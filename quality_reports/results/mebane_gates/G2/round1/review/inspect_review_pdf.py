"""Rendering and text-box checks for reviewer deliverable, not scientific tests."""
import json
from pathlib import Path
import pdfplumber
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
pages = []
geometry = []
with pdfplumber.open(HERE / "review.pdf") as doc:
    for number, page in enumerate(doc.pages, 1):
        img = page.to_image(resolution=100).original.convert("RGB")
        target = HERE / f"review-page-{number:02}.png"
        img.save(target)
        pages.append(target)
        outside = [c for c in page.chars if c["x0"] < 30 or c["x1"] > page.width-30
                   or c["top"] < 20 or c["bottom"] > page.height-20]
        geometry.append({"page": number, "characters": len(page.chars),
                         "outside_safety_bounds": len(outside)})
for start in range(0, len(pages), 4):
    canvas = Image.new("RGB", (1200, 1640), "#dddddd")
    draw = ImageDraw.Draw(canvas)
    for k, path in enumerate(pages[start:start+4]):
        img = Image.open(path)
        img.thumbnail((580, 770))
        x, y = (k % 2)*600+10, (k // 2)*820+30
        canvas.paste(img, (x, y))
        draw.text((x, y-20), f"Review page {start+k+1}", fill="black")
    canvas.save(HERE / f"review-contact-{start//4+1}.png")
(HERE / "review_pdf_geometry.json").write_text(json.dumps({"pages": geometry}, indent=2)+"\n")
print(json.dumps({"pages":len(pages), "characters_outside_safety_bounds":sum(p["outside_safety_bounds"] for p in geometry)}))
