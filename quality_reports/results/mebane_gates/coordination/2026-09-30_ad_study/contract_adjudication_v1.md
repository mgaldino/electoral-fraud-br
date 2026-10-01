# Adjudicação do contrato A/D, versão 1

O achado AD-CONTRACT-QA-01 foi **confirmado**: a versão 1 não fixava os limiares e a relevância de todos os diagnósticos discretos. A regra de não tratar NA como aprovação estava presente, mas não bastava para decidir sobre diferenças finitas de ocupação entre cadeias.

O reparo é seguro dentro da autorização existente: versionar a tabela de alvos, estatísticas, limiares e ações antes de observar MCMC. Não muda dados, modelo, sementes, iterações ou estimandos. A versão 1 e o parecer permanecem intactos. A versão 2 deve receber revisão independente do delta e os testes executáveis devem comprovar os veredictos para ocupação divergente, NA obrigatório, constante analítica e constante apenas amostral.

Veredicto técnico: **READY_FOR_IMPLEMENTATION**, limitado ao reparo do protocolo. Não libera o piloto da versão 1 nem aprova produção, G3 ou G10. Identidades de D, prioris efetivas de A, inicializações e definições dos funcionais receberam revisão favorável em seu escopo; identificação e convergência continuam sem atestação.

O registro JSON contém a identidade exata do contrato e do parecer, evidência, classificação e limites.
