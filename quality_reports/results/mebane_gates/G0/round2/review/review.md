# QA-BASELINE: G0 round2

**Parecer: `pass`; `manifest_complete=true`; nenhum achado vigente.** Os três reparos foram verificados diretamente nos arquivos e por testes próprios. Este resultado se refere ao candidato de manifesto `f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7`; não altera o estado do gate no ledger.

O contrato canônico permanece `e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3`. O executor é `01a0eaba-2cec-74f3-bca0-8c27b736567e` e este revisor independente é `01a0eace-749b-7490-994c-2cb3b39c9a26`. A adjudicação lida é a de round1, SHA-256 `19488904da5d64f743a89616d0becf01cff8af4423a5670d19c556a6d1660ab4`.

## Resolução Dos Achados

| ID histórico | Classificação preservada | Rechecagem e estado |
|---|---|---|
| G0-R1-F1 | CONFIRMED | **Resolvido.** O manuscrito e os quatro CSVs têm snapshots idênticos aos originais, papéis explícitos, hashes e tamanhos; constam no inventário adicional, em `run.inputs`, no mapa final e no manifesto. |
| G0-R1-F2 | CONFIRMED | **Resolvido.** O lock passou de 174 para 180 registros, preservando integralmente os anteriores e os demais metadados. Foram acrescentados apenas os seis pacotes faltantes, com versões iguais às instaladas e fonte CRAN. |
| G0-R1-F3 | PARTIAL | **Resolvido no alcance adjudicado.** O README retirou a receita genérica de recuperação, explicita URL/data/método desconhecidos e condiciona restauração exata à disponibilidade do ZIP de hash conhecido. A recuperação externa continua não demonstrada. |

F1 e F2 continuam sendo defeitos históricos confirmados, agora corrigidos. Para F3, o reparo documental atende à adjudicação: disponibilidade local e integridade estão atestadas; não há promessa de recuperar externamente os mesmos bytes, tampouco afirmação de perda universal do ZIP.

Os seis registros incluídos são `bbmle 1.0.25.1`, `bdsmatrix 1.3-7`, `diptest 0.77-2`, `emdbook 1.3.14`, `plyr 1.8.9` e `spikes 1.1`. Meu código R analisou as expressões de **18 scripts congelados**, sem executá-los: encontrou **31 pacotes diretos**, com fechamento recursivo de **179 pacotes não-base**, todos presentes no lock e sem divergência de `DESCRIPTION$Version`. Isso verifica a reconciliação; não é teste de restauração fria.

## Integridade E Completude

Recalculei os hashes e tamanhos dos **158 arquivos** do novo manifesto. Todos coincidem, incluindo o raw grande, fits e fontes. Os **37 snapshots** são coerentes com o mapa e com `run.json`. Há **129 arquivos herdados no mesmo caminho**, com registros e bytes inalterados; todos os inputs e códigos declarados em round1 continuam cobertos.

Os **22 produtos históricos** que deixaram de aparecer diretamente no manifesto round2 permanecem fixados pelo manifesto round1, agora incluído como entrada com hash. Também conferi os 22 arquivos, incluindo o `DESCRIPTION` e o qbl JAGS congelados, sem divergências. A cobertura foi examinada a partir de `run`, referências de `todo_evidence`, código de congelamento, fontes e reparos; não apenas da lista de arquivos fornecida pelo executor. `implementation.md` não foi usado como validação.

O manifesto não depende dos caminhos canônicos mutáveis de código, documentos ou ledger identificados no mapa. O contrato G0 derivado do ledger congelado coincide com o contrato esperado. Durante a revisão, o README vivo recebeu uma seção posterior sobre denominadores; o snapshot SHA-256 `994b6aa2b95a9d49b1b6e8e516ab3e2bbd82c76d2012236033a6a7f7b402cc2e` permaneceu íntegro. Essa seção nova e a nota referida não foram incorporadas ao objeto avaliado.

## Evidência Executada E Reutilizada

Nesta rodada foram executados, com exit 0:

- `python3 quality_reports/results/mebane_gates/G0/round2/review/audit_round2.py`, com saída detalhada em `audit_results.json`.
- `Rscript --vanilla quality_reports/results/mebane_gates/G0/round2/review/check_dependencies.R`, com saída em `dependencies_results.json`.

Também li os diffs README/CLAUDE, a seção de proveniência do README congelado, `sources.md`, os scripts novos e os cinco artefatos de F1. O primeiro teste de parsing R do revisor encontrou um argumento sintaticamente vazio em um script; o parser foi corrigido e a execução final analisou todos os 18 scripts com sucesso. Isso não foi defeito do candidato.

**Reutilização explicitamente histórica:** os testes de carregamento do fit `fresh_v2` e das quatro bases parquet, a comparação de `qbl()`/commit/`DESCRIPTION`, a identificação e estrutura dos PDFs e a igualdade ZIP→extraídos foram executados na **primeira revisão**, não novamente nesta. Seus artefatos mantêm os hashes agora recalculados. A revisão anterior carregou quatro cadeias de 5.000 draws e reproduziu R-hat clássico `1.246802` para `pi[2]` e `1.713809` para `iota.s.alpha`; esses valores não constituem certificação inferencial. O SSRN válido permanece identificado como artigo de Kalinin, e o arquivo em `.download` permanece uma fonte inválida.

A origem externa do ZIP continua desconhecida e explicitamente limitada ao que foi verificado neste checkout. Não houve instalação, restauração fria, MCMC, recálculo das tabelas nem trabalho G1/G2. Todos os arquivos produzidos por esta rechecagem estão em `round2/review/`; round1 e o candidato foram preservados.
