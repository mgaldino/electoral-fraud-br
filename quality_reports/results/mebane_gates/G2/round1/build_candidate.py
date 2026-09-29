"""Reproduce audit artifacts and freeze/verify a G2 candidate, never the ledger."""
import argparse
import csv
import datetime as dt
import hashlib
import json
import subprocess
import time
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
REL = str(HERE.relative_to(ROOT))
EXECUTOR = "01a0eaee-01df-7773-bd63-d321db26a47c"
PY = "/Users/manoelgaldino/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
G0 = "quality_reports/results/mebane_gates/G0/round2"
R0 = "quality_reports/results/mebane_gates/G0/round1"
COORD = "quality_reports/results/mebane_gates/coordination"
EXPECTED = {
    f"{G0}/candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
    f"{G0}/review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
    f"{G0}/adjudication.json": "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b",
    f"{COORD}/measfrauds_2022-03-06.pdf": "ad3b1cd473d48540877fb00cdffaaa09df1a21a98e4a2b4fa0a03c227ec50d76",
    f"{COORD}/pm23_2023-07-02.pdf": "615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431",
}
READ_ONLY_CODE = [
    f"{R0}/qbl_installed_3017de5.jags", f"{R0}/ef_models_3017de5.R",
    f"{R0}/final_state/stan/eforensics_qbl.stan",
    *[f"{R0}/final_state/R/{x}" for x in (
        "05_eforensics_qbl_fresh_diagnostic.R", "05_jags_qbl_zone_fe.R",
        "05_stan_eforensics_qbl_calibrate.R")],
]

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def contract_hash():
    contract = read(HERE / "gate_contract.json")
    assert "status" not in contract and "records" not in contract
    assert all("status" not in t and "evidence" not in t for t in contract["todos"])
    assert contract["id"] == "G2" and contract["depends_on"] == ["G0"]
    return hashlib.sha256(json.dumps(contract, sort_keys=True, ensure_ascii=False,
                                      separators=(",", ":")).encode("utf-8")).hexdigest()

def dependencies():
    for path, digest in EXPECTED.items():
        assert sha(ROOT / path) == digest, f"Changed dependency: {path}"
    for suffix in ["review/review.json", "adjudication.json"]:
        record = read(ROOT / G0 / suffix)
        assert record["status"] == "pass"
        assert record["candidate_manifest_sha256"] == EXPECTED[f"{G0}/candidate_manifest.json"]
    baseline = {x["path"]: x["sha256"] for x in read(ROOT / G0 / "candidate_manifest.json")["files"]}
    older_manifest = f"{R0}/candidate_manifest.json"
    assert sha(ROOT / older_manifest) == baseline[older_manifest]
    older = {x["path"]: x["sha256"] for x in read(ROOT / older_manifest)["files"]}
    for path in READ_ONLY_CODE:
        expected = baseline[path] if path in baseline else older[path]
        assert sha(ROOT / path) == expected, f"Snapshot mismatch: {path}"

def build():
    assert not (HERE / "candidate_manifest.json").exists(), "Frozen candidate: use a new round, do not rebuild"
    dependencies()
    (HERE / "rendered").mkdir(exist_ok=True)
    commands = [
        ["Rscript", "--vanilla", "tests/mebane/algebra/run_tests.R"],
        ["pandoc", "appendices/mebane_model_contract.md", "--standalone", "--pdf-engine=pdflatex",
         f"--lua-filter={REL}/render_code.lua", "-V", "colorlinks=true", "-V", "urlcolor=blue",
         "-o", f"{REL}/mebane_model_contract.pdf"],
        ["pdftotext", "-layout", f"{REL}/mebane_model_contract.pdf", f"{REL}/results/rendered_contract.txt"],
        ["pdftoppm", "-r", "65", "-png", f"{REL}/mebane_model_contract.pdf", f"{REL}/rendered/page"],
        [PY, f"{REL}/inspect_pdf.py"],
    ]
    records = []
    for i, command in enumerate(commands, 1):
        start = time.monotonic()
        timestamp = dt.datetime.now(dt.timezone.utc).isoformat()
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        log = HERE / "results" / f"command_{i}.log"
        log.write_text(result.stdout + result.stderr, encoding="utf-8")
        records.append({"argv": command, "started_at_utc": timestamp,
                        "elapsed_seconds": time.monotonic() - start,
                        "exit_code": result.returncode, "log": str(log.relative_to(ROOT))})
        write(HERE / "commands.json", records)
        print(command[0], result.returncode, records[-1]["elapsed_seconds"])
        if result.returncode:
            raise RuntimeError(result.stderr)

