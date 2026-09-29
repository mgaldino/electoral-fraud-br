# Rechecagem independente do checker e renderer, rodada 2

**Revisor:** QA-LEDGER-SOL (`01a0ea8e-acec-7211-a061-220d8547fc6c`).  
**Executor do candidato:** `01a0ea96-c9e9-77e3-b931-0d448e1cc876`, distinto do revisor.  
**Status:** `changes_requested`. Os reparos C-F001..008 foram confirmados dentro de seus limites mecânicos, mas C-F009 viola a regra documentada de reabertura quando muda a aprovação de um predecessor.

## Candidato e verificações

O SHA-256 de `candidate_checker_round2.json` é `73a167addcb5d4536773b42458b4201258be6c7c42448ae93f5bb620e7c509a3`. Recalculei, sem depender do relato do executor, os quatro hashes nele declarados:

| Arquivo | SHA-256 vigente |
|---|---|
| `scripts/mebane_gates.py` | `2effb4bc77697ba4a60b108de42b797d7b211268e0209f1000c93baddb7b13aa` |
| `tests/test_mebane_gates.py` | `84f98dbe3a4b397c21a64dc2936f827742b835cf3a6cb5efcab493ba39b0749b` |
| `quality_reports/plans/mebane_2022_2026_gates.json` | `fc44b2c192b432f0b8754adf974ffc582f7f942fa091df0edef14b081b6a0e39` |
| `quality_reports/plans/mebane_gate_agent_prompts.md` | `793063d3e74be4d8b49535f3ade07da4a440f3ccc22a306fb846bf84f505bc2c` |

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_mebane_gates.py' -v`: 24 testes, todos `ok`. `PYTHONDONTWRITEBYTECODE=1 python3 scripts/mebane_gates.py check`: `PASS: 10 gates, 45 todos; structural checks only`. Inspeção do ledger confirmou G8/T1 e G9/T2 separados, ambos em `waiting_external`, e somente G9 com `allow_not_applicable: true`. `render(read_json(LEDGER))` coincide exatamente com o Markdown existente. Os fixtures independentes usaram apenas `tempfile.TemporaryDirectory(dir='/tmp')`, importação do checker original e, quando indicado, chamadas CLI `check`/`render` sobre cópias JSON em `/tmp`.

## Fechamento de C-F001..008

| ID | Resultado da rechecagem |
|---|---|
| C-F001 | **Fechado mecanicamente.** `check_records` exige `gate_id`, `round` e `contract_sha256` em run, manifesto, review e adjudicação (`scripts/mebane_gates.py:174-186,236-240`). Um review de G1 reetiquetado G0 foi rejeitado; o contrato estático muda quando muda um critério. |
| C-F002 | **Fechado mecanicamente.** IDs passam por `canonical_uuid` e devem ser distintos (`:62-69,169-172`). O alias `executor_id + " "` foi rejeitado. A autenticidade do UUID real ainda é documental. |
| C-F003 | **Parcial, com limite semântico explícito.** O checker exige atestação estruturada, URL HTTPS sob `tse.jus.br`, ano/turno, datas, revisor, hash do snapshot e inclusão no manifesto para `pass` (`:84-160,278-279`). Rejeitou G8/T1 como `not_applicable`. Porém uma atestação sintética com URL textual do TSE, `coverage_pass: true` e snapshot contendo `not an official electoral publication` passou em `check_external`; o revisor humano deve abrir a publicação, validar cobertura e ocorrência. Isso está explicitado em `mebane_gate_agent_prompts.md`, seção “Publicação de 2026”. |
| C-F004 | **Parcial, com limite semântico explícito.** Run declara inputs/código/configuração/outputs; paths declarados devem integrar o manifesto, e review exige `manifest_complete: true` (`:217-246`). Arquivo declarado e omitido foi rejeitado. O checker não descobre código efetivamente usado mas não declarado, nem exige mecanicamente o snapshot `gate_contract.json` prescrito no prompt; o revisor deve conferir completude e snapshot antes de atestar. |
| C-F005 | **Fechado mecanicamente.** Adjudicação vincula `review_sha256`, reconcilia IDs e impede finding material não resolvido (`:247-273`). Alteração posterior do review foi rejeitada. |
| C-F006 | **Fechado.** `date` ausente, `routing=[]` e `G0.write_scope=[42]` produziram `FAIL` em `check` e `render`, sem traceback ou escrita de output (`:285-323,481-505`). |
| C-F007 | **Fechado.** `status=[]` e `basis=[]` produziram diagnóstico `FAIL`, sem traceback (`:324-325,378-392`). |
| C-F008 | **Fechado.** Título com aspas, nova linha e `G9 --> G0` foi rejeitado como unsafe Mermaid title (`:318-320`). |

O estado `not_applicable` tem controle mecânico de ano/turno 2026/T2, `allow_not_applicable`, atestação `turn_not_held`, snapshot e revisor (`:87-160,354-358,395-396`). Um fixture de G9 com declaração sintética passou estruturalmente; isso não prova não ocorrência oficial de T2. O prompt reserva essa comprovação ao revisor humano e não confunde `not_applicable` com `pass` nem com inferência executada.

## Achado novo

**C-F009, severidade major, aprovação de predecessor alterada sem invalidar dependente.** Localização: `scripts/mebane_gates.py:189-203`; contrato: `quality_reports/plans/mebane_gate_agent_prompts.md`, “Ciclo do coordenador” item 4 e “Reabertura”. O run do filho registra apenas `dependency_manifests`, hashes dos manifestos dos pais. Não registra nem confere a aprovação exata (revisor/review/adjudicação) que lhe permitiu iniciar.

Contraexemplo executado em `/tmp`: montei G0 e G1 `pass` com run, manifesto, review e adjudicação válidos; `validate(plan, root) == []`. Mantive intactos os dois manifestos e o run de G1, mas substituí `G0.review.reviewer_id` por outro UUID canônico, atualizei `G0.records.reviewer_id` e `G0.adjudication.review_sha256` para a nova revisão. O hash da revisão de G0 mudou; G1 continuou com o hash original do manifesto de G0 em `run.dependency_manifests`. `validate(plan, root)` permaneceu `[]`. Portanto, o checker aceita G1 após a aprovação concreta de G0 ter sido substituída, embora o protocolo determine reabrir os descendentes quando muda a aprovação de um predecessor. Vincular no run de cada filho os digests da revisão e da adjudicação aprovadas de cada predecessor, além do manifesto, e compará-los com os records vigentes; preservar snapshots das rodadas. O coordenador deve reabrir os descendentes já aprovados afetados por essa troca.

## Limites

Os testes provam comportamento do checker com artefatos sintéticos, não aprovação de qualquer gate analítico real. Os UUIDs de teste são apenas strings canônicas; identidade efetiva e independência são verificações documentais. A URL e o hash do TSE não provam oficialidade, suficiência da cobertura nem que T2 deixou de ocorrer. `manifest_complete: true` é uma atestação do revisor, não descoberta automática de arquivos usados. Não executei R, MCMC, instalação, análise eleitoral ou revisão estatística; o renderer foi conferido textualmente, sem QA visual. Round1 e candidato round2 foram preservados.
