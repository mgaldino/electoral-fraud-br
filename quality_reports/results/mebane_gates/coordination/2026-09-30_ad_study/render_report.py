"""Render the study report from its separately computed Markdown and tables."""

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
from reportlab.platypus import Paragraph, SimpleDocTemplate, Table, TableStyle


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\((https?://[^\s)]+)\)",
                  r'<link href="\2" color="#12516b">\1</link>', text)
    text = re.sub(r"`([^`]+)`", r'<font name="Courier" size="8.5">\1</font>', text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), "Preserve earlier renders."
    body = ParagraphStyle("Body", fontName="Times-Roman", fontSize=11,
                          leading=14.3, spaceAfter=7)
    heading = ParagraphStyle("Heading", fontName="Helvetica-Bold", fontSize=12,
                             leading=15, spaceBefore=11, spaceAfter=7,
                             textColor=colors.HexColor("#193f48"), keepWithNext=True)
    title = ParagraphStyle("Title", parent=heading, fontSize=19, leading=23,
                           spaceBefore=0, spaceAfter=13)
    cell = ParagraphStyle("Cell", parent=body, fontSize=9, leading=11, spaceAfter=0)
    story, paragraph, rows = [], [], []

    def flush():
        if paragraph:
            story.append(Paragraph(inline(" ".join(paragraph)), body))
            paragraph.clear()
        if rows:
            table = Table([[Paragraph(inline(x), cell) for x in row] for row in rows],
                          colWidths=[170 * mm / len(rows[0])] * len(rows[0]),
                          repeatRows=1, hAlign="LEFT")
            table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e6eef0")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LINEBELOW", (0, 0), (-1, 0), 0.7, colors.HexColor("#69818a")),
                ("LINEBELOW", (0, -1), (-1, -1), 0.4, colors.HexColor("#69818a")),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]))
            story.append(table)
            rows.clear()

    for line in args.source.read_text(encoding="utf-8").splitlines():
        if line.startswith("# ") or line.startswith("## "):
            flush()
            mark, text = line.split(" ", 1)
            story.append(Paragraph(inline(text), title if mark == "#" else heading))
        elif line.startswith("|"):
            if paragraph:
                flush()
            values = [x.strip() for x in line.strip("|").split("|")]
            if not all(re.fullmatch(r"[:\- ]+", x) for x in values):
                rows.append(values)
        elif not line.strip():
            flush()
        elif line.startswith("- ") or re.match(r"^\d+\. ", line):
            flush()
            paragraph.append(line)
        else:
            if rows:
                flush()
            paragraph.append(line)
    flush()

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#bcc9ce"))
        canvas.line(20 * mm, 17 * mm, A4[0] - 20 * mm, 17 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.drawString(20 * mm, 12 * mm, "Estudo A/D | Comparação experimental, não inferência eleitoral")
        canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, str(doc.page))
        canvas.restoreState()

    SimpleDocTemplate(str(args.output), pagesize=A4, leftMargin=20*mm,
                      rightMargin=20*mm, topMargin=20*mm, bottomMargin=24*mm,
                      title="Comparação experimental A/D em D.C. 2010",
                      author="Projeto electoralFraud").build(
                          story, onFirstPage=footer, onLaterPages=footer)
    record = {"source": str(args.source), "source_sha256": sha(args.source),
              "renderer": str(Path(__file__)), "renderer_sha256": sha(Path(__file__)),
              "pdf": str(args.output), "pdf_sha256": sha(args.output),
              "reportlab": reportlab.Version, "visual_qa": "pending"}
    with args.output.with_suffix(".manifest.json").open("x", encoding="utf-8") as stream:
        json.dump(record, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps(record, ensure_ascii=False))


if __name__ == "__main__":
    main()
