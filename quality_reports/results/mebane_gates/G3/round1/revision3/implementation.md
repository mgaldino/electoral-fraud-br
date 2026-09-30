# G3 round1 revision3: forma dos diagnósticos

O reparo G3-COORD-DIAG-01 passa uma matriz numérica ordinary 2000 x 4
diretamente a `posterior::rhat`, `posterior::ess_bulk` e `posterior::ess_tail`.
A função compartilhada pelo pós-processamento e pela regressão rejeita
dimensões ou classes incompatíveis antes de calcular os diagnósticos.
O RDS de revision2 foi reaberto, com SHA-256
`66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d`.
Nenhuma nova MCMC foi executada.

A regressão determinística usa quatro cadeias com médias -2, +2, -2, +2
e uma onda pequena, conforme `repair_plan.json`, congelado antes dos checks.
Rhat correto foi 1.73364677702875; o caminho antigo, que agrupa as quatro
cadeias antes do split, produziu 0.999874992186523. As nove verificações
passaram, incluindo rejeição de array 2000 x 4 x 1, matriz 8000 x 1 e matriz
transposta. As três estatísticas da função de produção coincidiram com as
chamadas diretas sobre a matriz preservando as cadeias.

Nos draws do caso condicionado, os diagnósticos corrigidos concordam com os
valores independentes da QA. Para N.iota.s, Rhat é 1.00120757086769, ante
1.00020832622997 no resumo anterior. Os funcionais por draw e os estados
exatos permanecem byte-idênticos aos arquivos de revision2; médias, MCSE,
expectativas exatas e tolerâncias também permanecem iguais dentro de 1e-12.

O defeito de forma está implementado e entregue para QA. O problema separado
de diagnósticos em distribuições discretas permanece: tail ESS retornou NA
para nove alvos não constantes. A QA atribui esses casos ao indicador de
cauda superior constante, conforme sua tabela arquivada; esses NAs continuam
sem satisfazer o critério do protocolo. S é constante no suporte posterior
positivo e recebe tratamento analítico. O resultado do candidato continua
inconclusive, sem conclusão sobre convergência nacional ou resolução F1/F2.

Os manifestos de revision1 e revision2 mantêm seus hashes originais. Antes
da edição, todos os 321 registros de revision2 foram conferidos. Os arquivos
canônicos referenciados por aquele candidato foram copiados para
`inherited_snapshots`; `predecessor_files.json` mapeia cada hash anterior aos
bytes preservados. O código novo tem snapshot próprio em `code_snapshots`.
O manifesto ativo usa esses snapshots, o RDS existente e os novos outputs,
sem depender do ledger vivo.
