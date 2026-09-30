"""Render the reviewed proposal without modifying its Markdown source."""

import argparse
import hashlib
import html
import json
import re
from pathlib import Path

import reportlab
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inline(text):
    value = html.escape(text)
    value = re.sub(r"\[([^\]]+)\]\((https?://[^\s)]+)\)",
                   r'<link href="\2" color="#12516b">\1</link>', value)
    value = re.sub(r"`([^`]+)`", r'<font name="Courier" size="8.5">\1</font>', value)
    return re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), "Keep previous renders; use a new output path."
    body = ParagraphStyle("Body", fontName="Times-Roman", fontSize=11,
                          leading=14.6, spaceAfter=8)
    styles = {
        "body": body,
        "title": ParagraphStyle("Title", fontName="Helvetica-Bold", fontSize=20,
                                leading=24, textColor=colors.HexColor("#193f48"),
                                spaceAfter=14, keepWithNext=True),
        "heading": ParagraphStyle("Heading", fontName="Helvetica-Bold", fontSize=12.5,
                                  leading=16, textColor=colors.HexColor("#193f48"),
                                  spaceBefore=12, spaceAfter=8, keepWithNext=True),
        "item": ParagraphStyle("Item", parent=body, leftIndent=9, firstLineIndent=-9),
    }
    story, pending = [], []
    style = "body"

    def flush():
        if pending:
            story.append(Paragraph(inline(" ".join(pending)), styles[style]))
            pending.clear()

    for line in args.source.read_text(encoding="utf-8").splitlines():
        if line.startswith("# ") or line.startswith("## "):
            flush()
            level, content = line.split(" ", 1)
            story.append(Paragraph(inline(content), styles["title" if level == "#" else "heading"]))
        elif line.startswith("- ") or re.match(r"^\d+\. ", line):
            flush()
            style = "item"
            pending.append(line)
        elif line.strip():
            pending.append(line.strip())
        else:
            flush()
            style = "body"
    flush()

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#bcc9ce"))
        canvas.line(20 * mm, 17 * mm, A4[0] - 20 * mm, 17 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#435b63"))
        canvas.drawString(20 * mm, 12 * mm, "Mebane no Brasil | Proposta, não estimação | 30/09/2026")
        canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, str(doc.page))
        canvas.restoreState()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(str(args.output), pagesize=A4, leftMargin=20*mm,
                                 rightMargin=20*mm, topMargin=20*mm, bottomMargin=24*mm,
                                 title="Mebane no Brasil: proposta de validação",
                                 author="Coordenação do projeto")
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    record = {"source": str(args.source), "source_sha256": sha(args.source),
              "builder": str(Path(__file__)), "builder_sha256": sha(Path(__file__)),
              "output": str(args.output), "output_sha256": sha(args.output),
              "reportlab_version": reportlab.Version, "visual_qa": "pending"}
    with args.output.with_suffix(".manifest.json").open("x") as stream:
        json.dump(record, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps(record, ensure_ascii=False))


if __name__ == "__main__":
    main()
