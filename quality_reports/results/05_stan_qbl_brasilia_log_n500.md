# Bloco 5B -- log da calibração Stan qbl

Data/hora: 2026-04-11 10:27:04 -0300
R: 4.4.2
CmdStanR: 0.9.0
CmdStan: 2.37.0

## Alvo do modelo

- Modelo: aproximação Stan do `qbl()` canônico do `UMeforensics`.
- Mantido: prior ordenado de `pi`, seis blocos hierárquicos e `k = 0.7`.
- Relaxação: as contagens binomiais latentes `N.iota.*` e `N.chi.*` do JAGS foram substituídas por magnitudes contínuas na escala logística.
- Tempo de compilação Stan: `0.05 s`.

## Dataset usado na última execução

- Seções: 500
- Aptos totais: 159727
- Abstenções totais: 27546
- Votos do leader totais: 57464

## Timings

                phase            model n_obs n_chains warmup sampling_iter
               <char>           <char> <int>    <int>  <int>         <int>
1: smoke_brasilia_qbl qbl_stan_relaxed   500        2    500           250
   total_iter wall_seconds per_iter_ms per_iter_per_obs_us ess_bulk_min
        <int>        <num>       <num>               <num>        <num>
1:        750     235.0017    313.3356            626.6711     36.55647
   ess_tail_min rhat_max divergent_transitions max_treedepth_hits
          <num>    <num>                 <int>              <int>
1:     75.00493  1.04062                     0                  0

## Resumo posterior (última execução disponível)

# A tibble: 18 x 9
   variable      mean   median      sd     q2.5    q97.5  rhat ess_bulk ess_tail
   <chr>        <dbl>    <dbl>   <dbl>    <dbl>    <dbl> <dbl>    <dbl>    <dbl>
 1 pi_1       7.70e-1  7.73e-1 7.87e-2  6.05e-1  9.10e-1 1.03      50.8     96.4
 2 pi_2       2.28e-1  2.25e-1 7.87e-2  8.68e-2  3.94e-1 1.03      49.8     81.0
 3 pi_3       2.13e-3  1.36e-3 2.38e-3  2.20e-5  8.69e-3 1.01     561.     299. 
 4 tau_alpha  1.55e+0  1.55e+0 1.95e-2  1.51e+0  1.58e+0 1.02     120.     132. 
 5 nu_alpha  -3.19e-1 -3.19e-1 2.24e-2 -3.69e-1 -2.79e-1 1.02      52.1    115. 
 6 iota_m_a~ -1.58e+0 -1.56e+0 3.11e-1 -2.26e+0 -1.04e+0 1.02     110.     226. 
 7 iota_s_a~ -1.95e+0 -1.92e+0 2.58e-1 -2.54e+0 -1.54e+0 1.02     105.     168. 
 8 chi_m_al~  3.40e-2  6.78e-2 1.08e+0 -2.05e+0  2.24e+0 1.01    1329.     287. 
 9 chi_s_al~  3.10e-2  2.96e-2 1.02e+0 -1.89e+0  1.94e+0 0.998    844.     401. 
10 sigma_tau  1.41e-1  1.41e-1 1.04e-2  1.23e-1  1.61e-1 1.00     261.     446. 
11 sigma_nu   1.08e-1  1.07e-1 1.45e-2  7.83e-2  1.37e-1 1.03      57.6     84.3
12 sigma_io~  3.12e-1  2.93e-1 1.59e-1  4.54e-2  6.31e-1 1.02     147.     261. 
13 sigma_io~  3.05e-1  2.94e-1 1.57e-1  6.41e-2  6.56e-1 1.03      97.5    258. 
14 sigma_ch~  4.04e-1  3.82e-1 2.00e-1  9.46e-2  8.52e-1 1.000    804.     344. 
15 sigma_ch~  3.97e-1  3.71e-1 2.03e-1  8.12e-2  8.65e-1 0.998    714.     409. 
16 Ft         7.39e+2  7.13e+2 2.74e+2  3.08e+2  1.34e+3 1.02      71.6    122. 
17 Fw         2.18e+3  2.16e+3 6.02e+2  1.00e+3  3.45e+3 1.03      40.3     75.0
18 stolen_v~  1.44e+3  1.40e+3 4.34e+2  6.47e+2  2.41e+3 1.04      36.6     92.6

## Notas

- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_QBL_FULL=1` para a calibração completa.
- Smoke test concluído com a aproximação hierárquica Stan do qbl. As contagens latentes binomiais do JAGS foram relaxadas para magnitudes contínuas.
- Diagnóstico: `rhat_max = 1.041` ainda está alto.
- Diagnóstico: `ESS_bulk_min = 36.6` ainda é baixo.
