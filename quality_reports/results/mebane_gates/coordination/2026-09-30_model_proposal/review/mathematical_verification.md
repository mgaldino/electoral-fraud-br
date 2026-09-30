# Derivações independentes para a proposta v1

Vínculo: `proposal_v1.md`, SHA `7fe462ed99561dee68d49fe1c5595845664249060459d018b4d01829fd61153c`. Estas contas são condicionais a parâmetros fixos, salvo indicação em contrário. Não constituem estimação ou identificação de fraude.

## 1. Três operações de normalização

Se `b_z(r|theta)` é a massa-base das contagens e `h_z(a,w,r;theta)` o produto literal das respostas, com zero para probabilidades inválidas e fora do triângulo, defina `c_z(r)=sum_{a,w} h_z(a,w,r)` e `C_z=sum_r b_z(r)c_z(r)`. A distribuição por componente é `b_z(r)h_z/C_z`. Somando a e w, obtemos `P(R=r|z,theta)=b_z(r)c_z(r)/C_z`. Logo o prior de R só é conservado quando c_z(r) é constante no suporte relevante.

A mistura desses componentes normalizados tem marginal de classe pi. Já a normalização global de `pi_z b_z h_z` tem marginal `pi_z C_z/sum_j pi_j C_j`. Normalizar condicionalmente a r, usando `b_z(r) h_z/c_z(r)`, conserva b_z quando todos os c_z relevantes são positivos, mas define outra distribuição. Casos c_z=0 precisam de regra de suporte explícita; não são resolvidos por divisão silenciosa.

No fixture literal com N=2, tau=0,6, nu=0,4, probabilidades das quatro contagens `(0,2;0,3;0,8;0,9)` e pi `(0,6;0,25;0,15)`, obtive C `(0,9808;0,937621366112;0,968597500928)`. A normalização global induz pesos `(0,607824019687016;0,242110516795230;0,150065463517755)`, distintos de pi. A maior mudança na massa conjunta de R do componente 2 é `0,00748656240967721`. A marginal de uma contagem inativa permanece sua binomial: seus fatores integram a um e c_z não depende dela.

A definição de B condiciona em theta. Se alguém normalizasse também sobre theta, mudaria a prior contínua: isso não está autorizado nem proposto no texto. Para o domínio interior usual, R ativo todo zero tem massa-base positiva e A=W=0 fornece massa positiva, garantindo C_z>0; essa observação não torna o kernel original normalizado.

## 2. Contagens e multinomial

Um eleitor tem cinco resultados disjuntos: abstenção não convertida, líder original, abstenção convertida, resíduo transferido e resíduo preservado. Suas probabilidades são `(1-tau)(1-m)`, `tau*nu`, `(1-tau)m`, `tau(1-nu)s` e `tau(1-nu)(1-s)`. Elas são não negativas e somam um. A função geradora observacional de um eleitor é `pA*x + (pL+pM+pS)*y + pO*z`. Para N eleitores, elevar a N e tomar coeficientes produz exatamente a multinomial de A,W,O, para todo N inteiro não negativo.

A fatorização por A decorre de separar a célula A das outras duas. Condicional a A, há N-A unidades distribuídas entre W e O com pesos `pW/(pW+pO)` e `pO/(pW+pO)`. Se o denominador é zero, A=N quase certamente. As marginais são Bin(N,pA) e Bin(N,pW), e `Cov(A,W)=-N*pA*pW`, pois as categorias de um mesmo eleitor são exclusivas.

O produto de binomiais independentes não possui essa exclusividade. Com N=1, tau=nu=0,5 e m=s=0, atribui massa 1/8 a A=W=1. Condicioná-lo ao triângulo também não o torna a multinomial: a probabilidade de A=W=0 torna-se 3/7, enquanto a multinomial dá 1/4.

## 3. Posterior de transferências

Na multinomial de cinco células, observar A e O fixa suas contagens; observar W fixa a soma das três células internas do líder. Ao dividir a massa conjunta pela probabilidade observada, os fatores de A e O cancelam e resta `Multinomial(W; pL/pW,pM/pW,pS/pW)`. Esta é uma identidade da **lei conjunta**, não apenas das esperanças. Ela pressupõe classe e parâmetros condicionados na posterior com os dados completos.

Para classes com probabilidades observadas distintas, `P(Z=z|dados,theta,pi)` é proporcional a `pi_z L_z(dados|theta)`. No fixture N=2,A=0,W=2, tau=0,6,nu=0,4, magnitudes `(0,0)`, `(0,2;0,3)` e `(0,8;0,9)`, pi `(0,6;0,25;0,15)` produz posterior de classe `(0,1749214473;0,2317911632;0,5932873895)`. Usar a prior pi nesse passo daria outra distribuição de M/S.

Condicionalmente, M+S tem lei `Binomial(W,(pM+pS)/pW)`. Isso foi confrontado diretamente com a soma dos microestados, assim como cada par M,S. Para pW=0, apenas W=0 pertence ao suporte; todas as contagens internas são zero. No exemplo da proposta, as médias de M/S condicionadas a W=400 são `74,7663551402` e `100,9345794393`, diferentes das esperanças anteriores aos dados, 80 e 108.

## 4. O que não é identificado

Para qualquer ponto interior do triângulo de probabilidades observadas, `tau0=1-pA` e `nu0=pW/(1-pA)` pertencem a (0,1). Com m=s=0, recuperam pA,pW,pO. Portanto, parâmetros locais livres podem produzir a mesma distribuição de observáveis com diferentes transferências. Exemplo: `(tau,nu,m,s)=(0,7;5/7;0;0)` e `(0,6;0,5;0,25;1/3)` produzem `(pA,pW,pO)=(0,3;0,5;0,2)`, com transferências esperadas zero versus `0,1N+0,1N`.

A transformação necessária depende dos parâmetros de cada seção. Não foi demonstrado que ela conserve a família hierárquica, os efeitos compartilhados ou suas prioris. Assim, não há prova de equivalência marginal hierárquica nem de impossibilidade de informação sob todas as restrições adicionais. Tampouco há prova de que a informação que uma hierarquia acrescente identifique fraude real. Um resíduo agregado que inclua brancos/nulos não informa quanto S veio do adversário.

## 5. Alcance das verificações

Os scripts da QA não são candidatos alternativos de estimação. Executam enumeração finita e identidades condicionais. `proposal_preparation01/protocol.json` foi gravado antes dos novos testes; `proposal_attempt01/freeze.json` fixa seus bytes. O máximo desvio numérico observado, `9,66e-15`, ficou abaixo de 1e-12. Suporte de probabilidades foi verificado sem epsilon. As identidades gerais acima, e não a quantidade de casos testados, sustentam as conclusões matemáticas.
