"""Render a source-bound operational brief; no estimation or new numerical analysis."""
import hashlib
import html
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import reportlab
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Table, TableStyle

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
STEM = "2026-09-29_resumo_execucao"
LEDGER = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
plan = json.loads(LEDGER.read_text())
gates = {gate["id"]: gate for gate in plan["gates"]}
G1 = ROOT / "quality_reports/results/mebane_gates/G1/round2"
G2 = ROOT / "quality_reports/results/mebane_gates/G2/round1"
G7 = (ROOT / gates["G7"]["records"]["candidate_manifest"]).parent
review1 = json.loads((G1 / "review/review.json").read_text())
review2 = json.loads((G2 / "review/review.json").read_text())
assert gates["G0"]["status"] == gates["G1"]["status"] == "pass"
assert review1["status"] == "pass" and review1["manifest_complete"]
assert gates["G2"]["status"] == "changes_requested"
assert review2["status"] == "changes_requested"
assert not review2["tests"]["mcmc"]
if gates["G7"]["status"] == "pass":
    review7 = json.loads((ROOT / gates["G7"]["records"]["review"]).read_text())
    adjudication7 = json.loads((ROOT / gates["G7"]["records"]["adjudication"]).read_text())
    assert review7["status"] == adjudication7["status"] == "pass"
    assert review7["manifest_complete"]
    assert adjudication7["unresolved_material_findings"] == 0

styles = getSampleStyleSheet()
styles.add(ParagraphStyle("BriefTitle", fontName="Helvetica-Bold", fontSize=22,
                          leading=26, textColor=colors.HexColor("#143e46"), spaceAfter=10))
styles.add(ParagraphStyle("BriefH1", fontName="Helvetica-Bold", fontSize=14,
                          leading=18, spaceBefore=13, spaceAfter=7,
                          textColor=colors.HexColor("#143e46")))
styles.add(ParagraphStyle("BriefBody", fontName="Times-Roman", fontSize=11,
                          leading=14.5, spaceAfter=8, alignment=TA_LEFT))
styles.add(ParagraphStyle("BriefSmall", fontName="Helvetica", fontSize=8.5,
                          leading=11, spaceAfter=5))
styles.add(ParagraphStyle("BriefRef", fontName="Times-Roman", fontSize=10,
                          leading=13.5, spaceAfter=10))
story, markdown = [], []


def paragraph(text, style="BriefBody"):
    story.append(Paragraph(html.escape(text), styles[style]))
    markdown.extend([text, ""])


def heading(text, title=False):
    story.append(Paragraph(html.escape(text), styles["BriefTitle" if title else "BriefH1"]))
    markdown.extend([("# " if title else "## ") + text, ""])


def pagebreak():
    story.append(PageBreak())


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#a7b9bc"))
    canvas.line(20 * mm, 17 * mm, A4[0] - 20 * mm, 17 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#4c5c60"))
    canvas.drawString(20 * mm, 12 * mm, "Mebane | Brasil 2022 e preparação 2026 | 29/09/2026")
    canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, str(doc.page))
    canvas.restoreState()


