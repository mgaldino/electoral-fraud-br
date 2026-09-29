# G1 round2: reparos delimitados e candidato para QA

Estado: candidato do executor SOL-DADOS, sujeito a revisão independente e adjudicação. A conclusão do goal de entrega não aprova G1 nem autoriza estimação. Executor real: `01a0eaee-0164-7530-884d-adec564a8327`. Modelo/esforço solicitados: `gpt-6-sol`/`high`; modelo/esforço efetivamente usados: desconhecidos.

## Escopo e preservação

Esta rodada implementa somente F01/F02, autorizados em `G1/round1/adjudication.json`, e F03, autorizado separadamente em `G1/round1/adjudication_addendum.json`. F01/F02 vieram da QA Curie; F03 veio da contraprova **COORD-G1-R1**, não da QA original. As duas adjudicações, seus relatórios e suas contraprovas são inputs distintos do novo manifesto.

Antes da primeira edição de produção, `prepare_round.py` conferiu os 53 arquivos do manifesto revisado e copiou seus dez arquivos de código/configuração para `previous_candidate_sources/`. `previous_candidate_sources_map.json` registra origem, destino, SHA e `snapshotmatchedoldmanifest=true`. As cópias incluem o helper, a configuração e o teste preexistente que seriam alterados. A verificação posterior encontrou os 53 arquivos revisados recuperáveis por seus hashes e os 74 arquivos inicialmente inventariados da round1 inalterados. Os quatro arquivos do adendo F03, adicionados depois pela coordenação, estão registrados separadamente em `checks/round1_preservation.json`.

Arquivos preexistentes alterados nesta rodada: `R/lib/mebane_data.R`, `config/mebane/2022.json` e `tests/mebane/data/test_g1.R`. Os loaders `R/01_load_tse.R` e `R/02_build_vars.R` permanecem iguais aos bytes revisados. Foram adicionados testes em `tests/mebane/data/` e artefatos nesta round2. Nenhum raw, resultado histórico, fit, artefato G0/G2, ledger, README, CLAUDE ou nota congelada da coordenação foi editado por este reparo. Não houve instalação, atualização, acesso de rede ou MCMC.

## Reparos implementados

**F01: identidade eleitoral vinculada por turno.** `election_identity` exige código, data e tipo da eleição em cada turno configurado: T1 = `544`, `02/10/2022`, `2`; T2 = `545`, `30/10/2022`, `2`. O helper valida separadamente votação e detalhe contra essa referência antes de agregar. Erros iguais nas duas fontes deixam de ser aceitos pela mera concordância. O tipo passa a integrar os metadados preservados nas saídas.

Os valores foram conferidos, por leitura direta dos membros `_BR.csv` de ambos os ZIPs oficiais município/zona, em `checks/identity_official_anchors.csv`. Esses arquivos são extratos de resultados de 2022 gerados em 28/09/2026; não são configuração da eleição de 2026. O parser rejeita campos ausentes, mapas por turno incompletos/duplicados, formatos escalares e arrays incompatíveis, números fracionários, datas inválidas ou fora do ano configurado, códigos repetidos e datas fora da ordem dos turnos. Nenhum código ou candidatura de 2026 foi escolhido.

**F02: congelamento sem dependência do ledger mutável.** `freeze_candidate.py` lê o contrato estático da round1, verifica seu SHA de arquivo `2364acc589da079d44687c79c9fb35561816cfe7fd34ad7431f7c18386c1ae4d` e o SHA canônico `f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d`, e copia exatamente esses bytes para `gate_contract.json`. A canonicalização usa `sort_keys=true`, `ensure_ascii=false`, `separators=(',', ':')`. A entrada estática é declarada em `run.inputs`; o ledger não é lido nem incluído. O contrato não contém `status`, `records` ou `todos.status/evidence`.

O novo manifesto inclui inputs, código efetivamente consumido, configuração, resultados e run, com SHA explícitos. Também inclui os quatro ZIPs oficiais, mesmo ignorados pelo Git, os dois CSVs raw, os snapshots G0 de baseline, as fontes revisadas preservadas e as duas adjudicações. As dependências e aprovações G0 são exatamente as autorizadas pelo coordenador. O teste do congelador permite apenas a leitura do contrato estático e rejeita bytes alterados, hash canônico incorreto e campos mutáveis mesmo sob hashes recalculados.

**F03: todos os controles de candidatos declarados.** O loop deixou de fixar candidatos 13/22: percorre cada campo `candidate_<numero>` declarado. A configuração exige nomes canônicos sem zeros à esquerda, candidatos elegíveis naquele turno e valores escalares inteiros não negativos; rejeita duplicatas, campos malformados, candidatos de outro turno e categorias branco/nulo como candidato. O caso sintético de candidato 12 com um voto aceita controle 1 e rejeita 999 ou 0. Um candidato elegível ausente aceita controle zero somente após a reconciliação completa por categoria já exigida pelo loader. A configuração não é obrigada a declarar controles de todos os candidatos; todos os que declara são verificados.

## Execução e invariância

