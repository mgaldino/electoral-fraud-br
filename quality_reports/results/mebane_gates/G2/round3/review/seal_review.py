#!/usr/bin/env python3
"""Reuse the pinned documentary QA sealer without modifying G1 artifacts."""
import hashlib
import importlib.util
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
SOURCE = ROOT / "quality_reports/results/mebane_gates/G1/round3/review/seal_review.py"
AUDIT = SOURCE.with_name("check_documentary.py")
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == "cb6283a36e57ee71840adb307c135a1f4397e3e9995e78b410bd411c1e9bae24"
assert hashlib.sha256(AUDIT.read_bytes()).hexdigest() == "fdd479573b86944ee004bac6ad35e27c3eec51af0064527164f2f3d28bb992d2"
spec = importlib.util.spec_from_file_location("documentary_sealer_reused", SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.seal(HERE, supporting=(SOURCE, AUDIT))
