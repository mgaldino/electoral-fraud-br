# Instrução prospectiva sobre paralelismo

Durante a rodada Stan já iniciada, o usuário determinou:

> Pro futuro, rode as cadeias em parlaelo, usando mais cores, sempre que possivel.

As próximas rodadas deverão usar cadeias paralelas, respeitando os núcleos
e a memória efetivamente disponíveis. Para quatro cadeias, preferir quatro
processos concorrentes quando houver capacidade. Registrar configuração,
concorrência e uso de recursos; não comparar tempos como se configurações
seriais e paralelas fossem iguais. A política também foi incorporada ao
CLAUDE.md para orientar futuras sessões.

Esta instrução não altera os contratos nem as saídas da rodada atual.
O ajuste em curso permanece serial, sem reinício e sem nova tentativa
automática. Nenhuma instalação, exclusão ou amostragem adicional decorre
deste registro.
