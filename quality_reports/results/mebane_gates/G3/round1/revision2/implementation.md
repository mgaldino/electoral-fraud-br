# G3 round1 revision2: persistência dos draws

Reparo delimitado de `G3-COORD-DRAW-01`, adjudicado `READY_FOR_IMPLEMENTATION`.
O candidato anterior, revision1, SHA-256
`4b84fe6996a72321225fd3e5f4713439b77b74fc8a7f039d09e3dcaf7beb72a9`,
permanece íntegro. Nenhum protocolo, critério, seed, caso ou modelo foi alterado.
Esta revisão **não** promove G3, resolve F1/F2 ou certifica margem física.

`raw_chains.rds` contém o `mcmc.list` bruto de quatro cadeias, 2.000 draws
por cadeia e os cinco nós monitorados (`Z` e quatro contagens), além dos
dados condicionados, inits/RNG, versões e configuração. É uma **nova**
execução do mesmo problema, não recuperação dos draws não salvos em revision1.
O script `g3_draw_replay.R` executou somente esse contraste, sem probes ou
enumeração. `g3_draw_postprocess.R`, em processo separado, reabriu o RDS,
recalculou M/S e limites por draw, conferiu sete identidades e produziu MCSE,
rank-split Rhat e ESS pela regra congelada. O CSV de comparação com revision1
é descritivo e não acrescenta tolerância de aceitação.

Resultado: as médias cumpriram `max(1e-3,6*MCSE)`, mas tail ESS permaneceu
`NA` para nove alvos discretos. `S` é zero no suporte posterior positivo e
foi tratado analiticamente, sem alegar diagnóstico de cadeia. O status segue
`inconclusive`. `Dobs=1` é offset algébrico incompatível com N=1,A=0,W=0;
flags de capacidade/compatibilidade não autorizam contrafactual físico.
Ainda são necessárias revisão independente dos draws e decisão substantiva
G2 sobre F1/F2 antes de qualquer aprovação de produção.
