# Preparação independente QA-FIDELIDADE G3

Revisor/goal: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`. Esta preparação precede o recebimento do candidato; não é parecer final nem implementação alternativa. Toda escrita fica em `review/`.

## Derivações da fonte integral

Sejam `x=A/N`, `m=0, iota.m ou chi.m` e `s=0, iota.s ou chi.s`, conforme a mesma classe Z para ambas as respostas. Da expressão literal:

`pW = nu*(1-s)+s + x*((m-s)-nu*(1-s))/(1-m)`.

O coeficiente de x é finito porque a fonte transforma somente o endpoint manufactured em 0.999. O componente inativo pode exceder 1 sem tornar a soma ponderada inválida; isso é uma identidade algébrica, não uma previsão sobre o runtime. Os quatro nós binomiais continuam presentes no grafo e devem ser exercitados.

Com `N=A=R_M=1,R_S=0,tau=nu=0.5`, obtém-se `pA=0.0005` e `pW=499.5`: o evento que conduz ao pai inválido tem massa positiva. Com `Z=1,N=2,A=1,W=2`, `pA=0.5,pW=0.25` e a massa é `1/32`, embora `A+W>N`. São problemas distintos, ambos mantidos no benchmark literal.

Para parâmetros contínuos fixos, a soma sobre os quatro inteiros usa pesos `prod(dbinom(R_b,N,q_b))*pi_Z`, incluindo constantes combinatórias. Zeramento de estados inválidos define somente K. A soma de K em A,W é um diagnóstico, não necessariamente 1. A normalização `K/sum(K)` em estados latentes para A,W fixados deve ser rotulada como condicional do kernel diagnóstico, não como prova da semântica do modelo integral.

As duas contagens inativas somam 1 algebricamente; a redução a um par ativo não prova que o runtime ignore os nós inativos. O produto de misturas independentes para A e W perde a classe compartilhada e é um controle negativo.

Na prior de pi, escrever `U=B/H,V=C/H` dá duas U(0,1) independentes, `pi=(1,U,V)/(1+U+V)`. O jacobiano inverso é `pi1^-3`; a ordem é parcial, permitindo `pi3>pi2`. As seis exponenciais são sobre variâncias, com precisão recíproca. Cada preditor contém o coeficiente fixo `b0` e um efeito cujo centro é `alpha`; o vetor reportado beta não substitui o vetor beta1 usado no produto.

## Checklist final

- Confirmar hash recebido do manifesto, ID real do executor distinto do revisor, contrato estático G3 e aprovações correntes de G2; não usar antigos indicadores pending como estado atual.
- Recalcular SHA-256 e bytes de todos os inputs/code/configuration/outputs declarados. Inspecionar source/readRDS/read.csv/loads/system calls para fechar dependências reais, inclusive scripts encadeados, dados gerados e configuração.
- Conferir que protocolo, sementes, limites, critérios e tolerâncias antecedem resultados. Tentativas fracassadas e timeout continuam no manifesto; qualquer ajuste exige novo path e justificativa.
- Verificar fonte integral inalterada, seis matrizes n por 1, parâmetros efetivos e condicionamento em data versus inits. Ausência de a/w e qualquer modelo auxiliar recebem rótulos distintos.
- Verificar suporte probabilístico e físico separadamente, ativo/inativo, inicialização, atualizações e geração; nunca extrapolar um probe condicionado para o ajuste integral.
- Comparar likelihood e marginais small-N com a enumeração independente. Não chamar K de likelihood normalizada nem tratar tolerância como clamp.
- Verificar Z e contagens do mesmo draw, M e S por unidade, agregação conjunta, empates e margens condicionais com viabilidade. Médias condicionais não substituem quantis da distribuição conjunta.
- Exigir sentinela assimétrica através do wrapper real até os argumentos emitidos para o engine e lista direta, além de controle invertido que falhe.
- Separar execução, concordância numérica, convergência, fidelidade, validade do gerador e inferência. Auditor de geração não satisfaz automaticamente G3-T1.
- Classificar pass/changes_requested/inconclusive conforme o contrato; não liberar G4/G10, não editar ledger, não completar goal antes do parecer final.

## Limites

O protocolo não contém um ajuste posterior de produção nem uma portagem Stan. Os probes usam somente a fonte JAGS integral condicionada. A comparação de marginais do candidato será realizada somente após o hash. A skill `review-r` foi usada para estruturar as verificações; a autorização explícita atual abrange scripts e outputs de QA dentro do escopo exclusivo, sem editar o candidato.