def finalize():
    assert not (HERE / "candidate_manifest.json").exists(), "Refuse to overwrite a frozen candidate"
    dependencies()
    assert str(UUID(EXECUTOR)) == EXECUTOR
    chash = contract_hash()
    checks = list(csv.DictReader((HERE / "results/checks.csv").open()))
    assert len(checks) == 51 and all(x["pass"] == "TRUE" for x in checks)
    visual = read(HERE / "results/visual_qa.json")
    assert visual["inspector_id"] == EXECUTOR and visual["independent"] is False
    assert visual["pdf_sha256"] == sha(HERE / "mebane_model_contract.pdf")
    assert visual["status"] == "pass_implementer_visual_only"
    commands = read(HERE / "commands.json")
    assert all(c["exit_code"] == 0 for c in commands)
    for source, digest in visual.get("source_sha256", {}).items():
        assert sha(ROOT / source) == digest
    inputs = sorted(set(EXPECTED) | {
        f"{COORD}/method_sources_download.md", f"{R0}/loads_environment.json", f"{R0}/claims.md",
        f"{R0}/inventory.json", f"{R0}/snapshot_map.json", f"{R0}/candidate_manifest.json",
        *[str(p.relative_to(ROOT)) for p in (HERE / "sources").iterdir() if p.is_file()],
    })
    own_code = ["tests/mebane/algebra/qbl_algebra.R", "tests/mebane/algebra/run_tests.R",
                *[f"{REL}/{x}" for x in ("build_candidate.py", "prepare_sources.py", "inspect_pdf.py", "render_code.lua")]]
    code = sorted(own_code + READ_ONLY_CODE)
    configuration = [f"{REL}/gate_contract.json"]
    known = set(inputs + code + configuration)
    outputs = sorted({"appendices/mebane_model_contract.md"} | {
        str(p.relative_to(ROOT)) for p in HERE.rglob("*") if p.is_file()
        and p.name not in {"candidate_manifest.json", "run.json"}
        and "__pycache__" not in p.parts and "review" not in p.parts
        and str(p.relative_to(ROOT)) not in known})
    run = {
        "gate_id": "G2", "round": "round1", "contract_sha256": chash,
        "executor_id": EXECUTOR, "executor_role": "METODO-PRINCIPAL",
        "goal_id": EXECUTOR,
        "goal_objective": "Entregar candidato revisável delimitado da auditoria matemática exata G2; completar entrega não aprova gate",
        "requested_model": "inherit", "requested_effort": "xhigh",
        "effective_model": "unknown_not_exposed_by_runtime", "effective_effort": "unknown_not_exposed_by_runtime",
        "started_at_utc": dt.datetime.fromtimestamp(1790647875, dt.timezone.utc).isoformat(),
        "candidate_created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "outcome": "candidate_delivered_with_material_decisions_pending",
        "gate_approved": False, "independent_review_obtained": False,
        "dependency_manifests": {"G0": EXPECTED[f"{G0}/candidate_manifest.json"]},
        "dependency_approvals": {"G0": {
            "review_sha256": EXPECTED[f"{G0}/review/review.json"],
            "adjudication_sha256": EXPECTED[f"{G0}/adjudication.json"]}},
        "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
        "production_code_read_only": READ_ONLY_CODE,
        "production_code_execution": "none; R qbl function evaluated only to compare its literal model string",
        "commands": commands, "seeds": [], "rng": "none; deterministic finite sums and quadrature",
        "runtime_evidence": f"{REL}/results/execution.txt",
        "tests": {"passed": 51, "total": 51, "scope": "implementer algebra tests, no independent QA"},
        "pending": ["G2-T5 independent rederivation", "substantive target/normalization choice",
                    "explicit prior/intercept decision", "estimand and stolen-origin assumptions"],
        "write_scope_used": ["appendices/mebane_model_contract.md", "tests/mebane/algebra/", f"{REL}/"],
        "excluded": ["mutable ledger", "G1 implementation", "raw datasets", "fits", "production edits", "MCMC", "G3", "installations"]
    }
    write(HERE / "run.json", run)
    files = sorted(set(inputs + code + configuration + outputs + [f"{REL}/run.json"]))
    assert "quality_reports/plans/mebane_2022_2026_gates.json" not in files
    manifest = {"gate_id": "G2", "round": "round1", "contract_sha256": chash,
                "executor_id": EXECUTOR,
                "files": [{"path": p, "sha256": sha(ROOT / p), "bytes": (ROOT / p).stat().st_size} for p in files]}
    write(HERE / "candidate_manifest.json", manifest)
    verify()

def verify():
    dependencies()
    manifest = read(HERE / "candidate_manifest.json")
    run = read(HERE / "run.json")
    assert run["contract_sha256"] == manifest["contract_sha256"] == contract_hash()
    assert run["executor_id"] == manifest["executor_id"] == EXECUTOR
    assert run["dependency_manifests"]["G0"] == EXPECTED[f"{G0}/candidate_manifest.json"]
    assert run["dependency_approvals"]["G0"] == {
        "review_sha256": EXPECTED[f"{G0}/review/review.json"],
        "adjudication_sha256": EXPECTED[f"{G0}/adjudication.json"]}
    listed = set()
    for item in manifest["files"]:
        assert item["path"] not in listed
        listed.add(item["path"])
        assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
        assert (ROOT / item["path"]).stat().st_size == item["bytes"]
    assert f"{REL}/candidate_manifest.json" not in listed
    assert f"{REL}/run.json" in listed
    for field in ("inputs", "code", "configuration", "outputs"):
        assert set(run[field]) <= listed
    todos = read(HERE / "todo_evidence.json")["todos"]
    assert [t["status"] for t in todos] == ["done", "done", "done", "done", "in_progress"]
    for todo in todos:
        for evidence in todo["evidence"]:
            assert evidence["path"] in listed
            assert evidence["basis"] in {"historical", "inspected", "executed"}
    print(json.dumps({"candidate_integrity": "pass", "files_verified": len(listed),
                      "gate_approved": False, "contract_sha256": contract_hash(),
                      "candidate_manifest_sha256": sha(HERE / "candidate_manifest.json")}, indent=2))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["build", "finalize", "verify"])
    args = parser.parse_args()
    {"build": build, "finalize": finalize, "verify": verify}[args.action]()
