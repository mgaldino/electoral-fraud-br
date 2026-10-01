# Revisão independente: preflight D/Stan

**Status: PASS. Nenhum achado impeditivo ou correção pendente no candidato congelado.**

Revisor: `01a0f4b8-962b-77a3-a418-6247c6219e8b`. Coordenador: `019d795a-acfa-72c2-a210-d55a46c606c2`. Implementador do candidato Stan: `01a0f4b5-4434-7b83-91b9-69ced11b40ba`. Parecer emitido em 2026-10-01, após os checks independentes concluídos às 11:02:02 UTC.

Este parecer cobre somente o port D/Stan compilado, seu caminho de execução prospectivo e o adapter diagnóstico. Não avalia resultados empíricos, os resultados JAGS20k ou relatórios comparativos. A adjudicação permanece com o coordenador. PASS de preflight não significa posterior convergida, precisão adequada ou inferência substantiva.

## Vínculos do Parecer

Os caminhos abaixo são relativos à raiz do repositório. `NEW` designa `quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan`; `PREP` designa `NEW/stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation`.

- `PREP/manifest.json`: `2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb`.
- `PREP/preflight_manifest.json`: `7169d8b0e2536739ad2b2a9a9b9f6bfb471b9e6da3424aaad7cf86bd801d0c23`.
- `NEW/stan_diagnostic_candidate/manifest.json`: `3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0`.
- `PREP/build/d_multinomial`: `c2d882526d9893236c2ebaeec92a8eacdfa0d327f6f19de7f961d936ab6d65f1`.
- `models/experimental/mebane_ad_stan/d_multinomial.stan`: `b38de93ef22b826233f35898b5d3becfae1fb46df774ead065b8d4133c127c9b`.

Foram conferidas as 25 entradas do manifesto de preparação, as 58 entradas do preflight e as 14 entradas do adapter, incluindo snapshots e produtos nativos. Os vínculos foram reconferidos após os testes. O JSON deste parecer contém também os hashes dos dois contratos e dos resultados independentes que sustentam a conclusão.

## Verificações e Evidências

1. **Alvo matemático e código compilado.** A leitura estática encontrou o prior correto dos ratios após integrar `aux1`, variâncias Exp(5), parametrização não centrada e mistura por unidade da massa multinomial conjunta. As verificações próprias comparam diferenças de log-densidade em quatro estados, com e sem Jacobiano das restrições, e gradientes contra diferenças finitas de um oráculo R independente. Erro máximo das diferenças de densidade: `7.105427357601e-15`; erro máximo escalado dos gradientes: `4.16366718880568e-10`. Evidência: `d_multinomial.stan`, linhas 60-98; `compiled_checks01/density_gradient_errors.json`.

2. **Generated quantities e funcionais.** Foram reconstruídas as 256 linhas já existentes do fixture de três unidades sintéticas, sem gerar novos draws. Probabilidades de classe usam a mesma likelihood conjunta; Z condicional, probabilidades ativas e M/S correspondem ao mesmo draw e à mesma classe. Totais augmented e Rao-Blackwell permanecem separados. Erro máximo observado dos quatro totais: `4.44089209850063e-16`. Evidência: `d_multinomial.stan`, linhas 101-149; `compiled_checks01/GQ_errors.json`. Funções nativas de probabilidades e massa foram também verificadas em pontos próprios e na fronteira de probabilidade zero.

3. **Mapeamento e regras.** O payload sintético de formato real exercitou o pós-processador inteiro: 2000 iterações, quatro cadeias, 1451 colunas mapeadas, todas as 1742 decisões comuns obrigatórias e os 860 nomes/diagnósticos internos. Foram testados rejeição por divergência, limite de treedepth, energia constante, E-BFMI baixo, NCP constante ou separado entre cadeias e total M/S incorreto. As secundárias Rao-Blackwell não resgatam falhas obrigatórias. Evidência: `R/experimental/mebane_ad_long/stan_bridge.R`, linhas 6-65; `postprocess_stan.R`, linhas 24-58; `adapter_checks02/checks.json` e saídas preservadas em `adapter_checks02/tree/postprocessed/`.

4. **NA e denominador ESS/s.** O teste original próprio exigia indevidamente `!anyNA` na comparação numérica. O candidato havia produzido corretamente 429 ESS tail indefinidos de indicadores de classe e resultado `computationally_inconclusive`. O recheck restrito compara separadamente as máscaras de NA e os valores finitos de ESS divididos pelos 123 segundos do fixture. Passou sem mudar candidato, limiares ou resultado. O arquivo intermediário `adapter_checks02/checks.json` e seu status `needs_revision` ficam preservados; esse status do checker e a indicação antiga de preparação pendente são superados por este parecer. Evidência: `compiled_checks01/adapter_ESS_resolution.json`; `check_compiled.R`.

5. **Dados, inicializações e execução.** Os 143 casos preparados e quatro estados iniciais foram conferidos sem repetir a preparação dos dados. A execução prospectiva exige o parecer independente vinculado ao manifesto, carrega fontes congeladas, usa quatro cadeias seriais, 2000 warmup e 2000 draws, sem retry, com supervisão externa de 3600 segundos. A política de término alcança o grupo de processos mesmo após a saída do líder. Evidência: `R/experimental/mebane_ad_stan/common.R`, linhas 58-118; `run_stan.R`, linhas 67-120; `supervise_stan.py`, linhas 26-110. Evidência congelada dos fixtures de supervisão foi reutilizada; esta revisão não acionou um processo empírico.

6. **Relógios.** Os `43.1641881465912` segundos de compilação arquivados incluem o executável CmdStan e a interface C++ de métodos de densidade/gradiente. A interface standalone de funções tem medição separada nos testes. O denominador ESS/s interno do adapter é o tempo da chamada de amostragem Stan, identificado como tal nos metadados; não equivale ao tempo externo de geração mais diagnóstico. Evidência: `compiled_checks01/binding.json`; `postprocess_stan.R`, linhas 39-45.

## Reprodução e Limites

Os scripts próprios são `oracles.R`, `check_adapter.R` e `check_compiled.R`, neste diretório. Foram usados R 4.4.2 e posterior 1.7.0. As chamadas R foram executadas com `LC_ALL=C LANG=C` e `Rscript --vanilla`; saídas e tentativas anteriores permanecem preservadas. O teste nativo final foi:

```sh
env LC_ALL=C LANG=C Rscript --vanilla quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review/stan/check_compiled.R > quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review/stan/compiled_checks01.log 2>&1
```

A execução terminou com código zero e nove grupos PASS. O driver usa diretamente as bibliotecas `.so` preservadas, sem recompilar e sem chamar amostragem. O teste completo do adapter teve 19 grupos PASS inicialmente e um erro do checker, resolvido pelo recheck delimitado acima, sem repetir o pós-processamento completo. A tentativa inicial com erro sintático do script próprio também foi preservada em `check_adapter_attempt01.R` e `adapter_checks01.log`.

A suíte fornecida de 183 checks foi lida e vinculada por hash, não repetida integralmente. A revisão reutilizou helpers históricos somente onde a identidade de bytes ou o delta mecânico do adapter foi conferido. Nenhuma MCMC empírica, instalação, deleção, nova amostragem Stan ou edição do candidato foi realizada pelo revisor. Os testes sintéticos e determinísticos não antecipam a mistura, a precisão ou os tempos da futura execução empírica; esta continuará sujeita a todos os critérios prospectivos obrigatórios, inclusive NA como inconclusivo.
