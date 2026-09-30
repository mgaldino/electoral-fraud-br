# Checagem prévia do protocolo G3

O coordenador inspecionou `G3/round1/protocol.json` antes de receber resultados;
a listagem naquele momento continha apenas esse arquivo. A versão inicial
especificava duas cadeias, tolerância absoluta fixa de 0,12, ESS mínimo 50 e
R-hat máximo 1,2, sem definir o cálculo de erro Monte Carlo. Isso não demonstrava
o critério G3-T4 de comparação dentro do erro Monte Carlo.

Foi solicitado ao executor preservar v1 e congelar v2 antes dos testes, com
quatro cadeias, MCSE explícito, tolerância para médias `max(0.001, 6*MCSE)` e
diagnósticos rank-normalized split R-hat < 1,01 e bulk/tail ESS >= 400 para
alvos não constantes. Alvos constantes precisam de tratamento analítico, não
de diagnóstico artificial. Todos os quatro counts, Z e funcionais conjuntos
do contraste devem ser monitorados. A comparação é condicionada nos parâmetros
contínuos, sem alegar validação de toda a posterior hierárquica.

Se alguma execução v1 tiver começado antes da mensagem, seus logs e processos
devem ser preservados e observados até o estado terminal, sem reinício por perda
de observação. Essa execução será piloto; a comparação v2 usa sementes novas.
Nenhuma tolerância pode ser ajustada em função dos resultados. A QA deve
conferir a precedência temporal e o cálculo da MCSE independentemente.

Este preflight corrige critérios de teste insuficientes, sem alterar modelo,
priors, dados ou estimandos, e não constitui aprovação de G3.
