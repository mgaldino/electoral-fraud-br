# G2 round1: candidato delimitado

**Entrega do executor, não aprovação de gate.** O contrato auditável está em `appendices/mebane_model_contract.md`; a versão PDF está nesta rodada. A revisão independente ainda não existe. O goal do executor é entregar este candidato, não resolver por autoridade escolhas substantivas do alvo.

## Resultados e decisões necessárias

| ID | Resultado | Evidência precisa | Consequência |
|---|---|---|---|
| G2-F1 | O JAGS admite pais de binomial com `p.w > 1`. | Contrato §4.1; teste `minimal_invalid_support`: N=A=R_M=1, R_S=0, nu=0.5, m=0.999, p.w=499.5. | Escolher tratamento estatístico e verificar semântica runtime em G3; não presumir normalização por rejeição. |
| G2-F2 | Suporte de contagens difere do suporte eleitoral. | §2.1/4.1; testes `paper_physical_not_normalized` e `qbl_physical_not_normalized`: massas físicas 0.875 e 0.96875. | Decidir gerador físico versus produto de marginais/condicionais; truncar exige normalizadores. |
| G2-F3 | P/J/S não são o mesmo alvo. | §3–5 e Tabela 1; `paper_not_qbl_off_mean`, `plugin_not_marginalization`, `stan_clamp_changes_target`. | Não usar concordância de médias como validação de portagem. |
| G2-F4 | Exp(5) é variância em J/S, desvio-padrão no texto P22/P23; S também elimina pequeno intercepto. | §3.2/3.3; `scale_prior_divergence`, `intercept_not_exactly_removed`. | Aprovar explicitamente escala e redução exata ou aproximada do intercepto. |
| G2-F5 | Totais do Stan são esperanças condicionais em Z; origem de stolen não identifica segundo colocado. | §6; testes de variância Rao–Blackwell e limites de margem. | Definir distribuição-alvo dos estimandos e manter hipóteses/limites para a margem. |

Esses IDs são achados do implementador para verificação. Não são adjudicação CONFIRMED nem parecer independente. Alternativas (kernel literal, normalização explícita, produto do paper, multinomial) permanecem rotuladas como não aprovadas.

## O que foi feito

* Leitura das especificações P22/P23 e dos snapshots JAGS/Stan/R de G0, com mapa de todos os blocos executáveis de J e correspondentes de S; imagens das páginas críticas confirmam a diferença de escala e a omissão de `k` em P23 (4d).
* Derivação da prior parcial de mistura com densidade `pi1^(-3)`, jacobianos, hierarquia, interceptos e regularização por dummies de zona.
* Derivação de suporte, transformação 0.999, clamp e normalizadores; contraexemplos numéricos mínimos.
* Marginalização discreta por dois pares ativos, confrontada com enumeração das quatro contagens para todos os A/W em N=1,2,3; custo direto e custo adicional de normalização delimitados.
* Definição de estimandos por draw conjunto, classificação, esperanças condicionais e limites para a margem.
* Contexto lateral congelado sem herdar suas instruções. P23 confirma o precedente argentino sobre brancos; nenhum total da nota lateral foi revalidado em G2.

## Verificação e reprodução

O comando `Rscript --vanilla tests/mebane/algebra/run_tests.R` executa apenas R/base: quadratura determinística, enumeração finita e asserções. `results/checks.csv`, `metrics.csv` e `marginalization.csv` guardam o resultado; `execution.txt` informa versão, tempos e ausência de RNG. Os testes são auxiliares da derivação e não provam sozinhos equivalência geral. Para QA sem alterar os resultados congelados, fornecer um novo diretório como argumento ao script.

`build_candidate.py build` executa testes e renderização e registra comandos, códigos de saída e tempos em `commands.json`. `build_candidate.py finalize` escreve run/manifest somente se testes e QA visual do implementador estiverem registrados; `verify` confere todos os hashes e identidade estática, sem tocar no ledger. Scripts Python são exclusivamente de empacotamento/renderização; a análise está em R.

O primeiro render falhou por fonte não instalada; um segundo expôs delimitador de matemática incorreto. Corrigido o fonte via apply_patch, o render com pdflatex usa fontes já disponíveis. Nenhum componente foi instalado. O manual JAGS completo foi obtido em espelho acadêmico após timeouts; o arquivo parcial foi substituído e a integridade estrutural foi conferida com pdfinfo (74 páginas). As tentativas e URL final constam de `source_provenance.json`.

## Limites e próximos responsáveis

G2-T1 a T4 estão cobertos como tarefas de auditoria, não certificação inferencial. G2-T5 permanece `in_progress` porque falta sua parte independente. G2 tem escolhas substantivas materiais pendentes e não deve ser marcado PASS. A QA deverá conferir os hashes antes de rederivar, em especial (G2.6), (G2.8), (G2.13–18), a semântica dos priors e o tratamento da incerteza em (G2.19–21).

Não houve MCMC, compilação/execução de modelos Stan/JAGS, recarga de fits, avaliação de identificação empírica, calibração ou G3. Timings e R-hat do histórico são inspeção de artefatos preservados; a recarga de fresh_v2 foi feita em G0, não nesta rodada. Arquivos de produção são inputs somente. Ledger, README, CLAUDE, G0, raw e fits não foram alterados. As mudanças concorrentes de G1/coordenação foram preservadas.
