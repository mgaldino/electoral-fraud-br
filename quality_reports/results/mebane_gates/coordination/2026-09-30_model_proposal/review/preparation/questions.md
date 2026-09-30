# Questões independentes para a proposta ainda não recebida

Este documento prepara revisão; não avalia nem aprova uma proposta ausente. A adjudicação é exclusiva da coordenação. Os critérios abaixo não autorizam implementar ou estimar qualquer alternativa.

## Identidade e fechamento documental

1. Os sete fontes recuperados têm exatamente os hashes da auditoria independente, incluindo newline final e demais bytes? Cada fonte está ligado à tentativa, comando, versão da biblioteca e evento bruto correspondente?
2. A reconstrução usa somente os eventos originais, sem completar código por plausibilidade? Seu programa e todos os inputs efetivos estão incluídos no novo manifesto?
3. Permanecem intactos os candidatos históricos, os protocolos, os logs e o RDS? Uma aceitação documental precisa dizer explicitamente que não transforma G3 em PASS nem altera o parecer histórico.

## Quatro alternativas distintas

4. **Referência literal:** a proposta preserva sua identidade por SHA e os contraexemplos F1/F2? Compilar, obter draws ou zerar estados inválidos não estabelece uma likelihood normalizada. A fonte literal é referência de software; não gerador aprovado.
5. **Kernel normalizado no triângulo:** qual é exatamente K(A,W;theta), com quais latentes integrados e em que ordem? Qual é C(theta), quando é estritamente positivo e onde aparece na likelihood? Normalizar a mistura inteira repondera suas classes por pi_z C_z / sum(pi C); normalizar cada componente e manter pi define outro modelo. Não basta dizer que será feita uma truncagem ou rejeição.
6. **Probabilidades dos artigos com binomiais independentes:** estão preservadas as duas tentativas N e a classe conjunta compartilhada por A e W? Probabilidades no simplex não eliminam A+W>N no produto de binomiais. Se a alternativa for apenas likelihood composta/marginal, a proposta deve rotulá-la assim e não prometer um gerador conjunto físico.
7. **Transferências e multinomial:** qual mecanismo produz categorias mutuamente exclusivas? Quais eleitores de abstinência e de outros votos podem ser transferidos? As variáveis M e S representam contagens realizadas ou esperanças? O produto sequencial correto tem W|A com N-A tentativas e probabilidade pW/(1-pA), incluindo a fronteira pA=1. Não é o qbl literal nem apenas uma troca de engine.

## Comparabilidade e interpretação

8. As alternativas têm os mesmos observáveis, denominadores, priors/hierarquia e estimandos? Se não, que mudanças são deliberadas? Corrigir a likelihood não autoriza trocar Exp(5) de variância por SD, retirar efeitos, fundir alpha+b0, ordenar pi2/pi3 ou substituir contagens discretas por suas médias.
9. O que demonstra identificação? Duas parametrizações de transferências podem induzir o mesmo (pA,pW,pO) e quantidades de fraude diferentes. A proposta deve distinguir restrições identificadoras, regularização por prior, mistura/população e informação externa; convergência não responde a essa questão.
10. Qual é o conteúdo de O? Com brancos, nulos e vários candidatos agregados, devolver S ao resíduo não determina automaticamente a identidade do beneficiário nem a margem contrafactual. Um limite condicional não é uma contagem observada de fraude.
11. A recomendação curta explica ao usuário os custos e a mudança substantiva de cada opção, em vez de eleger o modelo somente porque normaliza? A validação futura deve ser separada da decisão sobre qual alvo estudar.
12. Os artigos específicos, edições, páginas e equações estão identificados por fontes locais verificáveis? As equações lidas hoje no contrato G2 orientam as contraprovas, mas não substituem a conferência de fidelidade das citações da proposta futura.

## Limites do julgamento

Aceitar um reparo documental, uma identidade algébrica ou uma distribuição normalizada não demonstra identificação de fraude, validade inferencial, adequação ao Brasil ou segurança para produção. Nenhuma hipótese nova de geração, prior, geografia ou contrafactual foi aprovada neste preflight. O parecer final depende dos bytes congelados da proposta e do pacote documental.
