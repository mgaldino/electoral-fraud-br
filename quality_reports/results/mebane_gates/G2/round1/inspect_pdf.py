"""Render QA contact sheets and check PDF text boxes; no scientific computation."""
import json
from pathlib import Path
import pdfplumber
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
pdf = HERE / "mebane_model_contract.pdf"
boxes = []
with pdfplumber.open(pdf) as document:
    for number, page in enumerate(document.pages, 1):
        outside = [c for c in page.chars if c["x0"] < 35 or c["x1"] > page.width - 35
                   or c["top"] < 25 or c["bottom"] > page.height - 25]
        boxes.append({"page": number, "characters": len(page.chars),
                      "outside_safety_bounds": len(outside),
                      "rightmost": max(c["x1"] for c in page.chars)})
pages = sorted((HERE / "rendered").glob("page-*.png"))
for start in range(0, len(pages), 6):
    sheet = Image.new("RGB", (3 * 510, 2 * 685), "#dddddd")
    draw = ImageDraw.Draw(sheet)
    for k, path in enumerate(pages[start:start + 6]):
        page = Image.open(path).convert("RGB")
        page.thumbnail((500, 648))
        x, y = (k % 3) * 510, (k // 3) * 685
        sheet.paste(page, (x, y + 27))
        draw.text((x + 8, y + 7), f"Page {start+k+1}", fill="black")
    sheet.save(HERE / "rendered" / f"contact-{start // 6 + 1}.png")
result = {"pages": boxes, "visual_check": "requires implementer inspection of contact sheets and equations; not independent QA"}
(HERE / "results/pdf_geometry.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