heading("Mebane: Brasil 2022 e 2026", title=True)
paragraph("Resumo da execução coordenada e roteiro de retomada. Este documento registra trabalho de dados e auditoria; não apresenta estimativas eleitorais novas.")
paragraph("Estado extraído do ledger em " + datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC") + ".", "BriefSmall")
heading("1. O que está pronto")
rows = [["Gate", "Estado", "Alcance"]]
notes = {
    "G0": "Ambiente, fontes, dados e fits inventariados; baseline aprovado.",
    "G1": "Pipeline de dados 2022 reparado, reproduzido e aprovado independentemente.",
    "G2": "Auditoria matemática rederivada; seleção do alvo e estimandos pendente.",
    "G7": ("Staging ensaiado e aprovado após reparos e QA; sem votos reais de 2026."
           if gates["G7"]["status"] == "pass" else
           "Prontidão de recepção 2026 em reparo/revisão, sem aprovação inferencial."),
}
for gate_id, note in notes.items():
    rows.append([gate_id, gates[gate_id]["status"], note])
table = Table([[Paragraph(html.escape(x), styles["BriefSmall"]) for x in row] for row in rows],
              colWidths=[15 * mm, 36 * mm, 119 * mm], repeatRows=1, hAlign="LEFT")
table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e7eff0")),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LINEBELOW", (0, 0), (-1, 0), 0.8, colors.HexColor("#40646b")),
    ("LINEBELOW", (0, 1), (-1, -1), 0.35, colors.HexColor("#ccd6d8")),
    ("LEFTPADDING", (0, 0), (-1, -1), 6), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
]))
story.append(table)
markdown.extend(["| Gate | Estado | Alcance |", "|---|---|---|"])
markdown.extend("| " + " | ".join(row) + " |" for row in rows[1:])
markdown.append("")
paragraph("Tabela 1. Estado operacional dos ramos executados. Pass aprova somente o contrato do gate indicado; não é aprovação geral de inferência.", "BriefSmall")
paragraph("Sol executou inventário e dados; outro agente Sol fez a QA independente. A auditoria matemática e sua revisão foram atribuídas a agentes separados do modelo principal. O coordenador conferiu evidências e adjudicou os achados; nenhum executor aprovou seu próprio gate.")
heading("2. Dados de 2022")
paragraph("O pipeline conserva 944.150 registros seção-turno, 472.075 em cada turno. Retém os 99 casos de votos nominais zero. Há 47 seções não instaladas por turno, com 657 aptos; seus 94 registros permanecem no arquivo, sinalizados como não elegíveis. Restam 472.028 linhas elegíveis por turno, sem que isso constitua ainda uma amostra inferencial aprovada.")
paragraph("N corresponde aos eleitores aptos; a = N - comparecimento; w aos votos do candidato-alvo. Brancos/nulos são preservados nas contagens e no comparecimento. A abstenção reportada original permanece separada. Exterior e seções pequenas são sinalizados, sem exclusão automática para gráficos.")
paragraph("A QA reproduziu controles nacionais, 56 UF-turnos e 364 candidato-UF-turnos a partir dos brutos e controles oficiais. Passaram 43 contraprovas próprias e 64 regressões do executor. Nove produtos centrais foram byte-idênticos em quatro execuções; as 70 colunas anteriores dos Parquet mantiveram valores e tipos. Os três defeitos encontrados foram reparados e rechecados.")
paragraph("Limite: a igualdade dos agregados com extratos oficiais posteriores não autentica a aquisição histórica do ZIP dos autores nem prova identidade de todos os campos entre versões. Não houve restauração fria integral do ambiente.", "BriefSmall")

