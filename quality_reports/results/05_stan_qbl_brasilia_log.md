# Bloco 5B -- log da calibração Stan qbl

Data/hora: 2026-04-12 12:54:13 -0300
R: 4.4.2
CmdStanR: 0.9.0
CmdStan: 2.37.0

## Alvo do modelo

- Modelo: aproximação Stan do `qbl()` canônico do `UMeforensics`.
- Mantido: prior ordenado de `pi`, seis blocos hierárquicos e `k = 0.7`.
- Relaxação: as contagens binomiais latentes `N.iota.*` e `N.chi.*` do JAGS foram substituídas por magnitudes contínuas na escala logística.
- Reparametrização: no caso intercept-only, `pi.aux1` foi marginalizado e os interceptos fixos ultra-concentrados foram colapsados nas localizações `alpha`.
- Tempo de compilação Stan: `0.04 s`.

## Dataset usado na última execução

- Seções: 2000
- Aptos totais: 647623
- Abstenções totais: 111375
- Votos do leader totais: 219317
- Zone FE: ativo (18 dummies)

## Timings

                phase                    model n_obs n_chains warmup
               <char>                   <char> <int>    <int>  <int>
1: smoke_brasilia_qbl qbl_stan_relaxed_reparam  2000        2     50
   sampling_iter total_iter wall_seconds per_iter_ms per_iter_per_obs_us
           <int>      <int>        <num>       <num>               <num>
1:           100        150     635.3398    4235.599            2117.799
   ess_bulk_min ess_tail_min rhat_max divergent_transitions max_treedepth_hits
          <num>        <num>    <num>                 <int>              <int>
1:     45.06249     21.37938 1.102356                     0                  0

## Resumo posterior (última execução disponível)

# A tibble: 90 × 9
   variable      mean   median      sd     q2.5    q97.5  rhat ess_bulk ess_tail
   <chr>        <dbl>    <dbl>   <dbl>    <dbl>    <dbl> <dbl>    <dbl>    <dbl>
 1 pi_1       5.03e-1  5.02e-1 2.96e-3  5.00e-1  0.510   1.04     134.     150. 
 2 pi_2       4.97e-1  4.97e-1 2.88e-3  4.90e-1  0.500   1.05      45.7     64.3
 3 pi_3       6.42e-4  4.56e-4 5.89e-4  1.44e-5  0.00213 1.01     140.      95.9
 4 tau_alpha  1.56e+0  1.56e+0 7.96e-3  1.55e+0  1.58    1.01     193.      78.6
 5 nu_alpha  -4.75e-1 -4.75e-1 6.86e-3 -4.88e-1 -0.462   0.999    106.     153. 
 6 iota_m_a… -2.85e+0 -2.83e+0 3.52e-1 -3.54e+0 -2.21    0.993    233.     202. 
 7 iota_s_a… -1.36e+0 -1.35e+0 6.22e-2 -1.50e+0 -1.26    1.00     282.     222. 
 8 chi_m_al… -2.49e-1 -3.14e-1 1.15e+0 -2.51e+0  2.24    1.02     285.     108. 
 9 chi_s_al… -2.43e-1 -2.36e-1 9.66e-1 -2.18e+0  1.51    1.01     202.     139. 
10 sigma_tau  2.05e-1  2.05e-1 5.31e-3  1.94e-1  0.215   1.04      64.2    151. 
# ℹ 80 more rows

## Notas

- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_QBL_FULL=1` para a calibração completa.
- Smoke test concluído com a aproximação hierárquica Stan do qbl. As contagens latentes binomiais do JAGS foram relaxadas para magnitudes contínuas. A parametrização intercept-only também colapsa dimensões redundantes de mistura e intercepto para melhorar a geometria do HMC.
- Diagnóstico: `rhat_max = 1.102` ainda está alto.
- Diagnóstico: `ESS_bulk_min = 45.1` ainda é baixo.
