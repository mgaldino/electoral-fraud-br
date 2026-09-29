# Adjudicação G2 round1

**Decisão: G2 permanece `changes_requested`.** A revisão independente e as contraprovas da coordenação confirmam a auditoria matemática; não foi encontrado erro material nas derivações do candidato. Há três decisões substantivas abertas antes da implementação G3.

Tabela 1. Pendências confirmadas e alcance da decisão.

| ID | O que está estabelecido | O que precisa ser escolhido |
|:--|:--|:--|
| G2-QA-D1 | Paper, qbl/JAGS e Stan histórico têm alvos distintos. O qbl admite pais latentes com pW inválido; o clamp e o plug-in do Stan mudam o modelo. | Reproduzir primeiro o software como benchmark ou desenvolver um modelo gerador alternativo. A política runtime do JAGS ainda deve ser testada. |
| G2-QA-D2 | Exp(5) na variância e no desvio-padrão gera priors diferentes; interceptos e codificação geográfica também importam. | Preservar exatamente a implementação escolhida ou aprovar uma variante nomeada. Nenhuma mudança de prior foi aplicada. |
| G2-QA-D3 | Distribuição completa do funcional e distribuição de sua esperança condicional têm incertezas diferentes. A origem dos votos stolen não é identificada pelo agregado não-leader. | Fixar o estimando; recomendar draws conjuntos completos e limites para margem, sem supor que todo stolen veio do segundo colocado. |

## Evidência

O candidato está vinculado pelo manifesto `783cfb036f8f26bf894c36782df4fb94e20351e4df015ca6e24330021d04a5a9`; a revisão, por `a027cd5ad0875ffbb92e3b983c2907700fe6e8b4dbfc776df141ef9f5f80ba7c`. A coordenação verificou os 73 arquivos do candidato e os 49 arquivos do manifesto de revisão.

A QA executou 75 testes próprios e 162 enumerações pequenas, com erro máximo de 4,44e-16. A coordenação executou nove verificações adicionais em R/base: pW=499,5, massas físicas 0,875 e 0,96875, likelihood exata 0,4116 versus plug-in 0,4872, variâncias residuais médias 0,2 versus 0,08 e diferença de incerteza ao guardar somente esperanças condicionais. Scripts e resultados estão em `adjudication_checks.R/.csv` e `adjudication_integrity.py/.json`.

G2-T5 está concluído no sentido da rederivação independente. Os testes que passam demonstram as identidades e os contraexemplos declarados; não aprovam a especificação para inferência eleitoral.

## Encaminhamento

Foi solicitada ao usuário a escolha da próxima rota metodológica. A recomendação é primeiro reproduzir fielmente o JAGS como benchmark, preservando suas priors, sem liberá-lo automaticamente para inferência. Um modelo gerador alternativo pode ser valioso, mas precisa ser identificado como outro modelo, não como portagem equivalente.

Não foi feita execução JAGS/Stan, compilação, MCMC ou instalação. A semântica runtime diante de pais inválidos permanece não testada. Não se declarou convergência dos fits históricos, superioridade de um sampler ou ausência de fraude.

O veredicto estruturado `BLOCKED` refere-se exclusivamente a esta adjudicação; o estado operacional é `changes_requested`. A preparação dos dados pode avançar por G1/G7, sem depender dessa escolha e sem alterar o alvo inferencial.

