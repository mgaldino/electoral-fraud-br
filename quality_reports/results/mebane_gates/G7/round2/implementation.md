# G7 round2: reparos de prontidão operacional

O candidato implementa os três reparos seguros confirmados na adjudicação round1 de SHA-256 `882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a`. As regressões executadas passaram. G7 permanece pendente de QA independente e adjudicação da round2; este documento não aprova o gate.

## Resultado dos reparos

| Finding | Reparo | Evidência executada |
|---|---|---|
| G7-R1-COORD-F03 | Validação explícita dos bytes UTF-8 antes do parsing; leitura com `encoding="UTF-8"` e `fileEncoding=""`, sem mudar o locale global. Nome do candidato preservado também no recibo e nos snapshots. | `test_round2.R`, casos `F03_*`: nome `JOSÉ DA CONCEIÇÃO` e sequência Unicode decomposta preservados byte a byte; byte inválido e NUL recusados; releitura idempotente aprovada. |
| G7-R1-QA-F01 | `election_dates` obrigatório por turno e comparação exata com EA11 `pl.dt`; validação de data real, ano e ordenação. | Casos `F01_*`: datas 2022 corretas aceitas, 03/10 e 29/10 recusadas para T1/T2, configuração incompleta ou data impossível recusada. |
| G7-R1-QA-F02 | Configuração declara universo territorial e UFs esperadas; EA16 com UF ausente ou extra falha. O recibo informa universo, UFs esperadas/referenciadas/observadas e contagens por UF. | Casos `F02_*`: completude do fixture no escopo declarado, uma seção com completude apenas relativa à referência, UF faltante/excedente, votos parciais por UF e adulteração do recibo. |

O campo `validation.complete` foi substituído por `validation.reference_complete`. Essa mudança remove a ambiguidade: a completude diz respeito às seções principais dos EA16 fornecidos. `validation.national_coverage_attested` é sempre `false`. A configuração presidencial 2026 declara as 27 UFs brasileiras e `ZZ` para exterior como escopo pretendido; a presença dessas siglas não atesta que os EA16 contenham todas as seções do país. Não foi introduzido total esperado de seções/votos de 2026.

O schema de configuração passou a `g7-intake-v2`, com datas e escopo territorial obrigatórios. Configurações antigas incompletas falham explicitamente. O fixture 2022 declara apenas as seções sintéticas SP dos EA16 fornecidos, sem alegar censo estadual. O ensaio multi-UF antigo foi atualizado para declarar AM/SP, e o teste de adulteração agora altera `reference_complete`. O teste de DAG lê o snapshot copiado para round2. Essas são as mudanças justificadas nas regressões antigas; todos os seus cenários passaram nos três ambientes.

## Execução e preservação

Antes de editar fontes/fixtures, `prepare_round.py` verificou 275 arquivos do manifesto anterior e 809 do manifesto QA e copiou 1.094 caminhos distintos para `previous_sources/`. `recovery_map.json` vincula cada caminho original à cópia, tamanho e SHA-256, inclusive as fontes mutáveis. `previous_round1_inventory.json` preserva o inventário completo dos 1.066 arquivos de round1/QA. `audit_integrity.py` confirmou os bytes preservados e a ausência de alterações em round1 e nas dependências fora do escopo. Como as fontes de trabalho avançaram, a reconstrução do candidato anterior deve resolver seus caminhos pelo mapa de recuperação; o manifesto antigo e suas aprovações permanecem inalterados.

Comando do ensaio final: `PYTHONDONTWRITEBYTECODE=1 python3 quality_reports/results/mebane_gates/G7/round2/run_suite.py final1`. O script lançou processos R independentes com `--vanilla`, executou as regressões antigas e 20 casos de reparo em cada ambiente e registrou comandos, ambiente, exit codes, tempos e hashes de código/inputs antes e depois em `executions/final1/execution.json`. Todos os nove comandos terminaram com exit 0 e os inputs permaneceram idênticos. O conjunto inclui fixtures G1 e 26 testes do checker, além da rejeição específica de G8/G9 `pass` sem G6. A primeira execução `trial1` também passou e foi preservada; a repetição final acrescentou a vinculação explícita dos testes aos hashes, sem mudança na implementação R.