Todos os testes abaixo foram executados nesta rodada, não apenas herdados da round1. Os comandos literais, horários UTC, duração, exit code, escopo e stdout/stderr estão em `logs/*.json` e `logs/*.txt`, indexados no run.

Tabela 1. Verificações executadas na round2 e evidência principal.

| Verificação | Resultado observado | Evidência relativa à round2 |
|---|---|---|
| Regressões F01/F03 e formas de configuração | 64/64; 60 rejeições esperadas, quatro aceitações válidas | `checks/repair_regressions.csv` |
| Fixtures preexistentes | Exit 0, incluindo duplicatas, omissões, missing, schema e elegibilidade | `logs/existing_fixtures.txt` |
| Identidades oficiais nos dois extratos | 16/16 comparações iguais | `checks/identity_official_anchors.csv` |
| Contrato estático F02 | Leituras restritas e rejeições de corrupção passaram | `logs/static_contract_test.txt` |
| Load e build 2022 completos | 944150 seções-turno, 5380736 linhas de votação e 944150 linhas de modelo | `outputs/2022_final/` |
| Agregação alternativa relendo os raw | Totais por UF/turno e candidato/turno iguais | `outputs/2022_final/independent_raw_uf_turn.csv` |
| Históricos oficiais e extratos município/zona | Sem divergência nos controles testados | `outputs/2022_final/official_history_reconciliation.csv`; `official_munzona_uf_turn_reconciliation.csv`; `official_munzona_candidate_uf_turn.csv` |
| Nova execução com mesmos inputs/configuração | Nove produtos centrais byte-idênticos dentro da round2 | `outputs/2022_final/deterministic_replay.csv` |
| Comparação linha a linha com round1 | Mesmas chaves, tipos e valores de todas as colunas anteriores nos três Parquet | `checks/round1_rowwise_invariance.csv` |
| Comparação de agregados com round1 | Nove relatórios de agregação/controle byte-idênticos | `checks/round1_aggregate_invariance.csv` |

Os Parquet **não são byte-idênticos entre versões**: a única coluna adicionada é `CD_TIPO_ELEICAO`, com valor 2. Nenhuma coluna antiga foi removida ou teve valores alterados. `source_metadata.csv` também ganhou o tipo e o hash da configuração mudou por conter a identidade explícita. Essas diferenças são esperadas e não representam drift de totais ou de chaves. A igualdade byte a byte foi exigida somente entre as duas execuções da mesma versão/configuração.

As regras do alvo de contagens permanecem as da round1: `N=QT_APTOS`, `a=N-QT_COMPARECIMENTO`, `w` do candidato alvo, preservando separadamente as contagens físicas originais. Exterior e seções pequenas permanecem com flags. Os 99 casos de nominais zero continuam no arquivo; os 94 registros de discrepância aptos/comparecimento/abstenções continuam presentes e marcados `model_eligible=false`. O líder nacional calculado é 13 em cada turno. O número de linhas elegíveis continua 472028 por turno. Nenhum estimando, corte de amostra ou regra de exclusão foi introduzido por este reparo.

## Reprodução e limites

Na raiz do projeto, para uma nova execução, usar um diretório ainda inexistente:

```sh
Rscript --vanilla R/01_load_tse.R config/mebane/2022.json NOVO_DIRETORIO
Rscript --vanilla R/02_build_vars.R config/mebane/2022.json NOVO_DIRETORIO
Rscript --vanilla tests/mebane/data/test_g1.R --full NOVO_DIRETORIO
Rscript --vanilla tests/mebane/data/check_official_histories.R NOVO_DIRETORIO
Rscript --vanilla tests/mebane/data/check_official_munzona.R NOVO_DIRETORIO
```

Os caminhos exatos usados nesta rodada são `outputs/2022_final` e `outputs/2022_replay`, sob esta pasta; os comandos completos estão nos logs. Os loaders continuam recusando diretórios/produtos preexistentes e configuração alterada entre etapas. Não há default que sobrescreva saídas históricas. Os scripts de comparação adicionados recebem diretórios de relatório/saída explícitos. `python3 quality_reports/results/mebane_gates/G1/round2/freeze_candidate.py --check` verifica o pacote congelado sem o modificar; o congelamento padrão recusa sobrescrever run ou manifesto existentes.

Os controles oficiais preservam a distinção de fontes da round1: históricos congelados em 2022, extratos município/zona gerados em 2026 e controles das notícias transcritos na configuração. Não se certifica a autenticidade da aquisição histórica dos CSVs dos autores nem ausência de revisões em campos/linhas não comparados aos extratos oficiais. A diferença de 657 aptos por turno não foi corrigida nos dados; os 47 registros de seções não instaladas por turno seguem explicitados. Os avisos de locale e de introspecção de hardware do Arrow no sandbox estão preservados nos logs; todos os comandos de teste encerraram com exit 0.

As regressões e agregações alternativas do executor não substituem a reprodução própria da QA. `todo_evidence.json` e `repair_evidence.json` mapeiam o trabalho executado e os três reparos para evidências; não constituem parecer de aprovação. O coordenador deverá despachar a QA independente e adjudicar o novo candidato antes de promover G1.
