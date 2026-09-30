# Segunda tentativa determinística

O comando com `LC_ALL=C` terminou na checagem de equivalência sem transferências:
`abs(same["A"] - pA) < 1e-12 is not TRUE`. A tabela de 332 distribuições foi
salva antes da falha, e os asserts de normalização/equivalência anteriores passaram.

A causa é a composição automática de nomes de vetores em R. Um escalar herdado
com nome A, passado como tau, fez a função devolver A.A em vez de A, resultando
em NA ao selecionar A. O reparo remove nomes dos quatro argumentos escalares
na entrada de `paper_probs`; não altera fórmulas, casos ou tolerâncias. O código
anterior está preservado como `check_proposals_second.R`.
