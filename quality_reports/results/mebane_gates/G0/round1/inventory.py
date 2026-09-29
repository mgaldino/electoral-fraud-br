"""Read-only inventory of the material needed to establish the G0 baseline."""

import hashlib
import json
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
PATTERNS = {
    "raw": ["replication_authors/original_zip/*.zip", "replication_authors/extracted/fingerprint_brazil/raw-data/*"],
    "processed": ["data/processed/*.parquet"],
    "stan_chains": ["data/processed/cmdstanr_outputs/**/*.csv"],
    "fits": ["quality_reports/results/*.rds"],
    "logs": ["quality_reports/results/*.md", "quality_reports/results/*.txt", "quality_reports/results/*.csv"],
    "pdf": ["*.pdf", "output/figures/*.pdf", "ssrn-4073770.pdf.download/*.pdf"],
    "code": ["R/*.R", "stan/*.stan", "replication_authors/extracted/fingerprint_brazil/script_paper_sig.R"],
    "configuration": ["renv.lock", "renv/settings.json", ".Rprofile", "README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json", "quality_reports/plans/mebane_gate_agent_prompts.md", "scripts/mebane_gates.py"],
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command(*args):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=False)
    return {"exit_code": result.returncode, "stdout": result.stdout.strip(), "stderr": result.stderr.strip()}


items = []
seen = set()
for category, patterns in PATTERNS.items():
    for pattern in patterns:
        for path in sorted(ROOT.glob(pattern)):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT).as_posix()
            if relative in seen:
                continue
            seen.add(relative)
            item = {"path": relative, "category": category, "bytes": path.stat().st_size, "sha256": sha256(path)}
            tracked = command("git", "ls-files", "--error-unmatch", relative)
            item["git_tracked"] = tracked["exit_code"] == 0
            if category == "pdf":
                check = command("pdfinfo", str(path))
                item["pdf_integrity"] = "pdfinfo_ok" if check["exit_code"] == 0 else "invalid_or_incomplete"
                item["pdf_pages"] = next((line.split(":", 1)[1].strip() for line in check["stdout"].splitlines() if line.startswith("Pages:")), None)
                if check["exit_code"]:
                    item["pdf_error"] = check["stderr"]
            items.append(item)

repo = {
    "head": command("git", "rev-parse", "HEAD")["stdout"],
    "branch": command("git", "branch", "--show-current")["stdout"],
    "remote_origin": command("git", "remote", "get-url", "origin")["stdout"],
    "status_porcelain": command("git", "status", "--short")["stdout"],
}
archive = ROOT / "replication_authors/original_zip/fingerprint_brazil.zip"
archive_matches = []
if archive.exists():
    with zipfile.ZipFile(archive) as zipped:
        for name in zipped.namelist():
            if not name.startswith("fingerprint_brazil/raw-data/") or name.endswith("/"):
                continue
            extracted = ROOT / "replication_authors/extracted" / name
            digest = hashlib.sha256()
            with zipped.open(name) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            archive_matches.append({"archive_member": name,
                                    "extracted_path": extracted.relative_to(ROOT).as_posix(),
                                    "embedded_sha256": digest.hexdigest(),
                                    "extracted_matches": extracted.is_file() and sha256(extracted) == digest.hexdigest()})
report = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "git": repo,
    "archive_test": command("unzip", "-t", str(archive)) if archive.exists() else {"exit_code": None, "error": "missing"},
    "archive_matches": archive_matches,
    "items": items,
}
(ROUND / "inventory.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Inventoried {len(items)} files; PDF invalid: {sum(i.get('pdf_integrity') == 'invalid_or_incomplete' for i in items)}")
