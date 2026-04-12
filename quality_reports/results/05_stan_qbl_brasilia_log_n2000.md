# Bloco 5B -- log da calibração Stan qbl

Data/hora: 2026-04-11 11:04:48 -0300
R: 4.4.2
CmdStanR: 0.9.0
CmdStan: 2.37.0

## Alvo do modelo

- Modelo: aproximação Stan do `qbl()` canônico do `UMeforensics`.
- Mantido: prior ordenado de `pi`, seis blocos hierárquicos e `k = 0.7`.
- Relaxação: as contagens binomiais latentes `N.iota.*` e `N.chi.*` do JAGS foram substituídas por magnitudes contínuas na escala logística.
- Reparametrização: no caso intercept-only, `pi.aux1` foi marginalizado e os interceptos fixos ultra-concentrados foram colapsados nas localizações `alpha`.
- Tempo de compilação Stan: `9.62 s`.

## Dataset usado na última execução

- Seções: 2000
- Aptos totais: 647623
- Abstenções totais: 111375
- Votos do leader totais: 219317

## Timings

                phase                    model n_obs n_chains warmup
               <char>                   <char> <int>    <int>  <int>
1: smoke_brasilia_qbl qbl_stan_relaxed_reparam  2000        2    500
   sampling_iter total_iter wall_seconds per_iter_ms per_iter_per_obs_us
           <int>      <int>        <num>       <num>               <num>
1:           250        750     541.7433    722.3244            361.1622
   ess_bulk_min ess_tail_min rhat_max divergent_transitions max_treedepth_hits
          <num>        <num>    <num>                 <int>              <int>
1:     8.239818     43.75545 1.229375                     0                  0

## Resumo posterior (última execução disponível)

# A tibble: 18 x 9
   variable     mean   median      sd     q2.5     q97.5  rhat ess_bulk ess_tail
   <chr>       <dbl>    <dbl>   <dbl>    <dbl>     <dbl> <dbl>    <dbl>    <dbl>
 1 pi_1      9.96e-1  9.97e-1 3.79e-3  9.85e-1   1.000    1.15    12.6      81.1
 2 pi_2      3.94e-3  2.71e-3 3.76e-3  2.55e-4   0.0141   1.16    11.2      78.4
 3 pi_3      4.96e-4  3.35e-4 5.18e-4  1.13e-5   0.00204  1.00   662.      259. 
 4 tau_alp~  1.59e+0  1.59e+0 5.92e-3  1.58e+0   1.60     1.01   312.      315. 
 5 nu_alpha -3.70e-1 -3.70e-1 4.94e-3 -3.80e-1  -0.361    1.00   220.      436. 
 6 iota_m_~ -4.75e-1 -5.02e-1 9.43e-1 -2.22e+0   1.23     1.04    56.7     209. 
 7 iota_s_~ -3.17e-1 -5.77e-1 9.47e-1 -1.76e+0   1.77     1.14    11.7     113. 
 8 chi_m_a~ -2.08e-2  8.88e-3 9.78e-1 -1.90e+0   1.85     1.00  1235.      318. 
 9 chi_s_a~ -1.17e-2  8.66e-3 1.04e+0 -1.93e+0   1.91     1.00  1349.      474. 
10 sigma_t~  2.11e-1  2.11e-1 4.89e-3  2.02e-1   0.220    1.01   259.      357. 
11 sigma_nu  1.69e-1  1.69e-1 4.99e-3  1.60e-1   0.180    1.06    26.6     207. 
12 sigma_i~  3.84e-1  3.69e-1 1.96e-1  8.90e-2   0.826    1.00   639.      401. 
13 sigma_i~  4.04e-1  3.78e-1 2.15e-1  8.33e-2   0.896    1.00   358.      303. 
14 sigma_c~  3.98e-1  3.71e-1 2.05e-1  8.69e-2   0.830    1.00   798.      403. 
15 sigma_c~  3.96e-1  3.61e-1 2.08e-1  6.71e-2   0.868    1.01   932.      311. 
16 Ft        6.11e+1  4.95e+1 5.70e+1  1.35e+0 196.       1.23     8.24     87.3
17 Fw        2.37e+2  1.83e+2 2.25e+2  1.31e+1 786.       1.23     8.60     43.8
18 stolen_~  1.76e+2  1.16e+2 1.79e+2  9.41e+0 655.       1.21     9.24     80.6

## Notas

- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_QBL_FULL=1` para a calibração completa.
- Smoke test concluído com a aproximação hierárquica Stan do qbl. As contagens latentes binomiais do JAGS foram relaxadas para magnitudes contínuas. A parametrização intercept-only também colapsa dimensões redundantes de mistura e intercepto para melhorar a geometria do HMC.
- Diagnóstico: `rhat_max = 1.229` ainda está alto.
- Diagnóstico: `ESS_bulk_min = 8.2` ainda é baixo.
