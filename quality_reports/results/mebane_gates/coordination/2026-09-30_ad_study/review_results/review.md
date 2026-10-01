# AD-4: revisão independente do resultado A/D

**PASS da fidelidade quantitativa e documental da entrega. Nenhum achado concreto. O resultado do piloto permanece `computationally_inconclusive` nos dois modelos.** Este PASS não aprova precisão posterior, convergência, identificação ou inferência eleitoral.

Revisor: `01a0f4b8-962b-77a3-a418-6247c6219e8b`. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`. Data local: 30/09/2026; UTC: 01/10/2026. Durante as amostragens houve somente leitura estática/preparação. As verificações quantitativas começaram após o aviso de conclusão do usuário; nenhuma MCMC nova foi executada.

## Resultado Conferido

Tabela 1. Valores conferidos independentemente. Indefinidos estão incluídos nos reprovados, não devem ser somados a eles.

| Medida | A | D |
|---|---:|---:|
| Alvos obrigatórios | 2.171 | 1.742 |
| Reprovados | 1.605 | 1.021 |
| Com diagnóstico obrigatório indefinido | 432 | 392 |
| Globais reprovados entre 23 | 15 | 14 |
| R-hat máximo dos globais | 3,450627 | 2,471930 |
| ESS bulk mínimo dos globais | 4,411771 | 4,842889 |
| ESS cauda mínimo dos globais | 4,016064 | 4,991674 |
| Processo de geração, segundos | 102,570546 | 68,246832 |
| Processo de diagnóstico, segundos | 22,347333 | 21,721774 |
| Soma dos dois processos, segundos | 124,917879 | 89,968606 |

Os dois processos terminaram sem timeout, com adaptação registrada como adequada, quatro cadeias e 2.000 draws retidos por cadeia. Isso não supriu as falhas de precisão. Por exemplo, as médias de M por cadeia foram aproximadamente **1.814,53; 0; 0; 242,02 em A** e **168,23; 1.269,17; 0; 956,02 em D**. As médias combinadas M=514,14/598,36 e S=64,01/62,49 conferem aritmeticamente, mas descrevem as amostras geradas, não estimativas posteriores validadas de transferências ou fraude.

## Evidência e Escopo

**91 controles dos resultados e 22 do relatório/PDF passaram**, além dos quatro cenários sintéticos fornecidos para o comparador. Recalculei diretamente dos raw os **23 globais de cada modelo**: médias, SD, quantis, quatro médias por cadeia, R-hat rank/fold/split, ESS bulk/tail e MCSE. M/S foram reconstruídos por unidade dentro de cada draw/Z, preservando a transformação literal de A e a construção contínua D. Os resultados conferem com [globals_recomputed.csv](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results/globals_recomputed.csv).

Reapliquei as regras v2 sobre **todas as 3.913 linhas obrigatórias** e conferi seu universo completo, unicidade, grupos, NA, constantes amostrais e ausência de isenções. Ranges dos indicadores e contagens de classe foram recalculados dos Z por cadeia, incluindo o divisor n. As reprovações por grupo estão em [mandatory_groups_recomputed.csv](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results/mandatory_groups_recomputed.csv). Não recalculei indiscriminadamente cada R-hat/ESS local: a revisão proporcional combina recálculo central direto com decisão sobre todas as métricas persistidas e preflight já validado do produtor congelado.

Os dados reais passados ao JAGS coincidem com o payload comum e o RDA: 143 unidades na mesma ordem, sem exclusões, `a=NVoters-NValid`, com N/A/W/O e inits/seeds conferidos. A fonte A literal, fontes D e protocolo permanecem preservados. As contagens secundárias D têm dimensões, IDs, seed, inteireza e suporte corretos; agregações e médias condicionais conferem. Não houve novos sorteios de contagens nesta revisão.

Tempos externos de geração/diagnóstico conferem com os supervisores; fases e tempo interno conferem com `run_result`. A soma externa não conta novamente as fases internas. Todos os denominadores ESS/s foram verificados: amostragem, geração interna, geração externa e soma externa. O relatório não usa menor tempo para declarar superioridade estatística diante de precisão reprovada ([relatório, linha 71](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/comparison01/comparison_report.md:71)).

O comparador reproduziu **byte a byte cinco arquivos principais**, inclusive Markdown, a partir dos resultados persistidos em nova pasta de QA. O PDF de três páginas contém as 44 unidades textuais/tabelares conferidas; números e arredondamentos correspondem às tabelas verificadas. Inspecionei as três PNGs preservadas: não há cortes ou sobreposição, e a continuação da Tabela 1 repete o cabeçalho. O `visual_qa=pending` histórico no manifesto do renderer é sucedido pelo registro separado `visual_qa_v1.json`; ambos estão preservados.

A narrativa distingue médias amostrais de posterior confiável ([linha 7](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/comparison01/comparison_report.md:7), [linha 39](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/comparison01/comparison_report.md:39)), M/S de contagens secundárias, DC2010 da codificação brasileira e mesmo caso de replicação numérica externa ([linha 57](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/comparison01/comparison_report.md:57)). G3 continua inconclusivo; G10, produção e inferência eleitoral não recebem aprovação. Não reabri a matemática, identificação, potência ou auditoria histórica.

## Vinculação e Reprodução

- Manifesto vinculante `comparison01/manifest.json`: `3bfbdaf1018518e09f0abe78deb2554a92906692e64e32d6570f0b3f79062545`.
- Relatório Markdown: `7ce47502798661813f976c0bf975af30e7a10237c70d23afd44baad01e682f50`.
- PDF v1: `7d518b6a641b9793497264ec9eef261517c927f5610f858111f6610ee8389d6b`.
- Comparador: `ba835f6244341f26e425a4173f53edb1457162820dc0deed0649ea1cf2bae81f`.
- Raw A: `4fdd7316850c1b3aca1e067aeee5338c41a45042fb5f3405e4a43f3b30d9dcbd`.
- Raw D: `6fe3da66426201efe6da0176f7c880755df868cb9fb6b318a7a9eb1f6bed13ac`.

[review.json](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results/review.json) contém evidência por linha, comandos, hashes complementares e limites. `input_binding.json` vincula release/execução e os arquivos lidos; `checks_results.json` e `report_checks.json` documentam as verificações. `integrity_final.json` registra a reconferência dos inputs após a leitura, sem copiar integralmente os raw.

Duas interrupções dos testes próprios foram preservadas e explicadas: inferência de tipo lógico/numeric em coluna toda NA, e ordem de extração de uma célula quebrada em duas linhas no PDF. As correções ficaram apenas nos scripts de QA e não modificaram valores, critérios, candidato, relatório ou PDF. Scripts, logs, versões iniciais e evidência final permanecem em `review_results/`.

O goal AD-4 termina com esta entrega. Cabe ao coordenador adjudicar o PASS de fidelidade, preservando o resultado computacionalmente inconclusivo. Não foi autorizada por este parecer nova rodada, extensão ou inferência.
