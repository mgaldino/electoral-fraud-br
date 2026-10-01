# Adendo adjudicado às referências B1

Este adendo acompanha o CSV e o dicionário congelados; não altera seus
bytes nem os 51 registros. Parecer independente: `review/review.json`.

**B1-R1-F01 confirmado.** Nas páginas impressas 25 e 33 do PDF (páginas
26 e 34 do arquivo), os nove totais partidários somam 6.137.671. A coluna
publicada `Votos.Válidos` soma 6.137.778: diferença de 107. O comando do
autor constrói `NValid` da soma dos partidos, não dessa coluna. Logo,
usando `Inscritos=7.314.446`, o `A=N-NValid` agregado é 1.176.775.
Essas contas foram recompostas pelo revisor e pelo coordenador, que também
inspecionou a página. B2 deve investigar a discrepância no dado por mesa,
preservando ambos os totais publicados e a fórmula; não inventar correção,
causa ou exclusão de linhas. Isso não indica fraude eleitoral.

**B1-R1-F02 confirmado e esclarecido.** A frase do dicionário sobre
"Tabelas 1-18" ser um conjunto de saídas por mesa é imprecisa. A Tabela 1,
página impressa 4 (PDF 5), apresenta diagnósticos de dígitos/distribuição
para MAS/CC, com intervalos bootstrap, e é distinta das tabelas por mesa.
Continua fora do alvo declarado de 51 registros; não há célula faltante
nesse alvo por causa dessa correção.

**Escopo da aceitação.** A fidelidade da transcrição e a qualificação das
fontes foram aceitas. As definições operacionais completas dos intervalos
e agregados não estão certificadas: 95% global é inferência condicionada
ao código arquivado; o commit efetivo e scripts externos da Bolívia não
foram identificados. O critério forte de B1 sobre definição inequívoca
do alvo de replicação permanece pendente. Por isso, o gate não recebe
PASS integral nem libera estimação. Trabalho independente de localização
e reconstrução de dados pode continuar, sem adoção do input ou B4.
