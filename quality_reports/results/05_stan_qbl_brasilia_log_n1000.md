# Bloco 5B -- log da calibração Stan qbl

Data/hora: 2026-04-11 10:33:13 -0300
R: 4.4.2
CmdStanR: 0.9.0
CmdStan: 2.37.0

## Alvo do modelo

- Modelo: aproximação Stan do `qbl()` canônico do `UMeforensics`.
- Mantido: prior ordenado de `pi`, seis blocos hierárquicos e `k = 0.7`.
- Relaxação: as contagens binomiais latentes `N.iota.*` e `N.chi.*` do JAGS foram substituídas por magnitudes contínuas na escala logística.
- Tempo de compilação Stan: `0.04 s`.

## Dataset usado na última execução

- Seções: 1000
- Aptos totais: 326969
- Abstenções totais: 55765
- Votos do leader totais: 111169

## Timings

                phase            model n_obs n_chains warmup sampling_iter
               <char>           <char> <int>    <int>  <int>         <int>
1: smoke_brasilia_qbl qbl_stan_relaxed  1000        2    500           250
   total_iter wall_seconds per_iter_ms per_iter_per_obs_us ess_bulk_min
        <int>        <num>       <num>               <num>        <num>
1:        750     287.6401    383.5202            383.5202     15.29029
   ess_tail_min rhat_max divergent_transitions max_treedepth_hits
          <num>    <num>                 <int>              <int>
1:     36.32519 1.105083                     0                  0

## Resumo posterior (última execução disponível)

# A tibble: 18 x 9
   variable      mean   median      sd     q2.5    q97.5  rhat ess_bulk ess_tail
   <chr>        <dbl>    <dbl>   <dbl>    <dbl>    <dbl> <dbl>    <dbl>    <dbl>
 1 pi_1       9.85e-1  9.91e-1 1.65e-2  9.36e-1  9.99e-1  1.08     18.6     55.4
 2 pi_2       1.42e-2  8.06e-3 1.64e-2  1.34e-4  6.27e-2  1.09     17.7     62.3
 3 pi_3       9.98e-4  7.02e-4 9.51e-4  3.73e-5  3.53e-3  1.01    581.     349. 
 4 tau_alpha  1.60e+0  1.60e+0 1.31e-2  1.58e+0  1.63e+0  1.00    344.     434. 
 5 nu_alpha  -3.70e-1 -3.70e-1 1.36e-2 -3.96e-1 -3.43e-1  1.01    102.     335. 
 6 iota_m_a~ -1.07e+0 -1.16e+0 9.17e-1 -2.56e+0  9.86e-1  1.03     47.2    180. 
 7 iota_s_a~ -9.25e-1 -1.08e+0 7.29e-1 -1.94e+0  1.17e+0  1.02     94.9    146. 
 8 chi_m_al~  2.22e-3  3.73e-2 1.08e+0 -2.28e+0  2.09e+0  1.00    881.     335. 
 9 chi_s_al~ -2.43e-2 -2.97e-2 1.05e+0 -2.12e+0  1.90e+0  1.02   1349.     281. 
10 sigma_tau  2.02e-1  2.02e-1 6.95e-3  1.89e-1  2.15e-1  1.00    225.     322. 
11 sigma_nu   1.83e-1  1.84e-1 8.70e-3  1.65e-1  1.98e-1  1.03     41.3     51.6
12 sigma_io~  3.73e-1  3.43e-1 2.05e-1  8.11e-2  8.50e-1  1.01    452.     288. 
13 sigma_io~  3.50e-1  3.17e-1 2.01e-1  7.29e-2  8.25e-1  1.00    345.     352. 
14 sigma_ch~  4.04e-1  3.56e-1 2.03e-1  9.97e-2  8.77e-1  1.00    812.     372. 
15 sigma_ch~  3.94e-1  3.63e-1 2.22e-1  6.15e-2  8.71e-1  1.00    571.     302. 
16 Ft         8.25e+1  6.01e+1 8.23e+1  5.22e-6  2.87e+2  1.11     16.7    135. 
17 Fw         3.86e+2  2.44e+2 4.12e+2  5.86e-5  1.51e+3  1.10     15.3     36.3
18 stolen_v~  3.04e+2  1.82e+2 3.46e+2  4.76e-5  1.29e+3  1.10     15.7     39.3

## Notas

- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_QBL_FULL=1` para a calibração completa.
- Smoke test concluído com a aproximação hierárquica Stan do qbl. As contagens latentes binomiais do JAGS foram relaxadas para magnitudes contínuas.
- Diagnóstico: `rhat_max = 1.105` ainda está alto.
- Diagnóstico: `ESS_bulk_min = 15.3` ainda é baixo.
