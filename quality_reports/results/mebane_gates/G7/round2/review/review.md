# Parecer independente G7 round2

**Status: `pass`, restrito à prontidão operacional ensaiada do staging.** Os três findings confirmados na round1 estão reparados e encerrados nesta revisão. Não identifiquei novo defeito no alcance examinado. O parecer vincula-se ao candidato `2593c78b5687c883aff6441f09b5d2e67cd319c1ceae723d043dee44a36e62a6`, ao contrato canônico G7 `fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d` e à adjudicação anterior `882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a`. Revisor real: `01a0eb4a-fa6d-7463-9d5a-bad4dd08b3c0`, distinto do executor `01a0eb3a-6ea4-7f61-a66d-2805e495d1d0`.

| Finding anterior | Fechamento verificado |
|---|---|
| `G7-R1-COORD-F03`, major | ASCII e nomes UTF-8 acentuados, decompostos e com pontuação passam ponta a ponta em `C` e `pt_BR.UTF-8`. Configuração, CSV, snapshots e recibo preservam os bytes; inválidos, truncamento, overlong e NUL são rejeitados especificamente. O helper mantém o locale. |
| `G7-R1-QA-F01`, major | Datas T1/T2 são comparadas exatamente; divergências no mesmo ano e configurações malformadas são recusadas. T2 continua condicional e não tem código presumido. Casos 2026 coerentes nos dois turnos chegam ao erro exato de seleção `null`. |
| `G7-R1-QA-F02`, minor | UFs faltantes/extras são detectadas, o recibo identifica o universo e informa cobertura por UF. `reference_complete` descreve somente os EA16 recebidos; mesmo 28 siglas com uma seção cada deixam `national_coverage_attested=false`. |

Esses fechamentos preservam a classificação anterior `CONFIRMED`; o reparo verificado não reclassifica o defeito como refutado. As evidências por ID e os localizadores do código constam de `review.json`.

## Evidência executada

Executei **69 probes próprios em cada locale**, totalizando 138 execuções, com fixtures construídas pela QA e mensagens exatas nos casos negativos. Há controle ASCII, três formas de nome UTF-8, comparação de identidade exata, roundtrip do recibo e dos snapshots, byte inválido/NUL, datas exatas por turno, configuração antiga recusada, escopo por UF, cobertura parcial, controles divergentes, strings documentais quoted, chaves padded, mudança de política e de corpo de função, revisão de input e adulteração de campos derivados com `input_hashes` preservados. Os 25 recibos comparáveis entre os locales são idênticos byte a byte. Logs: `run01/C_independent/results.json`, `run01/UTF8_independent/results.json` e `verification.json`.

Reexecutei as suítes legada e de reparos do executor nos dois locales, os fixtures G1 e os 26 testes do checker. O antigo caso genérico que falha por data incompatível não serve como prova da seleção `null`: a evidência própria usa datas, códigos, cargo, controles e todas as UFs esperadas em 2026, em T1 e T2, e exige `Candidate selection unresolved for turn`.

Oito probes próprios do DAG construíram registros **sintéticos** coerentes, com todos os predecessores e vínculos de aprovação exigidos. G8 `pass` com G9 `waiting_external` ou `inconclusive` passou estruturalmente; G6/G7 pendentes e mero rótulo de aprovação foram recusados. G9 `not_applicable` exigiu atestação de não ocorrência, e ocorrência desconhecida foi recusada. Isso não criou autorização real. Evidência: `dag_probes/results.json`.

## Congelamento e alcance

Os **1.859 arquivos** do manifesto, o hash de `run.json` e o contrato estão íntegros. O mapa de recuperação corresponde ao hash fornecido, com **1.094 cópias**; os **1.066 arquivos originais da round1** permanecem intactos. Reconstituí a correspondência dos 275 itens do candidato anterior e dos 809 itens da QA anterior usando seus hashes e snapshots. Inventários de inputs, código, configuração, outputs e execução fecham com o manifesto. Os três hashes aprovados de G1 permanecem iguais. Os ensaios do executor `trial1` foram tratados como históricos; `final1` e a execução desta QA têm vínculos próprios.

A função de auditoria chamada pelo congelador teve 2.240 leituras efetivas de arquivos do projeto, todas cobertas pelo manifesto ou por cópias equivalentes no mapa de recuperação. O traço do checker e o da auditoria bloquearam o caminho do ledger mutável e não registraram tentativa de lê-lo. O congelador em si foi inspecionado, sem reexecutar a escrita do candidato. O primeiro traço classificou uma tentativa sem sucesso de ler cache Python inexistente como input externo; o diagnóstico foi corrigido e os dois logs ficaram preservados.

Conferi os PDFs EA11/EA16/EA18/EA20 e as instruções arquivadas, além da nota e URL do calendário. A nota contém 04/10/2026 e eventual 25/10/2026; seu HTML fonte não foi arquivado nem obtido novamente nesta rodada. O adaptador continua exigindo CSV normalizado por seção/candidato; falta o conversor auditado dos arquivos oficiais brutos. Cobertura nacional e conteúdo de uma publicação real exigirão verificação independente. Todos os recibos mantêm `data_ready=false`, `inference_ready=false` e `national_coverage_attested=false`.

O ledger foi lido explicitamente pela QA apenas para verificar preservação, conservando G2 `changes_requested`, G7 `under_review` e G8/G9 `waiting_external`. O estado real de G7 depende da adjudicação da coordenação. Não houve download, instalação, MCMC ou revisão metodológica ampliada. A ingestão continua serial ou sob lock externo; concorrência e desempenho nacional não foram reensaiados neste reparo. Tempos, comandos, logs e limites estão em `qa_run.json`; o manifesto próprio inclui todos os artefatos desta pasta.
