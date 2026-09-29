"""Check rendered brief geometry and links; visual inspection remains separate."""
import hashlib
import json
from pathlib import Path

import pdfplumber
from pypdf import PdfReader

HERE = Path(__file__).resolve().parent
pdf = HERE / "2026-09-29_resumo_execucao.pdf"
pages = []
with pdfplumber.open(pdf) as document:
    for number, page in enumerate(document.pages, 1):
        assert page.chars, f"Empty page {number}"
        outside = [c for c in page.chars if c["x0"] < 20 or c["x1"] > page.width - 20
                   or c["top"] < 20 or c["bottom"] > page.height - 20]
        assert not outside, f"Characters outside safety bounds on page {number}"
        pages.append({"page": number, "characters": len(page.chars), "outside_safety_bounds": 0})
reader = PdfReader(pdf)
links = []
for page in reader.pages:
    for ref in page.get("/Annots", []):
        item = ref.get_object()
        action = item.get("/A", {})
        if action.get("/S") == "/URI":
            links.append(action["/URI"])
assert len(reader.pages) == 4, "Reinspect pagination before delivery"
assert len(links) == 8 and all(link.startswith("https://") for link in links)
record = {"pdf_sha256": hashlib.sha256(pdf.read_bytes()).hexdigest(), "pages": pages,
          "links": links, "geometry_status": "pass", "visual_status": "requires_human_or_model_image_inspection"}
(HERE / "2026-09-29_resumo_execucao_geometry.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
