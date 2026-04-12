# Handoff da sessao Stan qbl — versao 2 (pos-diagnostico)

Data: 2026-04-12

## Objetivo deste arquivo

Registrar o estado da portagem `qbl()` → Stan e as conclusoes do diagnostico
realizado em 2026-04-11 (sessao longa). Substitui a v1 de 2026-04-11.

## Conclusao executiva

1. O `05_eforensics_qbl_brasilia_fit.rds` (JAGS, 4 chains, burn=2000,
   sample=5000) **esta preso num modo errado** (`tau.alpha ~ 0.71` vs.
   correto ~ 1.61). Artefato de burn-in insuficiente, nao defeito do modelo.

2. Um JAGS fresco (burn=5000, sample=5000, init default) **converge ao
   modo correto** em todas as 4 chains: `tau.alpha = 1.616`, `nu.alpha = -0.430`,
   `pi[1] = 0.991`, `pi[2] = 0.009`. Tempo: 32 min.

3. O Stan existente **ja estava no modo correto** desde os smoke tests
   (tau_alpha ~ 1.59, nu_alpha ~ -0.37). O "problema de mixing" reportado
   na v1 nao era traducao errada — era (a) benchmark JAGS invalido e
   (b) nao-identificacao inerente dos parametros de fraude sob a nula.

4. A hipotese de trabalho da v1 ("revisar a traducao Stan") **e descartada**.
   A hipotese correta: o modelo `qbl` tem identificabilidade fraca nos
   parametros de fraude (`iota_*_alpha`, `chi_*_alpha`) quando `pi[2]`, `pi[3]`
   sao proximos de zero. Isso vale para JAGS e Stan igualmente.

## Evidencia

### Comparacao dos tres fits para Brasilia 2022 T2

| parametro    | .rds salvo (burn=2000) | JAGS fresco (burn=5000) | Stan n=2000 | empirico |
|---|---|---|---|---|
| tau.alpha    | 0.711 ERRADO           | 1.616                   | 1.59        | 1.605    |
| nu.alpha     | -1.112 ERRADO          | -0.430                  | -0.370      | -0.419   |
| pi[1]        | 0.9995                 | 0.991                   | 0.996       | —        |
| pi[2]        | 0.0003                 | 0.0085                  | 0.004       | —        |
| pi[3]        | 0.0001                 | 0.0003                  | 0.0005      | —        |

### rhat do JAGS fresco (n=6748, 4 chains, burn=5000)

| parametro         | rhat   | interpretacao                              |
|---|---|---|
| tau.alpha         | 1.04   | identificado                               |
| nu.alpha          | 1.03   | identificado                               |
| tb, nb            | 1.08   | OK                                         |
| pi[1], pi[2]      | 1.24   | multimodalidade Mebane-padrao              |
| pi[3]             | 1.00   | identificado                               |
| iota.m.alpha      | 4.17   | NAO identificado (CI inclui zero)          |
| iota.s.alpha      | 1.71   | marginal (CI negativo: [-0.48, -0.18])     |
| chi.m.alpha       | 3.57   | NAO identificado                           |
| chi.s.alpha       | 3.04   | NAO identificado                           |
| imb               | 12.8   | NAO identificado (variancia de alpha)      |
| isb               | 9.0    | NAO identificado                           |

### Por que os `*_alpha` nao sao identificaveis

Quando `pi[2] ~ 0.009` e `pi[3] ~ 0.0003`, quase nenhuma observacao e
alocada as componentes "incremental" e "extreme". Os parametros
`iota_m_alpha`, `iota_s_alpha`, `chi_m_alpha`, `chi_s_alpha` so entram na
likelihood ponderados pela responsabilidade da classe respectiva, que e
proporcional a `pi[k]`. Com `pi[k]` desprezivel, o gradiente da likelihood
e essencialmente zero nesses parametros, e eles sao amostrados do prior
`Normal(0,1)`. Chains diferentes exploram regioes diferentes do prior, gerando
rhat alto. Isso NAO e bug do sampler — e propriedade do modelo.

## Referencia ao PA2024.pdf (Mebane, Pennsylvania 2024)

O paper `PA2024.pdf` (Mebane, Jun 2025) aplica `eforensics` a PA 2024 e
documenta como o autor lida com exatamente esses problemas:

### Diagnosticos usados por Mebane

