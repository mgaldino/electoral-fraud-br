# Correções dos verificadores independentes

## Tentativa 01: booleano no cabeçalho CmdStan

`attempt01/recompute.log` e `attempt01/recompute_checks.json` preservam a interrupção em `CSV:1:warmup-saved`. O CSV original, `stan2k01/csv/D_Stan-1.csv`, linha 10, declara `#     save_warmup = true`. O helper independente `csv_setting()` tentava converter esse texto diretamente para número, obtendo NA.

Classificação: erro do checker, não da candidata. Correção: converter os tokens explícitos `true` e `false` para 1 e 0 antes da conversão numérica geral. O critério continua exigindo warmup salvo, sem alterar dados, candidata, sementes ou thresholds. A tentativa corrigida usa um diretório novo; a tentativa 01 permanece intacta. Os fontes dos verificadores passam também a ser preservados em `reviewer_sources/` de cada nova tentativa.