pagebreak()
heading("3. Decisão metodológica pendente", title=True)
paragraph("A auditoria e a revisão independente confirmam que o qbl/JAGS instalado, o texto dos artigos e o Stan histórico não definem o mesmo modelo. A QA executou 75 testes próprios e 162 enumerações pequenas, com erro máximo 4,44e-16; a coordenação fez nove verificações adicionais. Nenhum erro material foi encontrado nas derivações, mas os achados impedem aprovar uma portagem equivalente sem fixar o alvo.")
heading("Três escolhas que precisam ficar explícitas")
paragraph("Alvo e suporte. O qbl admite combinações latentes que fazem a expressão de p.w sair de [0,1]; um caso mínimo gera 499,5. A política runtime do JAGS ainda não foi testada. O Stan limita artificialmente probabilidades (clamp) e substitui contagens latentes pela média, alterando o alvo. Mesmo em caso válido sem clamp, a likelihood exata 0,4116 difere do plug-in 0,4872. Normalização no retângulo de contagens não garante o suporte físico a + w <= N.")
paragraph("Priors e desenho. O JAGS aplica Exp(5) à variância hierárquica; o texto dos artigos, ao desvio-padrão. Isso implica variâncias residuais médias de 0,2 e 0,08. A prior de mistura ordena apenas o componente sem fraude acima dos outros dois, sem ordenar esses dois entre si. Interceptos e codificação geográfica também precisam ser preservados ou alterados explicitamente. Essas diferenças não demonstram que as priors causaram a falha de convergência.")
paragraph("Incerteza e margem. Quantis da esperança condicional não são quantis do total com classes latentes incertas. Totais devem ser agregados no mesmo draw. O modelo binário não identifica de qual candidato vieram votos stolen; brancos/nulos continuam no grupo residual mesmo em T2. Recomenda-se manter limites de identificação parcial, sem afirmar vencedor contrafactual.")
heading("Recomendação encaminhada ao usuário")
paragraph("Primeiro reproduzir fielmente o qbl/JAGS como benchmark de software, mantendo suas priors e testando sua semântica. Esse benchmark não seria liberado automaticamente para inferência. A alternativa é desenvolver um modelo gerador de contagens fisicamente coerente, explicitamente distinto do qbl. A escolha foi perguntada; ausência de resposta não foi tratada como aprovação.")
heading("O comentário sobre JAGS foi preservado")
paragraph('Comentário do usuário: "em JAGS rodou direito, então nao acho que seja prioris. HMC deveria ser melhor que MCMC padrao."')
paragraph("O fresh_v2 histórico terminou em 1.921,9 s, cerca de 32 minutos: 6.748 seções, quatro cadeias, adaptação 1.500, burn-in 5.000 e 5.000 draws por cadeia. G0 recarregou o fit e obteve R-hat clássico de 1,2468 para pi[2] e 1,7138 para iota.s.alpha. Terminar a execução não demonstrou convergência. São diagnósticos clássicos, não os rank-normalized exigidos pelo protocolo novo.")
paragraph("O Stan n2000 registrou 541,7 s de sampling/warmup e 9,62 s de compilação, com duas cadeias, R-hat máximo 1,2294 e ESS bulk mínimo 8,24. Dados, iterações, cadeias e alvo diferem do JAGS: não é benchmark controlado. HMC também é MCMC e não tem superioridade universal. Nenhuma nova estimação foi executada neste lote.", "BriefSmall")

pagebreak()
heading("4. Como retomar", title=True)
paragraph("O ledger quality_reports/plans/mebane_2022_2026_gates.json é a fonte de estado. A versão legível, o protocolo de despacho e as evidências por rodada estão na mesma estrutura do projeto. Não sobrescrever rounds congelados; mudanças materiais exigem nova rodada e QA separada.")
for text in [
    "G2: fechar a escolha do alvo, priors/desenho e distribuição dos estimandos; revisar a decisão antes de promover o gate.",
    "G3: implementar a referência small-N e o gerador compatível, testar suporte e priors, comparar engines somente no mesmo alvo e decidir a viabilidade do Stan exato.",
    "G4: recalcular diagnósticos dos fits históricos, executar pilotos e aprovar contrato de calibração antes das simulações confirmatórias. Quatro cadeias, R-hat rank-normalized < 1,01 e bulk/tail ESS >= 400 são critérios iniciais necessários, não suficientes.",
    "G5/G6: medir tempo por amostra efetiva e memória, aprovar capacidade e só então estimar o Brasil 2022. Não extrapolar linearmente um único tempo de Brasília.",
    "G7/G8/G9: preparar a recepção independentemente do modelo; cada turno de 2026 precisa de dados oficiais com cobertura auditada e inferência aprovada. Ausência de T2 não prova sua não ocorrência. Não existe monitoramento futuro ativo neste lote.",
]:
    paragraph(text)
