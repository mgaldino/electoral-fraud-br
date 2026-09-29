# Fechamento de AR-02

O reparo das quatro chamadas invertidas foi aceito após QA independente por
Socrates e adjudicação da coordenação. O finding AR-02 continua CONFIRMED,
agora resolvido; nenhum novo defeito foi identificado no escopo da interface.

A coordenação conferiu os hashes before/after e os 20 arquivos do manifesto
da revisão, além de ler o diff e os testes. A QA repetiu as quatro chamadas
reais até a fronteira interceptada do amostrador e seus controles negativos.
Seu teste próprio manteve as respostas corretas e trocou só as covariáveis:
Xw e Xa mudaram, como deveriam, demonstrando que comparar apenas respostas
seria insuficiente. Stubs bloquearam a amostragem; não houve compilação JAGS
ou MCMC, nem instalação ou reestimação de fits.

O JSON adjacente vincula os hashes exatos e as identidades independentes.
Essa aceitação não aprova G3 ou G10 e não resolve a pendência concorrente de
integridade G0. Os pareceres iniciais, o candidato e as fontes anteriores
foram preservados sem sobrescrita.