| Ambiente solicitado | LC_CTYPE efetivo | Regressores |
|---|---|---|
| `LC_ALL=C` | `C` | Ensaio legado e 20 casos de reparo passaram. |
| Ambiente padrão herdado | `C` | Ensaio legado e 20 casos passaram; o ambiente herdou `C.UTF-8`, indisponível neste macOS, e o R iniciou em `C`. Avisos de inicialização estão no log. |
| Locale UTF-8 presente em `locale -a` | `pt_BR.UTF-8` | Ensaio legado e 20 casos passaram. |

O locale antes/depois permaneceu idêntico dentro de cada execução. A sequência esperada para o nome acentuado é `4a4f53c38920444120434f4e434549c387c3834f`, preservada em todas elas. R 4.4.2, jsonlite 2.0.0 e digest 0.6.37 foram usados. `integrity_final.json` registra a checagem dos 39 recibos finais: `data_ready=false`, `inference_ready=false`, `national_coverage_attested=false` e somas por UF consistentes com a referência fornecida.

O contrato canônico G7 continua `fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d`. O snapshot DAG é byte-idêntico ao da round1; o ledger mutável não é input do ensaio ou congelador. Os hashes exatos do manifesto, review e adjudicação G1 round2 foram reconferidos e constam de `run.json`.

## Roteiro e limites mantidos

1. Para cada turno e snapshot real, arquivar URL efetivamente obtida, data de publicação/acesso, bytes e SHA-256 das referências e arquivos recebidos. Conciliar ambiente, fase, ano, data, cargo, pleito, eleição e turno. EA11/EA16 continuam exigindo códigos decimais quoted; município/zona/seção preservam cinco/quatro/quatro dígitos e zeros à esquerda.
2. As datas configuradas são 04/10/2026 e eventual 25/10/2026, conforme calendário TSE registrado no preflight de 28/09/2026. A URL e a data de consulta estão na configuração. A data prevista de T2 não afirma ocorrência nem fornece código de eleição; os candidatos seguem `null`. Pleito 3220/eleição federal 6257 T1 devem concordar com o EA11 recebido.
3. Produzir o CSV normalizado por seção e candidato somente mediante futuro conversor auditado dos arquivos brutos oficiais. Esse conversor ainda não existe. EA20 é agregado até zona e não substitui voto por seção; EA18 auxilia a localizar arquivos de urna. Este reparo não muda o escopo científico ou escolhe modelo/engine.
4. Declarar o universo pretendido na configuração, fornecer os EA16 independentes e controles comparáveis e executar `g7_stage()` de forma serial, ou sob lock externo. Revisões criam versões novas; duplicatas recalculam todo o recibo e conferem os snapshots. A versão inclui impressão de código/política; recibos antigos não são herdados após mudança de política. A operação não oferece garantia de concorrência.
5. Encaminhar snapshots, referências, controles e candidato à QA. Todas as flags de liberação permanecem falsas. `g7_gate_route()` continua `example_only=true` e `records_verified=false`; seus rótulos não autorizam inferência. G8/G9 dependem de G6/G7 aprovados. A ausência de dados T2 permanece distinta de não ocorrência oficialmente atestada; `not_applicable` requer a segunda.

Foram executados ensaios sintéticos e verificações de integridade. Não foram recebidos votos reais de 2026, adquiridos dados, instalados pacotes, executados MCMC ou testada escala nacional de memória/desempenho. A checagem UTF-8 atualmente lê os bytes do arquivo inteiro antes do parsing; grandes arquivos exigirão avaliação de recursos na recepção futura. A coordenação despachará QA independente para o novo hash.
