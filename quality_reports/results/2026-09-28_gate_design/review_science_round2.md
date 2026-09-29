# QA-PLANO: rechecagem científica delimitada, round2

**Status: `pass`.** S-F001, S-F002 e S-F003 estão resolvidos no protocolo congelado. Não foram encontrados novos achados materiais nem pendências materiais residuais no escopo desta rechecagem. Este resultado aprova o desenho documental dos gates, não o checker, a execução dos gates ou a validade empírica do qbl.

Data local: 2026-09-28, America/Sao_Paulo. Revisor: QA-PLANO, ID nativo `01a0ea8e-ac85-76d1-8470-271c7dc6e6bd`. Autor/executor identificado no manifesto: `019d795a-acfa-72c2-a210-d55a46c606c2`. São identidades distintas. Este revisor não escreveu os reparos, não alterou candidatos e não consultou notas de autoaprovação. Criou novo goal nativo finito, sem budget, após verificar que não havia goal ativo neste contexto.

## 1. Vínculo e Escopo

Raiz: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud`.

Manifesto: `quality_reports/results/2026-09-28_gate_design/candidate_science_round2.json`.

SHA-256 do manifesto: `65acd106397a115c73b0ae50ee256091d9c892c9238f3cac25f05fba2f50a6c1`.

| Documento científico | SHA-256 esperado e observado |
|---|---|
| `quality_reports/plans/mebane_2022_2026_gates.json` | `fc44b2c192b432f0b8754adf974ffc582f7f942fa091df0edef14b081b6a0e39` |
| `quality_reports/plans/mebane_gate_agent_prompts.md` | `793063d3e74be4d8b49535f3ade07da4a440f3ccc22a306fb846bf84f505bc2c` |
| `quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md` | `6e883902133b12c16fdbb997283e5474dd9b04e91bd7219df1c509cf68588db7` |

Os três hashes conferiram na entrada e foram reconferidos na entrega. Não foi detectado `hash mismatch`. A autoridade é o JSON; os prompts foram lidos e confrontados com ele; o MD foi inspecionado nas seções alteradas e comparado textualmente com o conteúdo do JSON. O código do checker e seus testes, em reparo separado, não foram lidos, executados ou incluídos neste vínculo.

O parecer round1 foi usado como lista de rechecagem. A classificação anterior dos três achados como CONFIRMED foi informada pelo usuário; a resolução abaixo foi verificada nos documentos exatos, não inferida dessa classificação. Os pareceres round1 permanecem inalterados, com hashes `99cf42f550cc9f7511c6fc642ba9a8f2336df6eb9a2e4c7eb9363b9f6d1d8eee` (MD) e `88d84516b300e4f7c92e0baab9535a0fb3dfac44789fe8ed95137bf2028df215` (JSON).

## 2. Achados Resolvidos

### S-F001 | Resolvido | Calibração anterior à confirmação

**Achado original:** "G4 exige medir recuperação, cobertura e falsos positivos, mas não exige congelar uma regra de detecção e critérios de aprovação dessas medidas antes da avaliação confirmatória; G6 herda essa lacuna ao concluir a análise de poder."

**Evidência do reparo:** JSON, linhas 146-153, G4-T2/T5/T6 e acceptance; prompts, linhas 44-50; MD, linhas 235-256.

G4-T2 agora identifica os pilotos como exploratórios. G4-T5 exige `calibration_contract.json` com regra/evento de detecção, unidade, cenários, estimandos, tolerâncias justificadas, precisão Monte Carlo, tratamento de réplicas falhas e afirmações permitidas por poder. Exige ainda especificações, réplicas, sementes novas e revisão independente antes de G4-T6. G4-T6 usa simulações/seeds distintas dos pilotos e aplica as regras sem reajustar limiares após os resultados.

A aceitação atribui ao revisor principal a aprovação prévia, exige evidência de precedência por hashes/timestamps/seeds e prevê reprovação ou inconclusividade por cobertura inadequada, falsos positivos excessivos ou precisão insuficiente. Os prompts chamam essa etapa de checkpoint obrigatório e esclarecem que ela não aprova G4 inteiro. G6 continua obrigado a aplicar os critérios aprovados em escala nacional (JSON, linhas 190-196), sem converter baixo poder em ausência de fraude.

**Decisão:** atende ao critério de rechecagem do round1. Não se exige preencher agora tolerâncias numéricas que o protocolo manda justificar e aprovar antes da avaliação futura. O reparo fixa responsável, artefato, ordem e consequência, sem confundir piloto com confirmação.

### S-F002 | Resolvido | Identidade imutável do contrato e dos predecessores

**Achado original:** "O contrato do gate é entregue ao revisor, mas o protocolo não exige arquivar seu snapshot e hash no vínculo de aprovação; mudanças de critérios ou dependências podem conservar um parecer cujo manifesto continua idêntico."

**Evidência do reparo:** JSON, linhas 23 e 34-39; prompts, linhas 26-29, 79-86, 157-201 e 224-232; MD, linhas 77 e 89-94.

O protocolo passa a exigir `gate_contract.json` no manifesto e `contract_sha256` na identidade da rodada. A projeção estática exclui somente `status`/`records` do gate e `status`/`evidence` dos todos. Os prompts definem sua serialização em JSON canônico, UTF-8, com chaves ordenadas e sem espaços. Alteração de aceitação, objetivo, tarefa ou dependência invalida a aprovação mesmo sem mudança do código.

`run.json` registra `dependency_manifests`, relacionando cada predecessor ao SHA-256 de seu manifesto vigente. O run integra o manifesto do candidato; review e adjudication vinculam esse manifesto e a identidade da rodada; a adjudicação também vincula `review_sha256`. Portanto, os predecessores ficam ligados transitivamente aos pareceres, sem exigir duplicação de todos os campos. A regra de reabertura abrange contrato, aprovação de predecessor e arquivos manifestados.

**Verificação independente:** apliquei em memória a projeção descrita ao G4, sem importar o checker. Alterar status/records/evidências operacionais preservou o hash; alterar uma cláusula de aceitação mudou o hash. O hash calculado da projeção original foi `9b3955d2a43a370b418ceac010aa27ec441c868c6e6a06a938eb6e7759773bed`. Este teste verifica a regra documental de identidade; não é teste do código em reparo.

**Decisão:** atende ao critério do round1. O contrato passa a ser um artefato obrigatório e a revisão antiga não serve para um critério novo. A exigência de completude do manifesto depende também da inspeção independente, limitação explicitada pelo próprio protocolo.

### S-F003 | Resolvido | Turnos e não aplicabilidade separados

**Achado original:** "G8 exige execução, espera e inconclusividade por turno, mas oferece somente um status, um conjunto de todos e um records; falta a regra que permita concluir T1 sem aprovar, sobrescrever ou manter indefinidamente ativo o trabalho de T2."

**Evidência do reparo:** JSON, linhas 30-31, 44, 214 e 222-264; prompts, linhas 145-147 e 203-222; MD, linhas 354-421.

G8 tem `election_scope` 2026/T1 e G9 tem 2026/T2. Possuem goals, todos, revisores, estados, records e diretórios distintos. Ambos dependem de G6/G7, mas nenhum depende da conclusão do outro. G8 declara expressamente que seu goal pode encerrar sem T2 e seu pass não altera G9.

Somente G9 admite `not_applicable`, mediante atestação independente de não ocorrência oficial de T2. A ausência de publicação mantém `waiting_external`; falha inferencial mantém `inconclusive`. Os prompts especificam `records.applicability_evidence`, `requirement: "turn_not_held"` e `occurrence: "not_held"`; o encerramento é apenas da verificação de aplicabilidade, sem marcar os todos analíticos como executados.

Os caminhos imutáveis por ano/turno/SHA-do-snapshot/roundN e a preservação de manifests/records anteriores distinguem retificação de entrada de nova rodada de revisão. G7-T4 inclui os casos de ensaio pedidos: G8 pass/G9 waiting_external, G8 pass/G9 inconclusive e G9 not_applicable apenas por não ocorrência oficial.

**Decisão:** atende ao critério do round1. As três situações podem ser representadas sem aprovação conjunta implícita nem perda do registro de T1. Atestar não ocorrência não equivale a realizar ou dispensar a inferência de um turno ocorrido.

## 3. Coerência, Regressão e Limites

| Checagem | Resultado |
|---|---|
| Integridade e preservação | Três fontes científicas iguais ao manifesto; pareceres round1 preservados |
| Gates/todos | 10 gates e 45 todos; oito gates `queued`, G8/G9 `waiting_external`; todos `todo`, sem evidências e com `records` nulos |
| DAG | Acíclico, sem dependência ausente; camadas: G0; G1/G2; G3/G7; G4; G5; G6; G8/G9 |
| JSON/MD | 171 trechos de objetivos, tarefas, entregáveis, aceitação, falhas, requisitos externos e regras globais conferidos literalmente; 12 arestas correspondentes |
| JSON/prompts | Checkpoint G4, identidade de contrato, referências dos predecessores, reabertura e regras de T1/T2 coerentes |
| Goals e independência | Entrega do executor continua distinta de pass; revisor separado e adjudicação permanecem obrigatórios; orçamento não é presumido |
| Sol/modelo herdado | Roteamento heurístico mantido; revisão matemática/inferencial e novos revisores de G8/G9 em `inherit`, sem alegação de benchmark |
| Alvo e engines | G2/G3 continuam exigindo derivação/fidelidade; aproximação Stan rotulada; comparação de equivalência apenas no mesmo alvo |
| Inferência e interpretação | Não convergência/identificação não são dispensadas; validação nacional e por turno permanece exigida; sem prova automática de fraude/ausência |
| Dados e recursos | G1 mantém reconciliação e tratamento de zeros/missing; G5 mantém limites, preflight, teste de falha e proibição de alteração silenciosa do alvo |

**Novos achados:** nenhum. **Achados materiais residuais:** nenhum. As obrigações abaixo são limites de uso e verificações futuras já exigidas pelo plano, não novos bloqueios documentais:

- O contrato de calibração ainda terá de ser produzido, justificado, aprovado e cumprido. O pass deste parecer não substitui esse checkpoint nem demonstra poder, cobertura ou convergência.
- A execução correta do checker, inclusive canonização, linhagem dos predecessores e tratamento de `not_applicable`, pertence à revisão mecânica separada. Nenhuma aprovação de código é inferida aqui.
- A oficialidade, ocorrência dos turnos e suficiência de dados de 2026 exigem inspeção real no momento apropriado. Não foram consultados nem presumidos resultados eleitorais.
- Não houve nova auditoria integral do qbl, leitura de seus PDFs/código, MCMC, instalação, execução de gates ou mudança do candidato. As checagens executadas foram de hashes, estrutura textual/JSON, DAG e projeção de contrato em memória.

O goal desta rechecagem termina com a entrega verificada de `review_science_round2.md` e `review_science_round2.json`. O pass é científico-documental e vinculado aos três hashes acima; não altera estados do ledger, não substitui a adjudicação do coordenador e não amplia a autorização operacional.
