# Comparacao cross-engine: JAGS vs Stan, intercept-only vs zone FE

Data: 2026-04-12 13:11:55 -0300

## Fits disponiveis

- **JAGS_IO**
- **JAGS_FE**

## Tabela comparativa (posterior mean [95%% CI])

| Parametro          | JAGS_IO                        | JAGS_FE                        | 
|--------------------|--------------------------------|--------------------------------| 
| tau_alpha          | 1.6165 [1.5953, 1.6364]        | 1.6152 [1.5985, 1.6334]        | 
| nu_alpha           | -0.4303 [-0.4504, -0.4089]     | -0.4305 [-0.4464, -0.4102]     | 
| pi[1]              | 0.9912 [0.9870, 0.9941]        | 0.9876 [0.9749, 0.9932]        | 
| pi[2]              | 0.0085 [0.0056, 0.0127]        | 0.0121 [0.0065, 0.0248]        | 
| pi[3]              | 0.0003 [0.0000, 0.0009]        | 0.0003 [0.0000, 0.0009]        | 
| iota_m_alpha       | 0.0420 [-0.4298, 0.2801]       | -0.2046 [-0.6938, 0.0255]      | 
| iota_s_alpha       | -0.3246 [-0.4818, -0.1835]     | -0.4205 [-0.9628, -0.1142]     | 
| chi_m_alpha        | -0.0619 [-0.4155, 0.1362]      | -0.0555 [-0.2092, 0.1058]      | 
| chi_s_alpha        | -0.1073 [-0.4497, 0.3692]      | -0.0100 [-0.1907, 0.1089]      | 
| sigma_tau          | 0.2043 [0.1988, 0.2100]        | 0.2043 [0.1990, 0.2097]        | 
| sigma_nu           | 0.1970 [0.1911, 0.2024]        | 0.1943 [0.1845, 0.2015]        | 
| Ft                 | --                             | --                             | 
| Fw                 | --                             | --                             | 
| stolen             | --                             | --                             | 

## Notas

- JAGS `tb`/`nb` foram transformados para sqrt(tb)/sqrt(nb) (SD) para comparabilidade com Stan `sigma_tau`/`sigma_nu`.
- JAGS nao computa Ft/Fw diretamente (calculado post-hoc ou via Stan).
- Ft = manufactured votes, Fw = total fraudulent votes, stolen = Fw - Ft.
- Valores de Ft/Fw proximos de zero suportam a hipotese nula (sem fraude).
