# Nova rodada: JAGS 20k e D em Stan 2k

Pedido de 1 de outubro de 2026: executar cadeias JAGS maiores e, em paralelo,
adaptar o alvo D para Stan e avaliar 2.000 amostras por cadeia.

Interpretamos 20k/2k como iterações retidas pós-aquecimento, não número de cadeias.
São quatro cadeias em cada ajuste. Mantemos os 143 precincts de D.C. 2010,
o modelo A literal e o modelo D já implementado. Não há nova análise brasileira.

Em JAGS, somente a quantidade pós-aquecimento muda: adaptação 1.000,
aquecimento 5.000, pós 20.000, mesmas sementes/inicializações e parâmetros.
A rodada antiga permanece intacta e inconclusiva; a autorização atual permite
nova rodada, sem reclassificar retroativamente a anterior.

Em Stan, D terá a classe discreta marginalizada e hierarquia não centrada,
com a mesma distribuição-alvo. As quatro cadeias serão executadas serialmente,
como o objeto rjags com quatro cadeias, para não confundir paralelização com
eficiência do algoritmo. Aquecimento 2.000 e pós 2.000 por cadeia. Stan não
recebe uma aproximação do modelo A. Testes de densidade e revisão independente
precedem amostragem; compilar não demonstra equivalência.

O desenvolvimento é paralelo, mas processos intensivos de compilação,
amostragem e diagnóstico não disputarão recursos durante as medidas. Eventual
concorrência observada será registrada, sem ocultá-la ou repetir modelos por isso.

Os limites são 3.600 segundos por geração JAGS, por diagnóstico JAGS e para
o processo de estimação Stan. Os limites do novo `contract.json` prevalecem
sobre o antigo `timing.md`, reutilizado apenas para definir os relógios.
Sem reestimação ou extensão automática; preservar erros e saídas parciais.

Os critérios anteriores de R-hat, ESS e classes continuam vigentes. Acrescentamos
diagnósticos específicos do HMC, incluindo divergências, profundidade de árvore,
energia e parâmetros internos não centrados. As classes raras indefinidas
continuam explicitadas; não serão usadas para ocultar nem para substituir os
diagnósticos dos parâmetros globais. Não se presume que 20k JAGS ou 2k Stan bastem.

Nenhuma instalação ou exclusão está autorizada. A, dados, códigos e outputs
anteriores permanecem preservados. G3, G10, identificação e produção brasileira
não são aprovados automaticamente por esta execução.

Coordenação: implementação Stan em Sol (executor anterior de D), revisão
independente em agente separado e integração pelo coordenador. A recomendação
automática de roteamento era uma heurística não calibrada que não reconheceu o
risco matemático; mantemos Sol com raciocínio xhigh e a checagem independente
já exigida no projeto, sem afirmar benchmark de superioridade entre modelos.

Fontes técnicas consultadas em 01/10/2026: [Stan, variáveis discretas latentes](https://mc-stan.org/docs/stan-users-guide/latent-discrete.html)
e [Stan, diagnósticos e avisos](https://mc-stan.org/learn-stan/diagnostics-warnings.html).
A documentação web atual pode ter versão posterior à instalação; a execução
usa CmdStan 2.37.0 e CmdStanR 0.9.0, verificados localmente, sem atualização.
