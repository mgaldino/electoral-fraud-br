"""F02: contract freezing consumes only the hashed static contract."""
import hashlib
import json
import runpy
import tempfile
from pathlib import Path
from unittest.mock import patch

module = runpy.run_path("quality_reports/results/mebane_gates/G1/round2/freeze_candidate.py")
read_contract = module["read_contract"]
source = Path(module["CONTRACT_SOURCE"])
content, contract = read_contract(source)
with tempfile.TemporaryDirectory() as directory:
    static = Path(directory) / "gate_contract.json"
    static.write_bytes(content)
    reads = []
    original_open = Path.open

    def tracked_open(path, *args, **kwargs):
        reads.append(path)
        if path != static:
            raise AssertionError(f"Unexpected input read: {path}")
        return original_open(path, *args, **kwargs)

    with patch.object(Path, "open", tracked_open):
        first = read_contract(static)
        second = read_contract(static)
    assert first == second and reads == [static, static]
    static.write_bytes(content + b" ")
    try:
        read_contract(static)
    except RuntimeError as error:
        assert "file hash changed" in str(error)
    else:
        raise AssertionError("Changed static file was accepted")
    static.write_bytes(content)
    try:
        read_contract(static, contract_sha="0" * 64)
    except RuntimeError as error:
        assert "canonical hash changed" in str(error)
    else:
        raise AssertionError("Wrong canonical hash was accepted")
    altered = dict(contract, status="running")
    payload = json.dumps(altered).encode()
    static.write_bytes(payload)
    try:
        read_contract(static, file_sha=hashlib.sha256(payload).hexdigest(),
                      contract_sha=module["canonical_sha"](altered))
    except RuntimeError as error:
        assert "mutable fields" in str(error)
    else:
        raise AssertionError("Mutable contract fields were accepted")
print("F02: static-only reads, unchanged repeated result, file/canonical hashes and mutable-field rejection: PASS")