heading("Limite concreto da preparação 2026")
paragraph("G7 entrega arquivamento e validação preliminar (staging) de CSV normalizado por seção/candidato, com referências EA11/EA16 e controles independentes. Não é ainda um conversor validado dos arquivos oficiais brutos de 2026. Esse adaptador precisa ser confirmado contra a publicação real, incluindo reconciliação completa das categorias. Recibos de ensaio, mesmo rotulados como oficiais, continuam data_ready=false e inference_ready=false.")
if gates["G7"]["status"] == "pass":
    paragraph("A aprovação de G7 inclui reparos rechecados para nomes UTF-8 sob locale C, datas exatas por turno e escopo territorial explícito. Completude relativa aos arquivos de referência não equivale a cobertura nacional atestada. A ingestão requer execução serial ou lock externo.", "BriefSmall")
heading("Fontes para retomada")
for text in [
    "Contrato matemático: appendices/mebane_model_contract.md; PDF e revisão independente em quality_reports/results/mebane_gates/G2/round1/.",
    "Dados aprovados, configuração e logs: quality_reports/results/mebane_gates/G1/round2/; comandos de execução versionada no README.",
    "Histórico da coordenação: quality_reports/results/mebane_gates/coordination/2026-09-28_execution.md. Os handoffs de abril são contexto histórico, não autorização para ignorar as novas validações.",
    "Fontes técnicas 2026: tse2026_source_preflight.md e cinco PDFs oficiais arquivados na pasta de coordenação. EA20 agregado não deve ser confundido com observações por seção. Arquivos de simulação não são resultados reais, mesmo com 100% de cobertura.",
]:
    paragraph(text, "BriefSmall")

pagebreak()
heading("5. Referências completas", title=True)
paragraph("Ordem sugerida: os dois textos de Mebane, o contrato auditado e o código do commit fixado; depois diagnósticos MCMC e documentação de marginalização. As fontes técnicas do TSE servem à implementação do intake, não à validação do modelo.")
for ref in plan["references"]:
    # Bibliographic fields are kept in the plan; do not invent publication details.
    if isinstance(ref, str):
        match = re.search(r"https://\S+$", ref)
        text = ref[:match.start()].rstrip() if match else ref
        url = match.group(0) if match else ""
    else:
        text = ref.get("citation", ref.get("reference", ""))
        url = ref.get("url", "")
    assert text, ref
    text = text.replace("\u2013", "-")
    story.append(Paragraph(html.escape(text) + (f' <link href="{html.escape(url, quote=True)}" color="#174e65">Fonte</link>' if url else ""), styles["BriefRef"]))
    markdown.extend([text + (f" [Fonte]({url})" if url else ""), ""])

doc = SimpleDocTemplate(str(HERE / f"{STEM}.pdf"), pagesize=A4,
                        rightMargin=20 * mm, leftMargin=20 * mm,
                        topMargin=19 * mm, bottomMargin=23 * mm,
                        title="Mebane: Brasil 2022 e preparação 2026",
                        author="Coordenação do projeto electoralFraud")
doc.build(story, onFirstPage=footer, onLaterPages=footer)
(HERE / f"{STEM}.md").write_text("\n".join(markdown), encoding="utf-8")
sources = [LEDGER, Path(__file__).resolve(), G1 / "review/review.json",
           G1 / "review/review.md", G1 / "adjudication.json",
           G2 / "review/review.json", G2 / "adjudication.json",
           ROOT / "appendices/mebane_model_contract.md",
           G7 / "implementation.md", G7 / "candidate_manifest.json"]
sources.extend(ROOT / gates["G7"]["records"][key] for key in ("review", "adjudication"))
sources.extend(HERE / f"{STEM}.{suffix}" for suffix in ("md", "pdf"))
record = {"generated_at_utc": datetime.now(timezone.utc).isoformat(),
          "reportlab_version": reportlab.Version,
          "status": "rendered_requires_visual_qa",
          "scope": "Operational summary of inspected and executed gate evidence, no new estimation",
          "files": [{"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in sources]}
(HERE / f"{STEM}_manifest.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"pdf": str(HERE / f"{STEM}.pdf"), "gate_states": {key: gates[key]["status"] for key in notes}}, ensure_ascii=False))
