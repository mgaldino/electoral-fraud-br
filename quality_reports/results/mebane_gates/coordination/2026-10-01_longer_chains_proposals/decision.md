# Propostas para JAGS 100 mil e Stan 5 mil

Data: 01/10/2026. Estado: **aguardando propostas e confirmação do usuário**.
Nenhuma nova amostragem ou alteração de priori foi iniciada nesta frente.

## Pedido do usuário

> Acho que com mistura, jamais iremos alcançar ESS bulk na causa de 400. Vamos ter que aceitar que nas caudas vamos ter imprecisão. Em todo caso, vamos rodar jags com 100k, stan com 5k. O burn-in nao precisa ficar em metade, pode deixar fixo em número menor (tanto pra jags quanto pra stan). Verifique comigo as propostas dos agentes para eu confirmar. Por fim, temos que investigar quais parametros estamos ficando com ESS bulk super baixo. A dificuldade de mixagem é potencialmente problema de priori que não é suficientemente informativa, ainda mais que nao fixamos a ordem de qual é mais provavel, incremental ou transferencia de votos entre candidatos.

## Escopo atual

Interpretar 100 mil/5 mil como draws retidos por cadeia, sujeitos à confirmação
junto com burn-in/warmup fixos e quatro cadeias paralelas. O caso proposto
continua D.C. 2010, mesmas 143 unidades. A é o qbl literal em JAGS; D é a
alternativa multinomial em JAGS e Stan. Não é uma estimação brasileira ou
boliviana. Quantidade de draws, modelo, caso e braços serão explicitados
na proposta consolidada antes da execução.

Trabalho autorizado agora: diagnóstico dos draws existentes, dimensionamento
de recursos, investigação de identificação e propostas. Não executar MCMC,
compilação ou alterações de modelo/priori antes da confirmação solicitada.
Não instalar ou excluir arquivos. Nenhum limiar histórico é modificado.

## Delegação

- Maxwell / Sol, `01a0f748-c560-7140-b832-5d2601df82b0`: goal finito de diagnóstico dos draws existentes, ranking de parâmetros com ESS bulk baixo e proposta de burn-in/warmup. Escrita somente em `diagnostics/`.
- Curie / modelo principal herdado, `01a0f756-1646-7910-ac2f-986ab89aac82`: goal finito de análise do modelo/prioris e regras prospectivas de precisão. Escrita somente em `model_proposals/`.
- Coordenador: recursos, confronto das propostas com a evidência, revisão independente pertinente e apresentação ao usuário. A conclusão dos goals de proposta não libera amostragem.

## Distinções obrigatórias

ESS bulk baixo em parâmetros contínuos centrais, imprecisão de quantis de
cauda e estatísticas indefinidas de indicadores raros são problemas distintos.
O primeiro não pode ser dispensado com uma regra apenas para caudas.

No código vigente, as classes são ausência, fraude incremental e fraude
extrema. Fabricação e transferência de votos são mecanismos que coexistem
nas classes com fraude, não os rótulos das classes 2 e 3. A ordem parcial
dos pesos já favorece a classe sem fraude; investigar o efeito de acrescentar
uma ordem é uma mudança de modelo, não uma correção automática de código.

O aumento de comprimento sem mudar prioris e as sensibilidades de prioris
devem permanecer braços identificáveis. Propostas informadas pelos resultados
atuais são exploratórias e precisam ser rotuladas assim. Não escolher prioris
por produzirem a conclusão eleitoral desejada.
