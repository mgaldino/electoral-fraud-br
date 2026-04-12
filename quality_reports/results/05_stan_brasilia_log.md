# Bloco 5 -- log da calibracao Stan

Data/hora: 2026-04-10 20:41:49 -0300
R: 4.4.2
CmdStanR: 0.9.0
CmdStan: 2.37.0

## Addendum 2026-04-11

- Este artefato corresponde apenas ao smoke test do `bl()` simplificado legado.
- A inspeção posterior do `UMeforensics` 0.0.4 mostrou que o alvo canônico em JAGS é `qbl()`, não `bl()`.
- Portanto, este log não deve ser tratado como validação do alvo principal para o port em Stan; ele fica apenas como baseline histórico.

## Alvo do modelo

- Modelo: aproximacao Stan do `bl()` simplificado legado do `eforensics`.
- Prior de mistura: Dirichlet(1, 1, 1), para espelhar o fork legado usado na comparacao com JAGS.
- Constante de threshold: `k = 0.7`.
- Limitacao: esta fase nao inclui os random effects hierarquicos do paper de Mebane (2023).
- Limitacao adicional: os latentes binomiais por secao (`N.iota.*`, `N.chi.*`) do JAGS foram substituidos por magnitudes globais continuas.

## Dataset

- Secoes: 6748
- Aptos totais: 2207628
- Abstencoes totais: 369136
- Votos do leader totais: 729295

## Timings

            phase n_obs n_chains warmup sampling_iter total_iter wall_seconds
           <char> <int>    <int>  <int>         <int>      <int>        <num>
1: smoke_brasilia  6748        4     50           100        150     3271.252
   per_iter_ms ess_bulk_min ess_tail_min rhat_max divergent_transitions
         <num>        <num>        <num>    <num>                 <int>
1:    21808.35     6.042383      18.8764 1.924325                     0

## Resumo posterior (ultima execucao disponivel)

# A tibble: 12 x 9
   variable        mean  median      sd     q2.5   q97.5  rhat ess_bulk ess_tail
   <chr>          <dbl>   <dbl>   <dbl>    <dbl>   <dbl> <dbl>    <dbl>    <dbl>
 1 pi_1         3.04e-1 7.61e-3 3.43e-1 1.56e- 5 7.36e-1  1.78     6.40    218. 
 2 pi_2         6.92e-1 9.88e-1 3.43e-1 2.63e- 1 9.98e-1  1.77     6.52    158. 
 3 pi_3         3.35e-3 2.40e-3 4.42e-3 3.98e- 4 2.38e-2  1.67     8.55     28.6
 4 tau          8.20e-1 8.12e-1 1.13e-2 8.07e- 1 8.33e-1  1.87     6.16     62.2
 5 nu           1.81e-1 1.48e-1 1.82e-1 5.98e-12 3.72e-1  1.79     6.40     67.0
 6 iota_m       7.18e-2 1.09e-1 5.80e-2 3.09e- 9 1.40e-1  1.92     7.20     35.6
 7 iota_s       2.60e-1 2.67e-1 1.19e-1 9.75e- 2 3.81e-1  1.91     6.05     28.6
 8 chi_m        7.08e-1 7.00e-1 2.52e-2 7   e- 1 8.42e-1  1.50     7.98     23.9
 9 chi_s        7.05e-1 7.00e-1 2.41e-2 7   e- 1 8.39e-1  1.29    11.8      18.9
10 Ft           2.91e+4 4.52e+4 2.49e+4 1.31e+ 2 5.79e+4  1.91     6.04     70.6
11 Fw           3.98e+5 4.63e+5 3.33e+5 4.70e+ 4 7.31e+5  1.78     6.42    232. 
12 stolen_votes 3.69e+5 4.19e+5 3.10e+5 4.63e+ 4 6.84e+5  1.75     6.52     52.1

## Notas

- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_FULL=1` para a calibracao completa.
- Smoke test concluido com o modelo Stan legado simplificado.
