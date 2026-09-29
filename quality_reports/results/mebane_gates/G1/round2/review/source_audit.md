# Auditoria dos insumos efetivamente lidos

QA-DADOS `01a0eb01-0a01-7a10-b432-d1f2cdbd12f8`, candidato
`517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8`.

O manifesto contém 194 arquivos. Foram recalculados SHA-256 e tamanho de todos,
conferida a igualdade entre seus caminhos e a união de `run.inputs`, `code`,
`configuration`, `outputs` e o próprio `run.json`, e conferido o mapa
`component_sha256` inteiro. A verificação semântica de completude também incluiu
as leituras abaixo; fechamento de listas, isoladamente, não seria suficiente.

| Código inspecionado | Insumos e tratamento no manifesto |
|---|---|
| `R/01_load_tse.R`, `R/02_build_vars.R`, `R/lib/mebane_data.R` | Configuração, helper, dois CSVs de seção e, no build, os dois parquets intermediários e o hash da configuração. Todos declarados; os intermediários estão em outputs. |
| `tests/mebane/data/test_g1.R`, `test_round2_repairs.R` | Configuração/helper, brutos no modo full e produtos do diretório da execução. Fixtures são geradas pelo código versionado. |
| `check_official_histories.R`, `check_official_munzona.R`, `check_round2_identity_sources.R` | Quatro ZIPs arquivados, apenas membros `_BR.csv` para município/zona, configuração e CSVs/parquets derivados. Todos declarados. |
| `check_replay.R`, `check_round1_invariance.R` | Produtos de round1 e dos dois diretórios round2. Os antigos são inputs, os novos são outputs; ambos estão cobertos por hashes. |
| `prepare_round.py`, `verify_preservation.py` | Manifesto/run round1, arquivos enumerados no manifesto, árvore round1, mapa das cópias e snapshot da árvore. As versões anteriores de código/configuração estão preservadas em `previous_candidate_sources/`, vinculadas aos hashes anteriores. |
| `freeze_candidate.py` | Lê o contrato estático round1 com hash de arquivo e hash canônico esperados, o manifesto antigo, mapa de fontes, árvore anterior, verificação de preservação, aprovações G0, logs de comandos e runtime. Todos os caminhos efetivamente usados estão no manifesto, inclusive artefatos intermediários classificados como outputs. Não lê o ledger mutável. |
| `test_round2_freeze.py` | Carrega o congelador e lê o contrato estático. As variações temporárias do contrato são geradas no teste; os fontes/contrato estão declarados. |
| `run_logged.py`, `capture_runtime.R` | Capturam saídas de processos, horários e versões instaladas. Logs e runtime estão congelados; bibliotecas instaladas são a dependência de ambiente descrita no G0 e verificadas novamente na QA. |

A função de leitura de contrato do candidato foi chamada sob guarda de I/O:
o único arquivo lido foi `G1/round1/gate_contract.json`. Mudança de bytes e hash
canônico errado foram rejeitados. A inspeção do restante do congelador confirmou
que o ledger só é mencionado para proibir sua inclusão como dependência.

Recuperação anterior: dez cópias de código/configuração coincidem com o manifesto
round1; os 53 itens daquele manifesto são recuperáveis, 74 arquivos da árvore
anterior permanecem iguais e quatro acréscimos posteriores da coordenação estão
explicitamente registrados. Os bytes do parecer QA round1 também permanecem
iguais. Evidência executada: `audit_integrity.py`, `integrity_results.json` e
`logs/integrity_final.json`.