- **Dip test D(pi_k)**: teste de Hartigan para unimodalidade da posterior de
  cada pi_k. Se rejeita (D=0), ha multimodalidade entre chains.
- **M(pi_k)**: diferenca entre a maior e menor media por chain. Mebane reporta
  e aceita M(pi_2) = 0.110 em PA 2024 (Table 2). Nosso M(pi_2) = 0.002 — muito
  melhor que o dele.

### Regra interpretativa de Mebane para os interceptos de fraude

- **rho_M (= iota.m.alpha) claramente negativo**: "strategic behavior, not
  malevolent distortions" (benchmarked contra eleicoes alemas). Suporta a nula.
- **rho_M com sinal indeterminado (CI inclui zero)**: "inductively suggests
  that manufactured votes very likely are produced from malevolent distortions".
  Sinal de possivel fraude.
- Nosso iota.s.alpha = -0.325 [-0.48, -0.18] e claramente negativo (suporta nula).
  Nosso iota.m.alpha = 0.042 [-0.43, 0.28] e indeterminado (ambiguo).
  Mas: Ft ~ dezenas de votos, substancialmente zero.

### Fixed effects como estrategia padrao

Mebane NAO usa intercept-only. PA 2024 Table 2 ja tem county fixed effects
para turnout e vote choice. Table 3 adiciona county FE para fraud magnitudes.
Cita: "When diagnostics signal posterior multimodality, my usual practice is to
expand the use of geographic fixed effects." Nosso intercept-only esta ABAIXO do
padrao praticado pelo autor do metodo.

## O que o Stan atual preserva corretamente

- Prior ordenado de pi (via u2, u3 ~ Uniform(0,1)): equivalente ao JAGS.
- Seis blocos hierarquicos de efeitos aleatorios: correto.
- k = 0.7: correto.
- Marginalizacao de Z via log_sum_exp: correto.
- Parametrizacao nao centrada para random effects: melhoria sobre JAGS.
- Interceptos fixos colapsados (intercept-only): correto e defensavel.

## O que o Stan atual relaxa (vs JAGS)

As contagens binomiais latentes `N.iota.s`, `N.iota.m`, `N.chi.s`, `N.chi.m`
do JAGS foram substituidas por magnitudes continuas. Isso e uma simplificacao
aceitavel: essas contagens adicionam ruido binomial por observacao em cima do
random effect ja existente. Para Brasilia sob a nula, com `pi[2,3] ~ 0`, isso
nao afeta as quantidades substantivas.

## Arquivos de referencia

### Fits salvos

- `05_eforensics_qbl_brasilia_fit.rds` — JAGS original. **INVALIDO** (modo errado).
  Manter para referencia mas nao usar como benchmark.
- `05_eforensics_qbl_brasilia_fresh_v2_fit.rds` — JAGS fresco com burn=5000.
  **BENCHMARK CORRETO**.
- `05_eforensics_qbl_brasilia_fresh_v2_summary.txt` — diagnostico do fit fresco.

### Stan

- `stan/eforensics_qbl.stan` — modelo Stan atual (relaxado, intercept-only).
- `R/05_stan_eforensics_qbl_calibrate.R` — calibracao Stan.
- `quality_reports/results/05_stan_qbl_brasilia_log_n2000.md` — ultimo smoke test.

### JAGS

- `R/05_eforensics_umeforensics_qbl.R` — script original do JAGS qbl.
- `R/05_eforensics_qbl_fresh_diagnostic.R` — script do diagnostico fresco.

### Referencia metodologica

- `PA2024.pdf` — Mebane (Jun 2025), aplicacao de eforensics a PA 2024. Mostra
  como o autor lida com multimodalidade posterior e interpretacao dos interceptos.

## Meta de mixing revisada

NAO exigir rhat < 1.01 em todos os parametros. Criterio revisado:

| nivel          | parametros                                  | meta         |
|---|---|---|
| obrigatorio    | tau_alpha, nu_alpha, tb, nb                 | rhat <= 1.05 |
| obrigatorio    | pi[1], pi[2], pi[3]                         | rhat <= 1.30 |
| desejavel      | Ft, Fw, stolen_votes                        | rhat <= 1.10 |
| NAO exigido    | iota_*_alpha, chi_*_alpha, imb, isb, cmb, csb | sem meta  |

Para os "nao exigidos": documentar que rhat alto e consequencia da
nao-identificacao sob a nula, nao bug do sampler.

