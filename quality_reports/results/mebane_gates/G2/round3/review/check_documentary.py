#!/usr/bin/env python3
"""Reuse the frozen G1 documentary QA, targeting only G2 review outputs."""
import hashlib
import importlib.util
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
SOURCE = ROOT / "quality_reports/results/mebane_gates/G1/round3/review/check_documentary.py"
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == "fdd479573b86944ee004bac6ad35e27c3eec51af0064527164f2f3d28bb992d2"
spec = importlib.util.spec_from_file_location("documentary_qa_g1_reused", SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
raise SystemExit(module.audit(HERE.parent))
