# Vínculos e inspeção de fontes G7 round2

O contrato canônico foi recomposto independentemente de `gate_contract.json`. `run.json` declara 1.113 inputs, 12 arquivos de código, três configurações e 730 outputs; somados ao próprio run, são 1.859 caminhos únicos. Cada caminho foi aberto e conferido por bytes e SHA-256. O `recovery_map.json` fornece 1.094 destinos congelados, todos no manifesto. As 1.066 entradas de round1 foram também confrontadas com os originais atuais, sem mudança. Os manifestos antigos resolvem os 275 e 809 itens por essas cópias, incluindo as cinco fontes/fixtures que avançaram na round2.

`freeze_candidate.py` usa contrato estático e chama `audit_integrity.audit()`. Examinei ambos integralmente, além de `prepare_round.py`, `run_suite.py`, `check_dag.py`, testes reparados e helper R. Executei a função de auditoria com interceptação de aberturas: nenhum acesso ao ledger mutável, 2.240 leituras efetivas e nenhum input descoberto sem vínculo direto ou snapshot equivalente. O congelador não foi reexecutado. O checker usou `round2/ledger_dag_snapshot.json`; os caminhos homônimos em G0 são snapshots congelados, distintos do ledger vivo.

## Referências oficiais já arquivadas

As extrações completas dos cinco PDFs congelados foram gravadas como logs `run01/tse-*.log` por `pdftotext -layout`, sem nova aquisição. EA11 pp. 1-2 representa `pl.cd`, `e.cd`, `e.t` e `cp.cd` entre aspas; p. 3 distingue fase simulada e oficial. EA16 pp. 1-3 documenta `cdp` quoted e município/zona/seção com cinco/quatro/quatro posições, incluindo zeros à esquerda; `nsp` indica agregação a uma principal. EA18 pp. 1-3 descreve hashes de arquivos de urna por seção. EA20 pp. 1-3 enumera BR/UF/município/zona e não fornece substituto dos votos por seção. As instruções pp. 3-4 usam EA11 para diretórios e separam ambiente oficial/simulado.

As datas 2026 provêm de `coordination/tse2026_source_preflight.md`, cuja URL é a mesma de `config/mebane/2026/intake.json:10`: `https://www.tse.jus.br/comunicacao/noticias/2026/Marco/eleicoes-2026-confira-as-principais-datas-do-calendario-eleitoral`. A nota registra consulta em 28/09/2026, T1 em 04/10/2026 e eventual T2 em 25/10/2026. Não há PDF/HTML integral do calendário nesse pacote; os PDFs técnicos documentam o formato, e a nota/URL fornecem a âncora de calendário. Essa fronteira documental não foi convertida em atestação externa de ocorrência ou publicação.

## Regressões e preservação

O código agora exige `g7-intake-v2` e datas/território; `g7-intake-v1` falha explicitamente. `reference_complete` substitui o antigo `complete`. Os snapshots antigos e recibos da round1 permanecem recuperáveis; a impressão de política e código impede herdar a versão anterior. Os probes modificaram somente funções em memória e recibos/snapshots de QA dentro de round2/review. Os testes do executor rodaram com saídas e TMPDIR nessa mesma pasta e `PYTHONDONTWRITEBYTECODE=1`, sem gerar cache fora do escopo.

O relatório inicial `integrity_read_trace.json` marcou como uncovered uma tentativa de abertura de `__pycache__/audit_integrity.cpython-313.pyc`; esse caminho não existia. `integrity_read_trace_final.json` registra separadamente a tentativa frustrada e confirma todas as leituras efetivas. Isso é correção da instrumentação QA, não finding contra o candidato. Nenhum output anterior foi substituído para ocultar o diagnóstico.
