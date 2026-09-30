# Primeira tentativa determinística

O comando `Rscript .../check_proposals.R .../checks01` terminou com exit code 1
na condição `max(results$sequential_error) < 1e-11`. A tentativa também emitiu
avisos de locale e mais de 50 avisos durante as avaliações binomiais. Não houve
estimação nem aleatoriedade. O código original está preservado neste diretório.

A expressão `pW/(1-pA)` sofre cancelamento e pode exceder 1 por arredondamento
nas fronteiras da grade. O reparo usa o denominador algebricamente equivalente
`pW+pO`, soma de células não negativas, sem clamp, novo domínio ou tolerância.
Também passa a salvar a tabela numérica antes dos asserts para que uma eventual
falha subsequente preserve seus valores. A tolerância continua `1e-11`.
