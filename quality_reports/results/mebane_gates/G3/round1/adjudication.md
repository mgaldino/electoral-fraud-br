# G3 round1: encerramento inconclusivo

A coordenação acolhe o parecer final independente sobre revision3 e encerra
esta rodada como **inconclusiva**, em 30/09/2026. O status não é aprovação de
JAGS, Stan ou inferência eleitoral. Os quatro todos mantêm progresso parcial.

## O que foi verificado

As médias do caso pequeno condicionado concordaram com enumeração exata;
priors, interface e funcionais conjuntos foram conferidos no escopo da rodada.
Os reparos de persistência e forma de diagnósticos foram reproduzidos pela QA.
Não houve MCMC nova neste fechamento.

O finding G3-QA-R2-INPUT-01 permanece historicamente CONFIRMED, mas seu reparo
delimitado foi aceito: sete versões foram reconstruídas por eventos brutos,
com hashes idênticos aos alvos independentes, e ligadas a cinco comandos.
A revisão do suplemento passou 914 verificações documentais. A coordenação
também reexecutou `reconstruct_sources.py verify-seal`, conferindo 42 arquivos
do suplemento e 350 do candidato, sem executar fontes R históricas.

Isso não certifica toda a história computacional. A sequência não permite
reconstruir `test_ar02_interface.R`; essa limitação fica explícita e está fora
dos sete alvos. Não se altera `manifest_complete=false` no parecer original.
O suplemento e este record complementam, sem substituir, os artefatos antigos.

## Por que G3 não passa

- F1: o literal admite estados de massa parental positiva com probabilidade
  inválida. O gerador integral continua não validado.
- F2: mesmo estados com probabilidades binomiais válidas podem produzir
  abstenções mais votos superiores ao eleitorado.
- Nove diagnósticos de ESS de cauda são indefinidos em alvos discretos. Não
  satisfazem o critério congelado, mas também não demonstram automaticamente
  falta de convergência. Um protocolo futuro deve tratar esse problema antes
  da próxima estimação, sem reclassificar a rodada antiga.

Não há engine de produção aprovada. JAGS continua referência literal de
software; o Stan histórico continua uma aproximação não validada como portagem
exata. G4 e G10 não são liberados. A proposta comparativa de 30/09 é uma entrega
separada para escolha de modelo, não mudança do contrato vigente.

O JSON associado contém identidades exatas do candidato, parecer, suplemento
e resultado independente. Seu veredicto documental limitado não deve ser
confundido com o status científico inconclusivo do gate.