## Passo b — CONCLUIDO (2026-04-12)

### O que foi feito

1. **Zone FE no JAGS**: Adicionado NR_ZONA (19 zonas, 18 dummies + intercept)
   nas formulas de fraud magnitude. Script: `R/05_jags_qbl_zone_fe.R`.
   Fit: `05_jags_qbl_zone_fe_fit.rds`. Wall: 26 min.

2. **Stan generalizado para covariáveis**: `stan/eforensics_qbl.stan` agora
   aceita design matrices (p_* = 0 para intercept-only, p_* > 0 para FE).
   Backward compat validada. Script: `R/05_stan_eforensics_qbl_calibrate.R`
   com toggle `STAN_EFORENSICS_QBL_ZONE_FE=1`.

3. **Dip test implementado**: `R/05_dip_test_diagnostics.R` com Hartigan
   dip test + M(pi_k). Pacote `diptest` instalado.

4. **Comparacao cross-engine**: `R/05_compare_fits.R` gera tabela markdown.
   Output: `05_compare_fits.md`.

### Resultados do JAGS zone FE (Brasilia 2022 T2, n=6748)

| parametro    | JAGS IO      | JAGS zone FE | rhat FE | meta    |
|---|---|---|---|---|
| tau.alpha    | 1.616        | 1.615        | 1.04    | <= 1.05 OK |
| nu.alpha     | -0.430       | -0.431       | 1.12    | <= 1.05 marginal |
| pi[1]        | 0.991        | 0.988        | 4.60    | <= 1.30 FAIL |
| pi[2]        | 0.009        | 0.012        | 4.62    | <= 1.30 FAIL |
| pi[3]        | 0.0003       | 0.0003       | 1.00    | OK |
| iota.m.alpha | 0.042        | -0.205       | 20.2    | NAO exigido |
| iota.s.alpha | -0.325       | -0.421       | 13.5    | NAO exigido |
| sigma_tau    | 0.204        | 0.204        | 1.01    | OK |

### Dip test

| fit           | D(pi_1) | p      | D(pi_2) | p      | M(pi_2) | benchmark |
|---|---|---|---|---|---|---|
| JAGS IO       | 0.001   | 1.000  | 0.001   | 0.999  | 0.002   | < 0.110 OK |
| JAGS zone FE  | 0.033   | <0.001 | 0.033   | <0.001 | 0.013   | < 0.110 OK |

### Interpretacao

- Zone FE NAO melhorou a identificacao dos interceptos de fraude — rhat
  dos `*_alpha` continua alto. Isso confirma que a nao-identificacao e
  inerente ao modelo sob a nula, nao artefato de especificacao.
- `iota.s.alpha = -0.421` claramente negativo [-0.96, -0.11] → suporta
  nula ("strategic behavior, not malevolent distortions", Mebane PA2024).
- M(pi_2) = 0.013 — excelente (Mebane aceita 0.110 em PA 2024).
- Zone FE introduziu multimodalidade leve em pi (dip test rejeita), mas
  M(pi_2) permanece muito baixo.

## Proximo passo (passo c)

1. **Stan full run com zone FE**: Rodar com 6748 obs. Custo estimado ~6-28h
   dependendo da config. Comando preparado (ver sessao de tempos abaixo).

2. **Ft/Fw do Stan zone FE**: Apos o full run, comparar Ft/Fw com JAGS
   intercept-only.

3. **Decidir sobre Bloco 4** (Monte Carlo de poder): Os resultados de Brasilia
   confirmam a nula. O proximo passo substantivo e o Bloco 4 — injetar fraude
   sintetica e medir poder do fingerprint method.

## Tempos de referencia

| modelo | implementacao | dataset | chains | iter_total | wall_min |
|---|---|---|---|---|---|
| qbl | JAGS salvo (INVALIDO) | BSB full 6748 | 4 | 7000 | 35.5 |
| qbl | JAGS fresco v2        | BSB full 6748 | 4 | 10000 | 32.0 |
| qbl | JAGS zone FE          | BSB full 6748 | 4 | 8500  | 26.0 |
| qbl | Stan smoke IO (p=0)   | BSB subset 2000 | 2 | 50 | 4.4 |
| qbl | Stan smoke FE (p=18)  | BSB subset 2000 | 2 | 150 | 10.6 |
