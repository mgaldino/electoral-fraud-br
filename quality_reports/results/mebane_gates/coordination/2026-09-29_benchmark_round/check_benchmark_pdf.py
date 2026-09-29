"""Check PDF geometry and source identity; visual review remains a separate act."""

import hashlib
import json
from pathlib import Path

import pdfplumber
from pypdf import PdfReader


HERE = Path(__file__).resolve().parent
pdf = HERE / "benchmark_update.pdf"
source = HERE / "benchmark_update.md"
record = json.loads((HERE / "benchmark_update.manifest.json").read_text(encoding="utf-8"))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(source) == record["source"]["sha256"]
assert sha(pdf) == record["output"]["sha256"]
rows = []
with pdfplumber.open(pdf) as document:
    assert len(document.pages) == 3
    for index, page in enumerate(document.pages, start=1):
        text = page.extract_text()
        assert text and len(text) > 500
        assert "\ufffd" not in text and "\u25a0" not in text
        assert all(0 <= c["x0"] <= c["x1"] <= page.width for c in page.chars)
        assert all(0 <= c["top"] <= c["bottom"] <= page.height for c in page.chars)
        rows.append({"page": index, "characters": len(page.chars), "words": len(page.extract_words()),
                     "out_of_page_characters": 0})
reader = PdfReader(pdf)
links = []
for page in reader.pages:
    for annotation in page.get("/Annots", []):
        action = annotation.get_object().get("/A", {})
        if action.get("/URI"):
            links.append(action["/URI"])
assert len(links) >= 6
assert all(str(link).startswith("https://") for link in links)
result = {"pdf_sha256": sha(pdf), "source_sha256": sha(source), "pages": rows,
          "links": links, "geometry_pass": True,
          "visual_review": "Record actual inspected final renders separately; geometry is not visual QA."}
(HERE / "benchmark_update.geometry.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
)
print(json.dumps(result, ensure_ascii=False))
