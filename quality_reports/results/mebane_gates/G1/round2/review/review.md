# QA-DADOS: parecer independente de G1 round2

**Parecer: `pass`, com `manifest_complete=true` e nenhum achado novo.** F01 e
F02 do parecer QA round1 e F03 da contraprova adicional `COORD-G1-R1` foram
confirmados nas adjudicações e estão reparados. Permanecem registrados como
`resolved_prior_findings`, sem reclassificação como `REFUTED`. A coordenação
ainda deve adjudicar este parecer para promover o gate.

Revisor: `01a0eb01-0a01-7a10-b432-d1f2cdbd12f8`.
Executor: `01a0eaee-0164-7530-884d-adec564a8327`.
Manifesto revisado: `517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8`.
Contrato canônico: `f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d`.
As três dependências G0 coincidiram exatamente com os hashes fornecidos.

## Fechamento dos achados anteriores

| Achado | Origem | Verificação independente e resultado |
|---|---|---|
| G1-R1-QAD-F01 | QA-G1-R1; adjudication.json | Configuração contém código, data e tipo eleitoral por turno. As identidades coincidem com os dois CSVs brutos e os dois extratos oficiais arquivados. Erros compartilhados pelos dois CSVs, ou presentes em apenas um, são rejeitados. Reparado. |
| G1-R1-QAD-F02 | QA-G1-R1; adjudication.json | Congelador usa o contrato estático round1, confere hash dos bytes e hash canônico e não lê o ledger mutável. Foram auditados 194 arquivos, os componentes do run e as leituras do código. Os 53 itens do manifesto anterior são recuperáveis; dez cópias de fontes/configuração são exatas. Reparado. |
| G1-R1-COORD-F03 | COORD-G1-R1; adjudication_addendum.json | Todos os controles declarados são percorridos. Testes próprios para candidatos 12 e 30, além de 13/15/22, rejeitam controles incorretos; nomes, valores, duplicidades e elegibilidade inválidos também são rejeitados. Reparado. F03 não é atribuído à QA round1. |

`adversarial_review.R` executou 43 casos próprios, com 42 rejeições esperadas
e um cenário válido que inclui candidato elegível sem linha e controle zero.
As fixtures existentes passaram, assim como as 64 regressões do executor e
seus testes do contrato estático, reexecutados com saídas dentro desta review.
A primeira execução do script QA encontrou um erro na impressão de tabela;
ele foi corrigido e a execução final passou. Ambos os logs estão preservados.

## Reprodução e controles

`independent_data.R` releu os dois CSVs brutos, os históricos nacionais e apenas
os membros `_BR.csv` dos arquivos oficiais de município/zona, sem usar helper
do executor para produzir os dois lados da comparação. Conferiu 944.150 linhas
de detalhe, 5.380.736 linhas de votos, 56 pares UF-turno, 364 combinações
candidato-UF-turno e 84 zonas com seções não instaladas. Todos os controles
coincidiram, incluindo 47 seções não instaladas e 657 aptos por turno. As 99
linhas de nominais zero permanecem no arquivo de contagens.

Tabela 1. Totais nacionais reobtidos dos CSVs brutos, em contagens. Abstenção
reportada conserva o campo original; a diferença de 657 por turno em relação
a `N-comparecimento` corresponde aos eleitores das seções não instaladas.

| Turno | Seções | Aptos | Comparecimento | Abstenções reportadas | Nominais | Brancos | Nulos |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 472075 | 156454011 | 123682372 | 32770982 | 118229719 | 1964779 | 3487874 |
| 2 | 472075 | 156454011 | 124252796 | 32200558 | 118552353 | 1769678 | 3930765 |

As duas execuções próprias da CLI estão em `cli_2022/` e `cli_replay/`. Os
nove produtos centrais são byte-idênticos entre essas duas execuções e os
diretórios final/replay do executor em round2. Foram reconstruídos diretamente
`N`, `a` e `w` para cada seção, sem violação dos limites físicos. Permanecem
472.028 linhas elegíveis por turno, 1.064 de exterior e 31 de seções pequenas
sinalizadas, sem exclusão automática; o líder nacional é 13 em ambos os turnos.

A comparação linha a linha entre round1 e round2 conferiu todas as 70 colunas
anteriores: 22 em sections, 14 em votes e 34 em model_counts. Valores, tipos,
chaves e contagens permanecem iguais. A única coluna nova nos três parquets
é `CD_TIPO_ELEICAO=2`, explicando a mudança dos respectivos hashes.

Todos os itens G1-T1 a G1-T5 estão cobertos; o mapa de critérios e evidências
consta de `review.json`. A auditoria adicional de leituras e insumos está em
`source_audit.md`. A preservação conferiu os 74 arquivos da árvore anterior e
quatro acréscimos documentados da coordenação, sem perda dos bytes revisados.

## Reprodução da QA e limites

Comandos principais, executados da raiz do projeto:

```sh
python3 -B quality_reports/results/mebane_gates/G1/round2/review/audit_integrity.py
Rscript --vanilla quality_reports/results/mebane_gates/G1/round2/review/adversarial_review.R
Rscript --vanilla R/01_load_tse.R config/mebane/2022.json NOVO_DIRETORIO_DENTRO_DA_REVIEW
Rscript --vanilla R/02_build_vars.R config/mebane/2022.json MESMO_DIRETORIO
Rscript --vanilla quality_reports/results/mebane_gates/G1/round2/review/independent_data.R
```

`qa_run.py` registrou os argumentos exatos, códigos de saída, horários e tempos
em `logs/`; `qa_run.json` reúne esses registros. Cada carga limpa levou cerca
de 10,5 segundos, cada build 2,7 segundos, e a reconciliação independente com
comparação dos parquets levou 18 segundos. Diretórios da CLI precisam ser novos;
o script independente compara os nomes `cli_2022` e `cli_replay` já preservados.
`qa_manifest.json` vincula os insumos e todos os artefatos finais da QA por hash.

Os CSVs dos autores têm geração de 01/11/2022; os controles oficiais por
município/zona, 28/09/2026. A coincidência dos agregados testados não autentica
externamente a aquisição dos autores nem estabelece igualdade de todos os
campos entre versões. Os históricos não têm abstenção; esse controle veio dos
extratos oficiais posteriores. Não há HTML arquivado das notícias usadas na
configuração. Não foram extraídos os 8,6 GB do ZIP nominal nem concatenados BR
e BRASIL. Esta revisão não realizou rede, instalação, MCMC ou validação
inferencial. Avisos de locale/sondagem de CPU do Arrow não impediram execuções
bem-sucedidas e replay byte-idêntico.
