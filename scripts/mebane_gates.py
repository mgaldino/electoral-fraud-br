#!/usr/bin/env python3
"""Check the gate ledger and render its human-readable execution plan."""

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
RENDERED = ROOT / "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"
STATES = {
    "queued", "running", "submitted", "under_review", "changes_requested",
    "pass", "inconclusive", "waiting_external",
}
ACTIVE_STATES = {"running", "submitted", "under_review", "pass"}
TODO_STATES = {"todo", "in_progress", "done"}


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


def check_records(gate, root):
    errors = []
    prefix = gate["id"]
    record = gate.get("records")
    if not isinstance(record, dict):
        return [f"{prefix}: pass requires approval records"]
    executor = record.get("executor_id")
    reviewer = record.get("reviewer_id")
    if not executor or not reviewer or executor == reviewer:
        errors.append(f"{prefix}: executor and reviewer must be distinct identified agents")
    try:
        manifest_path = project_file(root, record.get("candidate_manifest"))
        manifest = read_json(manifest_path)
        files = manifest.get("files")
        if not isinstance(files, list) or not files:
            raise ValueError("candidate manifest must have a nonempty files list")
        included = set()
        for item in files:
            path = project_file(root, item.get("path"))
            if path == manifest_path or path in included:
                raise ValueError("self-reference or duplicate file in manifest")
            included.add(path)
            if sha256(path) != item.get("sha256"):
                errors.append(f"{prefix}: stale candidate file: {item.get('path')}")
        manifest_hash = sha256(manifest_path)
        for field in ("review", "adjudication"):
            result = read_json(project_file(root, record.get(field)))
            if result.get("candidate_manifest_sha256") != manifest_hash:
                errors.append(f"{prefix}: {field} is bound to another candidate")
            if result.get("status") != "pass":
                errors.append(f"{prefix}: {field} has not passed")
            if field == "review" and (
                result.get("executor_id") != executor
                or result.get("reviewer_id") != reviewer
            ):
                errors.append(f"{prefix}: inconsistent review identities")
            if field == "adjudication" and result.get("unresolved_material_findings") != 0:
                errors.append(f"{prefix}: adjudication has unresolved material findings")
        for todo in gate["todos"]:
            for evidence in todo.get("evidence", []):
                if project_file(root, evidence.get("path")) not in included:
                    errors.append(f"{prefix}: todo evidence is not in the frozen manifest")
        if gate.get("external_prerequisites"):
            external = record.get("external_evidence", [])
            if not external:
                errors.append(f"{prefix}: external prerequisite evidence missing")
            for value in external:
                if project_file(root, value) not in included:
                    errors.append(f"{prefix}: external evidence is not in the manifest")
    except (ValueError, OSError, AttributeError, TypeError) as error:
        errors.append(f"{prefix}: invalid approval record: {error}")
    return errors


def validate(plan, root):
    errors = []
    if not isinstance(plan, dict) or plan.get("schema_version") != "1.0":
        return ["unsupported ledger schema"]
    gates = plan.get("gates")
    if not isinstance(gates, list) or not gates:
        return ["gates must be a nonempty list"]
    if any(not isinstance(gate, dict) for gate in gates):
        return ["each gate must be an object"]
    ids = [gate.get("id") for gate in gates]
    if any(not isinstance(key, str) or not re.fullmatch(r"G\d+", key) for key in ids):
        return ["invalid gate id"]
    if len(ids) != len(set(ids)):
        return ["duplicate gate ids"]
    by_id = dict(zip(ids, gates))
    for gate in gates:
        key = gate["id"]
        for field in ("title", "goal", "on_failure"):
            if not isinstance(gate.get(field), str) or not gate[field].strip():
                errors.append(f"{key}: missing {field}")
        for field in ("write_scope", "deliverables", "acceptance"):
            if not isinstance(gate.get(field), list) or not gate[field]:
                errors.append(f"{key}: missing {field}")
        if gate.get("status") not in STATES:
            errors.append(f"{key}: invalid status")
        for role in ("executor", "reviewer"):
            assignment = gate.get(role, {})
            if not isinstance(assignment, dict) or not all(
                assignment.get(field) for field in ("role", "model", "effort")
            ):
                errors.append(f"{key}: incomplete {role} assignment")
        if not isinstance(gate.get("reviewer"), dict) or not gate["reviewer"].get("independent"):
            errors.append(f"{key}: independent review is required")
        dependencies = gate.get("depends_on")
        if not isinstance(dependencies, list) or any(not isinstance(d, str) for d in dependencies):
            errors.append(f"{key}: invalid dependencies")
            continue
        if len(dependencies) != len(set(dependencies)):
            errors.append(f"{key}: duplicate dependencies")
        for dependency in dependencies:
            if dependency not in by_id:
                errors.append(f"{key}: unknown dependency {dependency}")
            elif gate.get("status") in ACTIVE_STATES and by_id[dependency].get("status") != "pass":
                errors.append(f"{key}: prerequisite {dependency} has not passed")
        external = gate.get("external_prerequisites")
        if not isinstance(external, list):
            errors.append(f"{key}: external prerequisites must be a list")
        elif external and gate.get("status") in ACTIVE_STATES:
            records = gate.get("records")
            evidence = records.get("external_evidence", []) if isinstance(records, dict) else []
            if not evidence:
                errors.append(f"{key}: execution requires external prerequisite evidence")
            else:
                for value in evidence:
                    try:
                        project_file(root, value)
                    except ValueError as error:
                        errors.append(f"{key}: invalid external evidence: {error}")
        todos = gate.get("todos")
        if not isinstance(todos, list) or not todos or any(not isinstance(t, dict) for t in todos):
            errors.append(f"{key}: todos must be nonempty objects")
            continue
        todo_ids = set()
        for todo in todos:
            tid = todo.get("id")
            if not isinstance(tid, str) or not re.fullmatch(rf"{key}-T\d+", tid):
                errors.append(f"{key}: invalid todo id")
            elif tid in todo_ids:
                errors.append(f"{key}: duplicate todo id {tid}")
            todo_ids.add(str(tid))
            if todo.get("status") not in TODO_STATES or not todo.get("task"):
                errors.append(f"{key}: incomplete todo {tid}")
            evidence = todo.get("evidence")
            if not isinstance(evidence, list):
                errors.append(f"{key}: evidence must be a list")
                continue
            if todo.get("status") == "done" and not evidence:
                errors.append(f"{key}: done todo {tid} requires evidence")
            for item in evidence:
                try:
                    if item.get("basis") not in {"historical", "inspected", "executed"}:
                        raise ValueError("evidence basis is required")
                    project_file(root, item.get("path"))
                except (ValueError, AttributeError) as error:
                    errors.append(f"{key}: invalid evidence for {tid}: {error}")
        if gate.get("status") == "pass":
            if any(todo.get("status") != "done" for todo in todos):
                errors.append(f"{key}: pass requires every todo done")
            errors.extend(check_records(gate, root))

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
        args.output.write_text(render(plan), encoding="utf-8")
        print(f"Rendered: {args.output}")
    else:
        count = sum(len(gate["todos"]) for gate in plan["gates"])
        print(f"PASS: {len(plan['gates'])} gates, {count} todos; structural checks only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
