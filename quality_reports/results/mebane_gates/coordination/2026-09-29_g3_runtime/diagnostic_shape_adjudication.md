# G3-COORD-DIAG-01: diagnóstico preservando cadeias

**CONFIRMED; READY_FOR_IMPLEMENTATION somente para o reparo delimitado.**
O candidato revision2, hash `de779221e409`, transforma a matriz 2000 x 4 em
um objeto `draws_array` antes de chamar as funções escalares do pacote
`posterior`. A contraprova independente mostra que essas chamadas convertem o
objeto em uma matriz 8000 x 1. O split é então 4000 x 2, em vez de 1000 x 8.
Os números do candidato coincidem com o caminho incorretamente agrupado.

O coordenador conferiu código congelado e contraprova. A correção passa a
matriz numérica iterações x cadeias diretamente a R-hat/ESS, com dimensões
verificadas e controle adversarial que detecte perda da identidade das cadeias.
Reprocessar o RDS existente em revision3, sem nova amostragem. As médias e
MCSE não precisam de novo alvo nem de tolerâncias novas.

O caso é independente do ESS de cauda indisponível para distribuições com
átomos. O protocolo continua igual; NA não é automaticamente não-convergência,
mas tampouco satisfaz o critério congelado. F1/F2 e a decisão de produção
permanecem sem correção. O JSON adjacente vincula a fonte e a evidência por hash.
