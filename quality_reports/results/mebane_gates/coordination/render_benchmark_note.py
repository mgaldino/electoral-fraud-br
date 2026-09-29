"""Render a short Markdown handoff, retaining its exact source hash."""

import argparse
import hashlib
import html
import json
import re
from pathlib import Path

import reportlab
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inline(text):
    escaped = html.escape(text)
    escaped = re.sub(
        r"\[([^\]]+)\]\((https?://[^\s)]+)\)",
        r'<link href="\2" color="#175b74">\1</link>', escaped,
    )
    escaped = re.sub(r"`([^`]+)`", r'<font name="Courier" size="8.6">\1</font>', escaped)
    return re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)


def render(source, output):
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        "NoteTitle", fontName="Helvetica-Bold", fontSize=20, leading=24,
        textColor=colors.HexColor("#173f49"), spaceAfter=13,
    ))
    styles.add(ParagraphStyle(
        "NoteHeading", fontName="Helvetica-Bold", fontSize=12.5, leading=16,
        textColor=colors.HexColor("#173f49"), spaceBefore=13, spaceAfter=7,
        keepWithNext=True,
    ))
    styles.add(ParagraphStyle(
        "NoteBody", fontName="Times-Roman", fontSize=11, leading=14.5,
        spaceAfter=8, alignment=TA_LEFT,
    ))
    styles.add(ParagraphStyle(
        "NoteItem", parent=styles["NoteBody"], leftIndent=10, firstLineIndent=-10,
    ))
    story, pending = [], []
    pending_style = "NoteBody"

    def flush():
        nonlocal pending_style
        if pending:
            story.append(Paragraph(inline(" ".join(pending)), styles[pending_style]))
            pending.clear()
        pending_style = "NoteBody"

    for line in source.read_text(encoding="utf-8").splitlines():
        if line == "<!-- pagebreak -->":
            flush()
            story.append(PageBreak())
        elif line.startswith("# "):
            flush()
            story.append(Paragraph(inline(line[2:]), styles["NoteTitle"]))
        elif line.startswith("## "):
            flush()
            story.append(Paragraph(inline(line[3:]), styles["NoteHeading"]))
        elif line.startswith("- ") or re.match(r"^\d+\. ", line):
            flush()
            pending.append(line)
            pending_style = "NoteItem"
        elif not line.strip():
            flush()
        else:
            pending.append(line.strip())
    flush()
    story.append(Spacer(1, 3 * mm))

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#afc1c6"))
        canvas.line(20 * mm, 17 * mm, A4[0] - 20 * mm, 17 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#40575d"))
        canvas.drawString(20 * mm, 12 * mm, "Mebane | Benchmark e replicação externa | 29/09/2026")
        canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, str(doc.page))
        canvas.restoreState()

    output.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(output), pagesize=A4, rightMargin=20 * mm, leftMargin=20 * mm,
        topMargin=20 * mm, bottomMargin=23 * mm,
        title="Mebane: benchmark e replicação externa", author="Coordenação do projeto",
    )
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    manifest = {
        "source": {"path": str(source.resolve()), "sha256": digest(source)},
        "builder": {"path": str(Path(__file__).resolve()), "sha256": digest(Path(__file__))},
        "output": {"path": str(output.resolve()), "sha256": digest(output)},
        "reportlab_version": reportlab.Version,
        "visual_qa": "pending; separate record required",
    }
    output.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    render(args.source, args.output)
