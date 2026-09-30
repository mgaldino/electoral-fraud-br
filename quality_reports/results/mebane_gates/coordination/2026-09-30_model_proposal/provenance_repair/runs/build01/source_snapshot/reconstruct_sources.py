#!/usr/bin/env python3
"""Recover historical source bytes as data. Never execute recovered commands/code."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


HERE = Path(__file__).resolve().parent
PLAN_PATH = HERE / "repair_plan.json"
PLAN = json.loads(PLAN_PATH.read_bytes())
BASE = "quality_reports/results/mebane_gates/G3/round1"
REVIEW = BASE + "/review"
COORD = "quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal"
INPUTS = {
    "adjudication.json": COORD + "/provenance_adjudication.json",
    "input_closure_revision2.json": REVIEW + "/input_closure_revision2.json",
    "executor_event_sequence.json": REVIEW + "/executor_event_sequence.json",
    "history_audit.json": REVIEW + "/history_audit.json",
    "qa_audit_event_history.py": REVIEW + "/final_checks/audit_event_history.py",
    "review.json": REVIEW + "/review.json",
    "revision3_manifest.json": BASE + "/revision3/candidate_manifest.json",
}
HUNK = re.compile(rb"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?:[^\r\n]*)\r?\n?\Z")
COMMAND = re.compile(r"/usr/bin/time -p timeout 120 Rscript --vanilla (tests/mebane/likelihood/[^ ]+\.R)")
SOURCE = "R/lib/mebane_model.R"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def local(path):
    resolved = Path(path).resolve()
    require(resolved.is_relative_to(HERE), f"Write outside authorized scope: {path}")
    return resolved


def write_new(path, data):
    path = local(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)


def write_json(path, value):
    write_new(path, json_bytes(value))


def read_json(path):
    return json.loads(Path(path).read_bytes())


def metadata(path, relative_to):
    data = path.read_bytes()
    return {"path": path.relative_to(relative_to).as_posix(),
            "sha256": digest(data), "bytes": len(data)}


def checked_repo_file(repo, name):
    path = (repo / name).resolve()
    require(path.is_relative_to(repo), f"Input escapes repository: {name}")
    require(path.is_file(), f"Missing input: {name}")
    return path


def apply_diff(original, patch):
    """Apply exact hunks with byte/context/count checks; no fuzzy matching."""
    old = original.splitlines(keepends=True)
    lines = patch.splitlines(keepends=True)
    result = []
    cursor = index = 0
    require(bool(lines), "Empty update patch")
    while index < len(lines):
        match = HUNK.fullmatch(lines[index])
        require(match is not None, f"Malformed hunk: {lines[index]!r}")
        old_start, old_count, new_start, new_count = [
            int(value) if value is not None else 1 for value in match.groups()
        ]
        start = old_start if old_count == 0 else old_start - 1
        target = new_start if new_count == 0 else new_start - 1
        require(cursor <= start <= len(old), "Overlapping/out-of-range hunk")
        result.extend(old[cursor:start])
        require(len(result) == target, "New hunk offset mismatch")
        cursor = start
        removed = added = 0
        index += 1
        while index < len(lines) and not lines[index].startswith(b"@@ "):
            prefix, content = lines[index][:1], lines[index][1:]
            require(prefix in (b" ", b"-", b"+"), "Unsupported diff marker")
            if prefix in (b" ", b"-"):
                require(cursor < len(old) and old[cursor] == content,
                        "Exact patch context mismatch")
                cursor += 1
                removed += 1
            if prefix in (b" ", b"+"):
                result.append(content)
                added += 1
            index += 1
        require((removed, added) == (old_count, new_count), "Hunk count mismatch")
    result.extend(old[cursor:])
    return b"".join(result)


def update_state(state, path, kind, patch):
    if kind == "add":
        require(path not in state, f"Duplicate addition: {path}")
        return patch
    require(kind == "update", f"Unsupported change kind: {kind}")
    require(path in state, f"Missing base: {path}")
    return apply_diff(state[path], patch)


def parser_checks():
    checks = []
    examples = [
        (b"a\nb\nc\n", b"@@ -1,3 +1,4 @@\n a\n-b\n+B\n+x\n c\n", b"a\nB\nx\nc\n"),
        (b"a\nb\nc\n", b"@@ -1 +1 @@\n-a\n+A\n@@ -3 +3 @@\n-c\n+C\n", b"A\nb\nC\n"),
        (b"a\n", b"@@ -0,0 +1 @@\n+x\n", b"x\na\n"),
        (b"a\nb\n", b"@@ -1 +0,0 @@\n-a\n", b"b\n"),
    ]
    for index, (old, patch, expected) in enumerate(examples):
        require(apply_diff(old, patch) == expected, "Positive parser regression")
        checks.append(f"exact_patch_fixture_{index + 1}")
    invalid = [
        lambda: apply_diff(b"a\n", b"@@ -1 +1 @@\n-b\n+c\n"),
        lambda: apply_diff(b"a\n", b"@@ -1,2 +1 @@\n-a\n+b\n"),
        lambda: update_state({}, "missing.R", "update", b"@@ -1 +1 @@\n-a\n+b\n"),
    ]
    for index, action in enumerate(invalid):
        try:
            action()
        except ValueError:
            checks.append(f"invalid_patch_rejected_{index + 1}")
        else:
            raise ValueError("Invalid patch accepted")
    return checks


def candidate_integrity(repo, manifest):
    require(len(manifest["files"]) == PLAN["expected_candidate_entries"],
            "Revision3 entry count changed")
    records = []
    for expected in manifest["files"]:
        data = checked_repo_file(repo, expected["path"]).read_bytes()
        actual = {"path": expected["path"], "sha256": digest(data), "bytes": len(data)}
        require(all(actual[key] == expected[key] for key in actual),
                f"Revision3 input mismatch: {expected['path']}")
        records.append(actual)
    require(len({item["path"] for item in records}) == len(records),
            "Duplicate revision3 path")
    return {"declared_files_checked": len(records), "all_match": True, "files": records}


def validate_inputs(inputs):
    adjudication = read_json(inputs / "adjudication.json")
    require(adjudication["source"]["sha256"] == PLAN["candidate_sha256"], "Wrong adjudicated source")
    require(adjudication["adjudication"]["verdict"] == "READY_FOR_IMPLEMENTATION", "Repair not ready")
    finding = next(item for item in adjudication["findings"] if item["finding_id"] == PLAN["finding_id"])
    require(finding["status"] == "CONFIRMED", "Finding not confirmed")
    require(digest((inputs / "revision3_manifest.json").read_bytes()) == PLAN["candidate_sha256"],
            "Revision3 manifest identity mismatch")
    require(digest((inputs / "review.json").read_bytes()) == PLAN["review_sha256"],
            "Independent review identity mismatch")
    targets = read_json(inputs / "input_closure_revision2.json")["historical_preservation"]["missing_effective_code_versions"]
    require(len(targets) == PLAN["expected_source_count"] and
            [item["sha256"] for item in targets] == PLAN["expected_source_sha256"], "QA target list differs")
    return targets


def validate_recovered(targets, recovered):
    require(len(recovered) == len(targets), "Recovered source count differs")
    for target in targets:
        key = (target["path"], target["sha256"])
        require(key in recovered, "Expected source identity not recovered")
        require(digest(recovered[key]["data"]) == target["sha256"], "Recovered source digest differs")


def reconstruct(inputs):
    targets = validate_inputs(inputs)
    manifest = read_json(inputs / "revision3_manifest.json")
    known = {}
    for item in manifest["files"]:
        known.setdefault(item["sha256"], []).append(item["path"])
    require(not set(PLAN["expected_source_sha256"]) & set(known), "Targets already declared in revision3")
    events_document = read_json(inputs / "executor_event_sequence.json")
    require(events_document["has_more"] is False, "Event extraction was paginated/incomplete")
    target_by_key = {(item["path"], item["sha256"]): item for item in targets}
    require(len(target_by_key) == 7, "Duplicate target identity")
    state, lineage, recovered = {}, {}, {}
    runs, edits = [], []
    for order, event in enumerate(events_document["events"]):
        if event["type"] == "fileChange":
            require(event["status"] == "completed", "Incomplete file change")
            for change_index, change in enumerate(event["changes"]):
                path = Path(change["path"]).relative_to(PLAN["source_repository"]).as_posix()
                require(change["diff"]["truncated"] is False, "Truncated patch")
                require(change["kind"].get("move_path") is None, "Unexpected file move")
                patch = change["diff"]["text"].encode("utf-8")
                before = digest(state[path]) if path in state else None
                state[path] = update_state(state, path, change["kind"]["type"], patch)
                edit = {"order": order, "id": event["id"], "change_index": change_index,
                        "path": path, "operation": change["kind"]["type"],
                        "input_sha256": before, "sha256": digest(state[path]),
                        "patch_utf8_sha256": digest(patch)}
                edits.append(edit)
                lineage.setdefault(path, []).append(edit)
            continue
        require(event["type"] == "commandExecution", "Unsupported event type")
        match = COMMAND.search(event["command"])
        if match is None:
            continue
        script = match.group(1)
        refs = [script]
        if b'source("R/lib/mebane_model.R")' in state.get(script, b""):
            refs.append(SOURCE)
        source_states = []
        for path in refs:
            if path not in state:
                source_states.append({"path": path, "state_from_trace_unavailable": True,
                                      "availability": "unresolved_in_event_trace"})
                continue
            sha = digest(state[path])
            source_state = {"path": path, "sha256": sha, "last_edit": lineage[path][-1],
                            "lineage": list(lineage[path])}
            key = (path, sha)
            if key in target_by_key:
                target = target_by_key[key]
                snapshot = "snapshots/" + target["attempt"] + "/" + path
                source_state.update(availability="recovered_in_this_supplement", snapshot=snapshot,
                                    qa_attempt=target["attempt"])
                recovered[key] = {"target": target, "data": state[path], "snapshot": snapshot}
            else:
                source_state.update(availability="inherited_candidate" if sha in known else "not_archived_here",
                                    inherited_paths=known.get(sha, []))
            source_states.append(source_state)
        log = re.search(r" > ([^ ]+) 2>&1", event["command"])
        require(log is not None, "Unmapped historical command log")
        runs.append({"order": order, "id": event["id"], "turn_id": event["turn_id"],
                     "item_order": event["item_order"], "command": event["command"],
                     "exit_code": event["exit_code"], "status": event["status"],
                     "duration_ms_from_event": event.get("duration_ms"),
                     "historical_log": log.group(1), "source_states": source_states,
                     "executed_by_this_repair": False})
    require(set(recovered) == set(target_by_key), "Not all seven QA targets recovered")
    validate_recovered(targets, recovered)
    history = read_json(inputs / "history_audit.json")
    require(len(runs) == len(history["executions"]), "Historical command count mismatch")
    for actual, expected in zip(runs, history["executions"]):
        for key in ("order", "id", "command", "exit_code"):
            require(actual[key] == expected[key], f"Command audit mismatch: {key}")
        actual_states = [{key: item[key] for key in ("path", "sha256", "state_from_trace_unavailable") if key in item}
                         for item in actual["source_states"]]
        expected_states = [{key: item[key] for key in ("path", "sha256", "state_from_trace_unavailable") if key in item}
                           for item in expected["source_states"]]
        require(actual_states == expected_states, "Historical source-state mismatch")
    require(len(edits) == len(history["source_edits"]), "Edit audit count mismatch")
    for actual, expected in zip(edits, history["source_edits"]):
        require(all(actual[key] == expected[key] for key in ("order", "id", "path", "sha256")),
                "Historical edit audit mismatch")
    affected = [run["id"] for run in runs if any(item["availability"] == "recovered_in_this_supplement"
                                                for item in run["source_states"])]
    require(len(affected) == PLAN["expected_affected_command_count"], "Affected command count mismatch")
    result = {"schema_version": "1.0", "finding_id": PLAN["finding_id"],
              "source": "frozen_inputs/executor_event_sequence.json",
              "source_thread_id": events_document["thread_id"], "event_count": len(events_document["events"]),
              "chronology_basis": "Saved raw tool-event order, not filesystem modification times or agent conclusions.",
              "dependency_scope": "Timed R entrypoints plus the explicit source(R/lib/mebane_model.R) dependency audited by QA; not a complete runtime dependency graph.",
              "affected_command_ids": affected, "commands": runs}
    return targets, recovered, result, edits


def freeze(repo, delivery):
    require(not delivery.exists(), "Delivery directory already exists; will not overwrite")
    entries = []
    for name, source in INPUTS.items():
        original = checked_repo_file(repo, source)
        data = original.read_bytes()
        destination = delivery / "frozen_inputs" / name
        write_new(destination, data)
        entries.append({**metadata(destination, delivery), "source_path": source,
                        "role": "preexisting_review_or_adjudication_input"})
    write_json(delivery / "input_manifest.json", {"files": entries})


def verify_frozen(delivery):
    for item in read_json(delivery / "input_manifest.json")["files"]:
        require(metadata(delivery / item["path"], delivery) ==
                {key: item[key] for key in ("path", "sha256", "bytes")}, "Frozen input mismatch")


def build(repo, delivery):
    checks = parser_checks()
    freeze(repo, delivery)
    inputs = delivery / "frozen_inputs"
    targets, recovered, command_map, edits = reconstruct(inputs)
    manifest = read_json(inputs / "revision3_manifest.json")
    before = candidate_integrity(repo, manifest)
    write_json(delivery / "candidate_integrity_before.json", before)
    snapshots = []
    for target in targets:
        item = recovered[(target["path"], target["sha256"])]
        path = delivery / item["snapshot"]
        write_new(path, item["data"])
        require(digest(path.read_bytes()) == target["sha256"], "Reopened snapshot hash differs")
        snapshots.append({**target, "snapshot": item["snapshot"], "bytes": len(item["data"]),
                          "matches_qa_sha256": True})
    logs = []
    for run in command_map["commands"]:
        if run["id"] not in command_map["affected_command_ids"]:
            continue
        source = checked_repo_file(repo, run["historical_log"])
        destination = delivery / "historical_logs" / source.name
        write_new(destination, source.read_bytes())
        log = {**metadata(destination, delivery), "source_path": run["historical_log"],
               "command_event_id": run["id"], "role": "historical_log_not_new_execution"}
        logs.append(log)
        run["archived_log"] = log
    write_json(delivery / "historical_logs_manifest.json", {"files": logs})
    write_json(delivery / "command_source_map.json", command_map)
    write_json(delivery / "reconstruction_trace.json", {"file_change_states": edits})
    after = candidate_integrity(repo, manifest)
    require(before == after, "Inherited candidate changed during reconstruction")
    write_json(delivery / "candidate_integrity_after.json", after)
    result = {"finding_id": PLAN["finding_id"], "executor_thread_id": PLAN["executor_thread_id"],
              "implementation_status": "candidate_ready_for_independent_review",
              "documentary_checks": "all_seven_exact_source_identities_recovered",
              "gate_outcome": "inconclusive", "independently_approved": False,
              "adjudication_resolved_by_executor": False,
              "candidate_manifest_sha256": PLAN["candidate_sha256"],
              "recovered_source_count": len(snapshots), "affected_command_count": len(logs),
              "historical_timed_commands_compared": len(command_map["commands"]),
              "source_edit_states_compared": len(edits), "parser_checks": checks,
              "revision3_declared_files_preserved": len(after["files"]),
              "snapshots": snapshots, "unresolved_target_ambiguities": [],
              "limits": [
                  "No recovered R code or historical command was executed. No MCMC, estimation, diagnostic recomputation or scientific change.",
                  "Saved tool events establish the reconstructible edit/command sequence. Unrecorded edits cannot be ruled out independently; QA target hashes and all saved source-state hashes agree.",
                  "The test_ar02_interface.R entrypoint has no addition/update base in this event trace. It remains explicitly unavailable in this trace and is outside the seven identities adjudicated here; current bytes are not substituted.",
                  "This supplement does not claim complete closure of all historical runtime inputs, change revision3, repair other findings, resolve F1/F2, or approve G3."
              ]}
    write_json(delivery / "result.json", result)
    return {key: result[key] for key in ("documentary_checks", "recovered_source_count",
                                       "affected_command_count", "revision3_declared_files_preserved", "gate_outcome")}


def verify(repo, delivery):
    verify_frozen(delivery)
    checks = parser_checks()
    targets, recovered, command_map, edits = reconstruct(delivery / "frozen_inputs")
    for target in targets:
        item = recovered[(target["path"], target["sha256"])]
        require((delivery / item["snapshot"]).read_bytes() == item["data"], "Replay bytes differ")
    saved_map = read_json(delivery / "command_source_map.json")
    for run in saved_map["commands"]:
        run.pop("archived_log", None)
    require(saved_map == command_map, "Replay command map differs")
    require(read_json(delivery / "reconstruction_trace.json") == {"file_change_states": edits},
            "Replay edit trace differs")
    for item in read_json(delivery / "historical_logs_manifest.json")["files"]:
        require(metadata(delivery / item["path"], delivery)["sha256"] == item["sha256"], "Archived log differs")
        require(digest(checked_repo_file(repo, item["source_path"]).read_bytes()) == item["sha256"],
                "Historical original log changed")
    original_manifest = checked_repo_file(repo, INPUTS["revision3_manifest.json"])
    require(digest(original_manifest.read_bytes()) == PLAN["candidate_sha256"], "Original manifest changed")
    integrity = candidate_integrity(repo, read_json(delivery / "frozen_inputs/revision3_manifest.json"))
    require(integrity == read_json(delivery / "candidate_integrity_before.json") ==
            read_json(delivery / "candidate_integrity_after.json"), "Parent integrity evidence differs")
    altered_targets = [dict(item) for item in targets]
    altered_targets[0]["sha256"] = "0" * 64
    altered_recovered = {key: dict(item) for key, item in recovered.items()}
    first_key = next(iter(altered_recovered))
    altered_recovered[first_key]["data"] += b"\n"
    for name, test_targets, test_recovered in (
        ("altered_expected_digest_rejected", altered_targets, recovered),
        ("altered_recovered_bytes_rejected", targets, altered_recovered),
    ):
        try:
            validate_recovered(test_targets, test_recovered)
        except ValueError:
            checks.append(name)
        else:
            raise ValueError("Corrupted provenance negative control was accepted")
    return {"status": "verified", "snapshots_replayed_byte_for_byte": len(targets),
            "command_map_reproduced": True, "edit_trace_reproduced": True,
            "historical_logs_unchanged": 5, "parent_manifest_sha256": PLAN["candidate_sha256"],
            "parent_entries_verified": len(integrity["files"]), "checks": checks,
            "new_scientific_executions": 0, "independent_qa": False}


def seal():
    require(not (HERE / "closure_manifest.json").exists(), "Manifest already exists")
    files = [metadata(path, HERE) for path in sorted(HERE.rglob("*")) if path.is_file()]
    manifest = {"schema_version": "1.0", "finding_id": PLAN["finding_id"],
                "artifact_kind": "documentary_supplement_to_revision3",
                "executor_thread_id": PLAN["executor_thread_id"],
                "parent_manifest_path": INPUTS["revision3_manifest.json"],
                "parent_manifest_sha256": PLAN["candidate_sha256"],
                "gate_outcome": "inconclusive", "approval_status": "submitted_for_independent_review",
                "scope": "Exactly seven recovered historical source identities and documentary execution/hash mapping.",
                "files": files,
                "external_inherited_inventory": "delivery/candidate_integrity_after.json",
                "coverage": "All package files present at sealing. Original 350 inherited files are referenced read-only in the external inventory, not recopied or treated as newly generated outputs.",
                "excluded_self_and_detached_checks": ["closure_manifest.json", "runs/final_verification/"],
                "seal_command": [sys.executable, "-B", str(Path(__file__).resolve()), "seal"]}
    write_json(HERE / "closure_manifest.json", manifest)
    return {"manifest_path": str(HERE / "closure_manifest.json"),
            "sha256": digest((HERE / "closure_manifest.json").read_bytes()), "files": len(files)}


def verify_seal():
    manifest_path = HERE / "closure_manifest.json"
    manifest = read_json(manifest_path)
    expected_paths = set()
    for item in manifest["files"]:
        path = local(HERE / item["path"])
        require(metadata(path, HERE) == item, f"Manifest mismatch: {item['path']}")
        expected_paths.add(item["path"])
    actual_paths = {path.relative_to(HERE).as_posix() for path in HERE.rglob("*") if path.is_file()
                    and path != manifest_path and not path.is_relative_to(HERE / "runs/final_verification")}
    require(actual_paths == expected_paths, "Unmanifested package file or missing file")
    return {"closure_manifest_sha256": digest(manifest_path.read_bytes()),
            "manifest_files_verified": len(expected_paths), "unmanifested_files": [],
            "detached_verification_excluded_to_avoid_self_reference": "runs/final_verification/"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("build", "verify", "seal", "verify-seal"))
    parser.add_argument("--repo", type=Path, default=Path(PLAN["source_repository"]))
    parser.add_argument("--delivery", type=Path, default=HERE / "delivery")
    args = parser.parse_args()
    repo, delivery = args.repo.resolve(), local(args.delivery)
    if args.mode == "build":
        result = build(repo, delivery)
    elif args.mode == "verify":
        result = verify(repo, delivery)
    elif args.mode == "seal":
        result = seal()
    else:
        result = {**verify(repo, delivery), **verify_seal()}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
