# Revisão Independente do Delta A/D v2

**Status: `pass`, restrito ao delta do contrato.** AD-CONTRACT-QA-01 foi atendido na v2 exata; recomendo seu fechamento pelo coordenador. Não há novo achado impeditivo. Este parecer não aprova implementação, MCMC real, resultado empírico, G3, G10 ou produção.

Data local: 30/09/2026, America/Sao_Paulo. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`. Revisor independente: `01a0f4b8-962b-77a3-a418-6247c6219e8b`, confirmado pelo goal próprio e `CODEX_THREAD_ID`.

Contrato: `AD-DC2010-v2`, SHA-256 `d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509`. A v1 permanece no hash `8f0783b5f3520958a2b1a6d6de5bb217e2ea4ac8656a6ac114024b9d6a95dc17`; a adjudicação v1, no hash `30adc6e3e8be431daacf727ff0b870b2e79ce7e1fa7f021332cca4246cbe9dd5`. O vínculo da adjudicação ao parecer anterior foi conferido, sem refazer sua adjudicação.

## Fechamento do Achado

A [tabela decisória da v2](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:202) explicita alvos, estatísticas, limiares, obrigatoriedade e consequências. Isso elimina a escolha pós-resultado do que seria “relevante” para a comparação.

| Alvos obrigatórios | Critério |
|---|---|
| 23 globais: `pi`, seis `alpha`, seis variâncias, seis `b0`, `M_total`, `S_total` | R-hat < 1,01; ESS bulk e tail ≥ 400 |
| `6*n` médias `mu` e probabilidades observacionais de A/D | Mesmos critérios |
| `3*n` indicadores `I(Z_i=c)` e três contagens de classe por draw | Mesmos critérios; amplitude das médias entre cadeias ≤ 0,05 |
| `4*n` auxiliares binomiais de A | Mesmos critérios |

Na amplitude entre cadeias, os indicadores estão em `[0,1]` e as contagens são divididas por `n`, apenas para essa checagem. Avaliar indicadores das três classes evita depender do rótulo numérico arbitrário de `Z`. O teto de cinco pontos percentuais é corretamente descrito como operacional e prospectivo, não como teste de fraude, igualdade posterior ou garantia isolada de precisão. [Evidência: linhas 234–250](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:234).

Qualquer estatística obrigatória reprovada, ausente ou indefinida leva a `computationally_inconclusive`; ambos os ajustes precisam terminar com adaptação adequada. Não há isenções analíticas no piloto. Constância amostral não pode ser convertida em zero analítico, e o rótulo conceitual `exact_not_MC` dos fixtures não cria uma exceção empírica. [Evidência: linhas 196–201](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:196) e [linha 295](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:295).

Saídas secundárias de D não resgatam precisão da posterior primária; defeitos de suporte/identidade bloqueiam resultados mesmo nessa linha secundária. `M_total`/`S_total` continuam obrigatórios. Dividi-los pelo `N_total` positivo conhecido é apenas reescala determinística, sem nova informação ou dispensa dos diagnósticos originais. [Evidência: linhas 267–275](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:267).

## Delta e Verificação

A comparação estrutural de JSON encontrou exatamente dez caminhos alterados: identificação da versão; esclarecimento dos auxiliares iniciais; execução; descrição dos discretos; veredicto; lista vazia de isenções; tabela decisória; um novo fixture; primeiro checkpoint; referência à v1. As seções `A`, `D`, `case`, `comparison` e `monitoring` são semanticamente idênticas. Priors, likelihood, referências de dados, sementes, iterações, limites de tempo e política de falha não mudaram. Foram preservados os oito arquivos do manifesto da entrega anterior.

O novo `floor(N*mu)` explicita as transformações incremental/extrema já usadas na revisão v1. Um objeto rjags com quatro cadeias, A seguido de D e timeout externo corresponde ao esclarecimento autorizado e respeita o teto de quatro cadeias. Não foi testado um runner. [Evidência: linhas 108–141](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:108).

Executei 14 controles determinísticos da regra decisória: fronteiras de R-hat, ESS e amplitude; normalização das contagens; `NA`, ausência e não finito; constância amostral; execução/adaptação incompleta; falha de suporte secundária. Todos corresponderam às decisões fixadas. É um avaliador independente da regra textual, não validação do futuro código diagnóstico. Para `n=143`, a tabela implica 2.171 alvos escalares obrigatórios em A e 1.742 em D; esses totais podem orientar a checagem de cobertura no preflight.

Comando executado, saída 0:

```bash
env LC_ALL=C LANG=C Rscript --vanilla quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_contract/check_delta_v2.R /Users/manoelgaldino/Documents/DCP/Papers/electoralFraud
```

Fontes locais consultadas em 30/09/2026; timestamps UTC, hashes e resultados em [delta_checks_v2.json](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_contract/delta_checks_v2.json), com ambiente e log em [delta_checks_v2.log](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_contract/delta_checks_v2.log). Não repeti enumerações matemáticas, preparação de dados ou auditoria histórica dos gates; não compilei modelos nem executei MCMC.

## Limites e Disposição

Os critérios são deliberadamente conservadores: indicadores raros ou constantes na amostra podem tornar o piloto inconclusivo. Isso não é uma contradição do protocolo, nem prova de não convergência ou de ausência de fraude. Não é permitido aliviar critérios depois dos resultados.

A implementação experimental de D está autorizada pelo pedido atual do usuário. Recomendo encerrar AD-CONTRACT-QA-01 para a v2 exata, preservando o parecer v1 como histórico. **MCMC real permanece condicionado ao fechamento/adjudicação da v2 e à revisão/adjudicação independentes da implementação e do preflight**, inclusive extração completa dos alvos, formato das cadeias, tratamento de `NA`, agregação do veredicto, persistência e timeout. [Checkpoints: linhas 298–301](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:298). Este parecer não substitui nenhuma dessas verificações.
