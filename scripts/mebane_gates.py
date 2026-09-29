#!/usr/bin/env python3
"""Check the gate ledger and render its human-readable execution plan."""

import argparse
import datetime
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit
from uuid import UUID

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
RENDERED = ROOT / "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"
STATES = {
    "queued", "running", "submitted", "under_review", "changes_requested",
    "pass", "inconclusive", "waiting_external", "not_applicable",
}
ACTIVE_STATES = {"running", "submitted", "under_review", "pass"}
TODO_STATES = {"todo", "in_progress", "done"}
FINDING_STATUSES = {"CONFIRMED", "PARTIAL", "REFUTED", "UNRESOLVED"}
MATERIAL_SEVERITIES = {"critical", "major"}
SHA256_RE = re.compile(r"[0-9a-f]{64}\Z")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def project_file(root, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError("expected a nonempty project-relative path")
    path = (root / value).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as error:
        raise ValueError("path escapes project root") from error
    if not path.is_file():
        raise ValueError(f"missing file: {value}")
    return path


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def contract_sha256(gate):
    static = {key: value for key, value in gate.items() if key not in {"status", "records"}}
    static["todos"] = [
        {key: value for key, value in todo.items() if key not in {"status", "evidence"}}
        for todo in gate["todos"]
    ]
    encoded = json.dumps(static, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def canonical_uuid(value):
    if not isinstance(value, str):
        return False
    try:
        parsed = UUID(value)
    except (ValueError, AttributeError):
        return False
    return str(parsed) == value


def nonempty_text(value):
    return isinstance(value, str) and bool(value.strip())


def path_list(value):
    return isinstance(value, list) and all(isinstance(item, str) and item for item in value)


def text_list(value, nonempty=True):
    return isinstance(value, list) and (not nonempty or bool(value)) and all(nonempty_text(item) for item in value)


def check_external(gate, root, record, included=None, applicability=False):
    errors = []
    prefix = gate["id"]
    required = ["turn_not_held"] if applicability else gate["external_prerequisites"]
    field = "applicability_evidence" if applicability else "external_evidence"
    paths = record.get(field) if isinstance(record, dict) else None
    if not isinstance(paths, list) or not paths:
        return [f"{prefix}: {field} requires independent official attestation"]
    if not canonical_uuid(record.get("executor_id")) or not canonical_uuid(record.get("reviewer_id")) or record["executor_id"] == record["reviewer_id"]:
        errors.append(f"{prefix}: external attestation requires distinct canonical UUID agents")
    seen = set()
    for value in paths:
        try:
            attestation_path = project_file(root, value)
            if included is not None and attestation_path not in included:
                errors.append(f"{prefix}: external attestation is not in the manifest")
            attestation = read_json(attestation_path)
            if not isinstance(attestation, dict):
                raise ValueError("external attestation must be an object")
            requirement = attestation.get("requirement")
            turn = attestation.get("turn")
            scope = gate.get("election_scope")
            if not isinstance(requirement, str) or requirement not in required or type(turn) is not int or turn not in (1, 2) or not isinstance(scope, dict) or turn != scope.get("turn"):
                raise ValueError("external requirement or turn does not match gate")
            if (requirement, turn) in seen:
                raise ValueError("duplicate external requirement/turn")
            seen.add((requirement, turn))
            if attestation.get("gate_id") != prefix:
                raise ValueError("external attestation is bound to another gate")
            url = attestation.get("source_url")
            if not isinstance(url, str):
                raise ValueError("official source_url must be HTTPS on tse.jus.br")
            parsed = urlsplit(url)
            host = parsed.hostname or ""
            if (parsed.scheme != "https" or not (host == "tse.jus.br" or host.endswith(".tse.jus.br"))
                    or not parsed.path or parsed.username or parsed.password or parsed.port not in (None, 443)):
                raise ValueError("official source_url must be HTTPS on tse.jus.br")
            publication = attestation.get("publication_date")
            if not isinstance(publication, str):
                raise ValueError("invalid publication_date")
            try:
                published = datetime.date.fromisoformat(publication)
                if published.isoformat() != publication or published > datetime.date.today():
                    raise ValueError("invalid publication_date")
            except ValueError as error:
                raise ValueError("invalid publication_date") from error
            if type(attestation.get("election_year")) is not int or attestation["election_year"] != 2026 or attestation["election_year"] != scope.get("year"):
                raise ValueError("external election_year must be 2026")
            if applicability:
                if attestation.get("occurrence") != "not_held" or "coverage_pass" in attestation:
                    raise ValueError("non-occurrence attestation requires occurrence=not_held without coverage_pass")
            elif attestation.get("coverage_pass") is not True:
                raise ValueError("external coverage_pass must be true")
            reviewer = attestation.get("reviewer_id")
            if not canonical_uuid(reviewer) or reviewer != record.get("reviewer_id") or reviewer == record.get("executor_id"):
                raise ValueError("external reviewer must be independent and match records")
            checked = attestation.get("checked_at")
            if not isinstance(checked, str):
                raise ValueError("invalid checked_at")
            try:
                timestamp = datetime.datetime.fromisoformat(checked)
                if timestamp.tzinfo is None or timestamp.utcoffset() is None or timestamp.date() < published:
                    raise ValueError("invalid checked_at")
            except ValueError as error:
                raise ValueError("invalid checked_at") from error
            snapshot = project_file(root, attestation.get("snapshot_path"))
            if not isinstance(attestation.get("snapshot_sha256"), str) or not SHA256_RE.fullmatch(attestation["snapshot_sha256"]):
                raise ValueError("invalid snapshot_sha256")
            if sha256(snapshot) != attestation["snapshot_sha256"]:
                raise ValueError("stale external snapshot")
            if included is not None and snapshot not in included:
                errors.append(f"{prefix}: external snapshot is not in the manifest")
        except (ValueError, OSError, TypeError, AttributeError, json.JSONDecodeError) as error:
            errors.append(f"{prefix}: invalid external evidence: {error}")
    if set(required) - {item[0] for item in seen}:
        errors.append(f"{prefix}: external prerequisites lack attestation")
    return errors


def check_records(gate, root, by_id):
    errors = []
    prefix = gate["id"]
    record = gate.get("records")
    if not isinstance(record, dict):
        return [f"{prefix}: pass requires approval records"]
    executor = record.get("executor_id")
    reviewer = record.get("reviewer_id")
    if not canonical_uuid(executor) or not canonical_uuid(reviewer) or executor == reviewer:
        errors.append(f"{prefix}: executor and reviewer must be distinct canonical UUID agents")
    try:
        run_path = project_file(root, record.get("run"))
        manifest_path = project_file(root, record.get("candidate_manifest"))
        manifest = read_json(manifest_path)
        run = read_json(run_path)
        if not isinstance(manifest, dict) or not isinstance(run, dict):
            raise ValueError("run and manifest must be objects")
        round_id = run.get("round")
        if not isinstance(round_id, str) or not re.fullmatch(r"round[1-9][0-9]*", round_id):
            raise ValueError("run requires a round id such as round1")
        contract = contract_sha256(gate)
        for name, artifact in (("run", run), ("manifest", manifest)):
            if (artifact.get("gate_id"), artifact.get("round"), artifact.get("contract_sha256")) != (prefix, round_id, contract):
                errors.append(f"{prefix}: {name} is bound to another gate, round or contract")
        if run.get("executor_id") != executor:
            errors.append(f"{prefix}: inconsistent run executor identity")
        dependencies = gate["depends_on"]
        dependency_hashes = run.get("dependency_manifests")
        if not isinstance(dependency_hashes, dict) or set(dependency_hashes) != set(dependencies):
            errors.append(f"{prefix}: run.dependency_manifests must match dependencies")
        else:
            for dependency in dependencies:
                parent = by_id.get(dependency)
                parent_record = parent.get("records") if isinstance(parent, dict) else None
                parent_manifest = parent_record.get("candidate_manifest") if isinstance(parent_record, dict) else None
                try:
                    current_hash = sha256(project_file(root, parent_manifest))
                    if dependency_hashes[dependency] != current_hash:
                        errors.append(f"{prefix}: stale dependency manifest {dependency}")
                except (ValueError, OSError) as error:
                    errors.append(f"{prefix}: missing dependency manifest {dependency}: {error}")
        files = manifest.get("files")
        if not isinstance(files, list) or not files:
            raise ValueError("candidate manifest must have a nonempty files list")
        included = set()
        for item in files:
            if not isinstance(item, dict) or not isinstance(item.get("sha256"), str) or not SHA256_RE.fullmatch(item["sha256"]):
                raise ValueError("invalid manifest file entry")
            path = project_file(root, item.get("path"))
            if path == manifest_path or path in included:
                raise ValueError("self-reference or duplicate file in manifest")
            included.add(path)
            if sha256(path) != item.get("sha256"):
                errors.append(f"{prefix}: stale candidate file: {item.get('path')}")
        if run_path not in included:
            errors.append(f"{prefix}: run is not in the frozen manifest")
        for field in ("inputs", "code", "configuration", "outputs"):
            if not path_list(run.get(field)):
                raise ValueError(f"run.{field} must be a list of project-relative paths")
            for value in run[field]:
                path = project_file(root, value)
                if path == run_path:
                    errors.append(f"{prefix}: run cannot declare itself as {field}")
                if path not in included:
                    errors.append(f"{prefix}: run.{field} file is not in the frozen manifest: {value}")
        if not run["inputs"] or not any(run[field] for field in ("code", "configuration", "outputs")):
            errors.append(f"{prefix}: run requires an input and an artifact")
        manifest_hash = sha256(manifest_path)
        review_path = project_file(root, record.get("review"))
        review = read_json(review_path)
        adjudication = read_json(project_file(root, record.get("adjudication")))
        if not isinstance(review, dict) or not isinstance(adjudication, dict):
            raise ValueError("review and adjudication must be objects")
        for field, result in (("review", review), ("adjudication", adjudication)):
            if (result.get("gate_id"), result.get("round"), result.get("contract_sha256")) != (prefix, round_id, contract):
                errors.append(f"{prefix}: {field} is bound to another gate, round or contract")
            if result.get("candidate_manifest_sha256") != manifest_hash:
                errors.append(f"{prefix}: {field} is bound to another candidate")
            if result.get("status") != "pass":
                errors.append(f"{prefix}: {field} has not passed")
        if review.get("executor_id") != executor or review.get("reviewer_id") != reviewer:
            errors.append(f"{prefix}: inconsistent review identities")
        if review.get("manifest_complete") is not True:
            errors.append(f"{prefix}: reviewer must attest manifest_complete=true")
        if adjudication.get("review_sha256") != sha256(review_path):
            errors.append(f"{prefix}: adjudication is bound to another review")
        findings = review.get("findings")
        resolutions = adjudication.get("findings")
        if not isinstance(findings, list) or not isinstance(resolutions, list):
            raise ValueError("review and adjudication findings must be lists")
        reviewed = {}
        for finding in findings:
            if not isinstance(finding, dict) or not nonempty_text(finding.get("id")) or finding.get("severity") not in {"critical", "major", "minor"}:
                raise ValueError("invalid review finding")
            if finding["id"] in reviewed:
                raise ValueError("duplicate review finding ID")
            reviewed[finding["id"]] = finding
        decided = set()
        for finding in resolutions:
            if not isinstance(finding, dict) or not nonempty_text(finding.get("id")) or finding.get("status") not in FINDING_STATUSES or not nonempty_text(finding.get("resolution")) or type(finding.get("resolved")) is not bool:
                raise ValueError("invalid adjudication finding")
            fid = finding["id"]
            if fid in decided or fid not in reviewed:
                raise ValueError("duplicate or unknown adjudication finding ID")
            decided.add(fid)
            if reviewed[fid]["severity"] in MATERIAL_SEVERITIES and (finding["status"] == "UNRESOLVED" or (finding["status"] in {"CONFIRMED", "PARTIAL"} and not finding["resolved"])):
                errors.append(f"{prefix}: unresolved material finding {fid}")
        if decided != set(reviewed):
            errors.append(f"{prefix}: adjudication does not reconcile every review finding")
        if type(adjudication.get("unresolved_material_findings")) is not int or adjudication["unresolved_material_findings"] != 0:
            errors.append(f"{prefix}: adjudication has unresolved material findings")
        for todo in gate["todos"]:
            for evidence in todo.get("evidence", []):
                if project_file(root, evidence.get("path")) not in included:
                    errors.append(f"{prefix}: todo evidence is not in the frozen manifest")
        if gate.get("external_prerequisites"):
            errors.extend(check_external(gate, root, record, included))
    except (ValueError, OSError, AttributeError, TypeError, KeyError, json.JSONDecodeError) as error:
        errors.append(f"{prefix}: invalid approval record: {error}")
    return errors


def validate(plan, root):
    errors = []
    if not isinstance(plan, dict) or plan.get("schema_version") != "1.0":
        return ["unsupported ledger schema"]
    for field in ("date", "scope", "current_deliverable", "coordinator"):
        if not nonempty_text(plan.get(field)):
            errors.append(f"invalid {field}")
    for field in ("routing", "readiness"):
        value = plan.get(field)
        if not isinstance(value, dict) or not value or any(
            not nonempty_text(key) or not nonempty_text(item) for key, item in value.items()
        ):
            errors.append(f"invalid {field}")
    for field in ("operating_rules", "evidence_contract", "references"):
        if not text_list(plan.get(field)):
            errors.append(f"invalid {field}")
    gates = plan.get("gates")
    if not isinstance(gates, list) or not gates:
        return errors + ["gates must be a nonempty list"]
    if any(not isinstance(gate, dict) for gate in gates):
        return errors + ["each gate must be an object"]
    ids = [gate.get("id") for gate in gates]
    if any(not isinstance(key, str) or not re.fullmatch(r"G\d+", key) for key in ids):
        return errors + ["invalid gate id"]
    if len(ids) != len(set(ids)):
        return errors + ["duplicate gate ids"]
    by_id = dict(zip(ids, gates))
    for gate in gates:
        key = gate["id"]
        schema_errors = []
        for field in ("title", "goal", "on_failure"):
            if not nonempty_text(gate.get(field)):
                schema_errors.append(f"{key}: missing {field}")
        title = gate.get("title")
        if isinstance(title, str) and (len(title.splitlines()) != 1 or any(ord(char) < 32 or ord(char) == 127 or char in '"[]' for char in title)):
            schema_errors.append(f"{key}: unsafe Mermaid title")
        for field in ("write_scope", "deliverables", "acceptance"):
            if not text_list(gate.get(field)):
                schema_errors.append(f"{key}: missing or invalid {field}")
        if not isinstance(gate.get("status"), str) or gate["status"] not in STATES:
            schema_errors.append(f"{key}: invalid status")
        for role in ("executor", "reviewer"):
            assignment = gate.get(role)
            if not isinstance(assignment, dict) or not all(
                nonempty_text(assignment.get(field)) for field in ("role", "model", "effort")
            ):
                schema_errors.append(f"{key}: incomplete {role} assignment")
        if not isinstance(gate.get("reviewer"), dict) or gate["reviewer"].get("independent") is not True:
            schema_errors.append(f"{key}: independent review is required")
        dependencies = gate.get("depends_on")
        if not isinstance(dependencies, list) or any(not isinstance(d, str) for d in dependencies):
            schema_errors.append(f"{key}: invalid dependencies")
            dependencies = []
        if len(dependencies) != len(set(dependencies)):
            schema_errors.append(f"{key}: duplicate dependencies")
        external = gate.get("external_prerequisites")
        if not text_list(external, nonempty=False) or len(external) != len(set(external)):
            schema_errors.append(f"{key}: external prerequisites must be a list of distinct text")
        scope = gate.get("election_scope")
        if scope is not None and (
            not isinstance(scope, dict) or type(scope.get("year")) is not int
            or scope.get("year") != 2026 or type(scope.get("turn")) is not int
            or scope.get("turn") not in (1, 2)
        ):
            schema_errors.append(f"{key}: invalid election_scope")
        if external and isinstance(gate.get("status"), str) and gate["status"] in ACTIVE_STATES and scope is None:
            schema_errors.append(f"{key}: active external gate requires election_scope")
        if "allow_not_applicable" in gate and type(gate["allow_not_applicable"]) is not bool:
            schema_errors.append(f"{key}: allow_not_applicable must be bool")
        if gate.get("status") == "not_applicable" and (
            gate.get("allow_not_applicable") is not True or not isinstance(scope, dict)
            or scope.get("year") != 2026 or scope.get("turn") != 2
        ):
            schema_errors.append(f"{key}: not_applicable is only allowed for an authorized 2026 T2 gate")
        todos = gate.get("todos")
        if not isinstance(todos, list) or not todos or any(not isinstance(t, dict) for t in todos):
            schema_errors.append(f"{key}: todos must be nonempty objects")
        if schema_errors:
            errors.extend(schema_errors)
            continue
        for dependency in dependencies:
            if dependency not in by_id:
                errors.append(f"{key}: unknown dependency {dependency}")
            elif gate["status"] in ACTIVE_STATES and by_id[dependency].get("status") != "pass":
                errors.append(f"{key}: prerequisite {dependency} has not passed")
        todo_ids = set()
        for todo in todos:
            tid = todo.get("id")
            if not isinstance(tid, str) or not re.fullmatch(rf"{key}-T\d+", tid):
                errors.append(f"{key}: invalid todo id")
            elif tid in todo_ids:
                errors.append(f"{key}: duplicate todo id {tid}")
            todo_ids.add(str(tid))
            if not isinstance(todo.get("status"), str) or todo["status"] not in TODO_STATES or not nonempty_text(todo.get("task")):
                errors.append(f"{key}: incomplete todo {tid}")
            evidence = todo.get("evidence")
            if not isinstance(evidence, list):
                errors.append(f"{key}: evidence must be a list")
                continue
            if todo.get("status") == "done" and not evidence:
                errors.append(f"{key}: done todo {tid} requires evidence")
            for item in evidence:
                try:
                    if not isinstance(item, dict) or not isinstance(item.get("basis"), str) or item["basis"] not in {"historical", "inspected", "executed"}:
                        raise ValueError("evidence basis is required")
                    project_file(root, item.get("path"))
                except (ValueError, AttributeError, TypeError) as error:
                    errors.append(f"{key}: invalid evidence for {tid}: {error}")
        if external and gate["status"] in ACTIVE_STATES and gate["status"] != "pass":
            errors.extend(check_external(gate, root, gate.get("records")))
        if gate["status"] == "not_applicable":
            errors.extend(check_external(gate, root, gate.get("records"), applicability=True))
        if gate.get("status") == "pass":
            if any(todo.get("status") != "done" for todo in todos):
                errors.append(f"{key}: pass requires every todo done")
            if all(isinstance(todo.get("evidence"), list) and all(isinstance(item, dict) for item in todo["evidence"]) for todo in todos):
                errors.extend(check_records(gate, root, by_id))

    visiting, visited = set(), set()

    def visit(key):
        if key in visiting:
            errors.append(f"cycle detected at {key}")
            return
        if key in visited:
            return
        visiting.add(key)
        dependencies = by_id[key].get("depends_on", [])
        if isinstance(dependencies, list):
            for dependency in dependencies:
                if isinstance(dependency, str) and dependency in by_id:
                    visit(dependency)
        visiting.remove(key)
        visited.add(key)

    for key in ids:
        visit(key)
    return errors


def render(plan):
    lines = [
        "# Gates Mebane: Brasil 2022 e 2026", "",
        "Gerado de `mebane_2022_2026_gates.json`; editar o ledger e renderizar novamente.",
        "", f"Data: {plan['date']}", "", plan["scope"], "",
        plan["current_deliverable"], "", "## Coordenação e modelos", "",
        plan["coordinator"], "",
    ]
    for key, value in plan["routing"].items():
        lines.append(f"- **{key}**: {value}")
    lines.extend(["", "## Sequência", "", "```mermaid", "flowchart TD"])
    for gate in plan["gates"]:
        lines.append(f'    {gate["id"]}["{gate["id"]}: {gate["title"]}"]')
        for dependency in gate["depends_on"]:
            lines.append(f"    {dependency} --> {gate['id']}")
    lines.extend(["```", "", "| Gate | Executor | Revisor independente | Estado |",
                  "|---|---|---|---|"])
    for gate in plan["gates"]:
        executor, reviewer = gate["executor"], gate["reviewer"]
        lines.append(f"| {gate['id']} | {executor['model']} / {executor['effort']} | "
                     f"{reviewer['model']} / {reviewer['effort']} | {gate['status']} |")
    lines.extend(["", "`inherit` = modelo principal herdado pelo subagente.", ""])
    lines.extend(plan["readiness"].values())
    for title, key in (("Regras de operação", "operating_rules"),
                       ("Contrato de evidência", "evidence_contract")):
        lines.extend(["", f"## {title}", ""])
        lines.extend(f"- {item}" for item in plan[key])
    for gate in plan["gates"]:
        lines.extend(["", f"## {gate['id']}: {gate['title']}", "",
                      f"**Goal:** {gate['goal']}", "",
                      f"**Dependências:** {', '.join(gate['depends_on']) or 'nenhuma'}.",
                      f"**Estado:** `{gate['status']}`.", "",
                      f"**Escrita exclusiva:** {', '.join('`' + p + '`' for p in gate['write_scope'])}.",
                      "", "### Todos do goal", ""])
        if gate["status"] == "not_applicable":
            lines.extend(["**Aplicabilidade:** segundo turno não realizado, conforme atestação independente; não há inferência deste turno.", ""])
        for todo in gate["todos"]:
            checked = "x" if todo["status"] == "done" else " "
            lines.append(f"- [{checked}] **{todo['id']}**: {todo['task']}")
        for title, key in (("Entregáveis", "deliverables"), ("Aceitação independente", "acceptance")):
            lines.extend(["", f"### {title}", ""])
            lines.extend(f"- {item}" for item in gate[key])
        if gate["external_prerequisites"]:
            lines.extend(["", "### Requisitos externos", ""])
            lines.extend(f"- {item}" for item in gate["external_prerequisites"])
        lines.extend(["", f"**Se falhar:** {gate['on_failure']}"])
    lines.extend(["", "## Referências completas", ""])
    for reference in plan["references"]:
        linked = re.sub(r"(https?://\S+)$", r"[Fonte](\1)", reference)
        lines.append(f"- {linked}")
    lines.extend(["", "## Despacho", "",
                  "Usar os prompts e o ciclo de coordenação em [mebane_gate_agent_prompts.md](mebane_gate_agent_prompts.md).",
                  "", "O checker verifica estrutura e rastreabilidade; o PASS científico depende da revisão e adjudicação.", ""])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "render"))
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    parser.add_argument("--output", type=Path, default=RENDERED)
    args = parser.parse_args()
    try:
        plan = read_json(args.ledger)
        errors = validate(plan, ROOT)
    except (OSError, ValueError) as error:
        errors = [str(error)]
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    if args.command == "render":
        try:
            args.output.write_text(render(plan), encoding="utf-8")
        except (OSError, ValueError) as error:
            print(f"FAIL: render: {error}")
            return 1
        print(f"Rendered: {args.output}")
    else:
        count = sum(len(gate["todos"]) for gate in plan["gates"])
        print(f"PASS: {len(plan['gates'])} gates, {count} todos; structural checks only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
