---
title: "Contrato matemático do qbl"
subtitle: "G2, round1: candidato para revisão independente"
author: "METODO-PRINCIPAL"
date: "28 de setembro de 2026"
lang: pt-BR
fontsize: 11pt
geometry: margin=25mm
---

# 1. Resultado e alcance

**Não há equivalência integral entre os artigos, o JAGS congelado e o Stan histórico.** O JAGS contém estados de massa positiva em que `p.w` excede 1; o Stan os transforma por `clamp`. O produto de binomiais dos artigos é normalizado no retângulo de contagens, mas atribui probabilidade a combinações eleitoralmente impossíveis. Também diferem a hierarquia de escala, o uso da abstenção observada e a presença de contagens latentes. Estes achados exigem decisão sobre o alvo antes de uma portagem certificada em G3.

Este documento estabelece o que está escrito e implementado, deriva equivalências delimitadas e oferece alternativas **não aprovadas**. Não estima modelos, não modifica produção, não aprova G2 nem incorpora G1. Os testes são do implementador. A rederivação por QA-MATEMATICA, a adjudicação e qualquer aprovação continuam pendentes.

O executor é `01a0eaee-01df-7773-bd63-d321db26a47c`, também identificador do goal nativo. Modelo e esforço efetivos não são expostos pelo runtime. O papel solicitado é METODO-PRINCIPAL, configuração solicitada `inherit/xhigh`.

## 1.1. Fontes e localização

Os caminhos desta seção são relativos à raiz do projeto. Todos os inputs efetivamente usados têm SHA-256 direto no manifesto G2, inclusive quando herdados de G0. A fonte de produção auditada é o snapshot, não arquivos que outro agente possa editar.

* **P22:** `quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf`, Mebane, Ferrari, McAlister e Wu, *Measuring Election Frauds*, 6/3/2022. Foram examinadas a especificação, pp. impressas 3–7 (PDF 5–9), e suas equações. SHA-256: `ad3b1cd473d48540877fb00cdffaaa09df1a21a98e4a2b4fa0a03c227ec50d76`.
* **P23:** `quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf`, Mebane, *Lost Votes and Posterior Multimodality in the eforensics Model*, 2/7/2023. Foram examinadas a especificação, pp. 5–8 (PDF 7–10), a discussão de ambiguidades e votos perdidos, e o exemplo argentino, p. 31 (PDF 33). SHA-256: `615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431`.
* **J:** `quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags`. O teste `source_qbl_exact` compara esse literal com `qbl()` em `ef_models_3017de5.R`, mesmo diretório, commit `3017de537450f97a01872d0157462a68bea348ee`. A linha 1 de J corresponde à linha 985 desse R; os números subsequentes diferem por 984.
* **S:** `quality_reports/results/mebane_gates/G0/round1/final_state/stan/eforensics_qbl.stan`.
* **R-F, R-Z, R-S:** respectivamente `05_eforensics_qbl_fresh_diagnostic.R`, `05_jags_qbl_zone_fe.R` e `05_stan_eforensics_qbl_calibrate.R`, sob `quality_reports/results/mebane_gates/G0/round1/final_state/R/`.
* **JAGS:** manual 4.3.0 de Martyn Plummer, seções de distribuições Normal, Exponential, Binomial e Multivariate Normal. O manual define `dnorm`/`dmnorm` por precisão, `dexp` por taxa e `dbin(p,N)` por probabilidade e tentativas. A cópia pública consultada é do manual primário do autor, hospedada na [Universidade de Edimburgo](https://webhomes.maths.ed.ac.uk/~swood34/TOI/jags_user_manual.pdf); não se afirma que a versão instalada seja 4.3.0. G0 identifica JAGS 4.3.2.

A extração textual das duas fontes está na rodada. As páginas com a especificação foram também renderizadas e inspecionadas. Há uma omissão tipográfica visível em P23, equação (4d): falta o `k` antes do sinal `+`. P22 (2d) imprime `k+`, e J/S implementam `k+`. Não se apresenta a fórmula corrigida como transcrição literal de P23.

A nota lateral de denominadores foi preservada e congelada como contexto separado em `sources/denominadores_contexto.md`. A afirmação sobre votos em branco foi conferida diretamente em P23, p. 31; a codificação foi conferida em R-F/R-S. Não foram herdadas instruções da nota, nem revalidados seus totais, nem consultada a fonte turca por ela mencionada. Sua existência não constitui aprovação G0.

# 2. Dados, unidades e alvo escrito nos artigos

Uma unidade $i$ é uma agregação eleitoral em um turno. $N_i$ é o número inteiro de eleitores aptos, $V_i$ o comparecimento codificado, $A_i=N_i-V_i$ as abstenções codificadas, $W_i$ os votos no líder e $O_i=V_i-W_i$ o resíduo. Exige-se fisicamente

$$N_i\geq1,\qquad A_i,W_i\in\{0,\ldots,N_i\},\qquad A_i+W_i\leq N_i.\tag{G2.1}$$

Escreva $q_i=A_i/N_i$. A escolha de líder é fixa para a análise; não se escolhe automaticamente o vencedor de cada seção. Nos runners de Brasília auditados, líder é Lula, $N$ vem de `QT_APTOS`, A é N menos `QT_COMPARECIMENTO` e $W$ soma votos do código 13; logo, o resíduo inclui o outro candidato, brancos e nulos. R-F verifica $N>0$, mas não todas as condições (G2.1); R-S verifica os limites individuais, não $A+W\leq N$. Esta é inspeção de código, não certificação G1 dos dados.

P22/P23 definem $\tau_i\in(0,1)$ como participação verdadeira e $\nu_i\in(0,1)$ como escolha do líder entre participantes. $Z_i\in\{1,2,3\}$ indica sem fraude, incremental e extrema. Para uma classe ativa, $m_i$ representa a fração manufactured de abstenções verdadeiras e $s_i$ a fração stolen do resíduo verdadeiro. Para $Z=1$, ponha $m=s=0$. A contabilidade esperada dos artigos é

$$p_A=(1-\tau)(1-m),\qquad p_W^P=\nu\tau+m(1-\tau)+s\tau(1-\nu).\tag{G2.2}$$

Ela implica $1-p_A-p_W^P=(1-s)\tau(1-\nu)\geq0$. A likelihood escrita em P22, p. 6, e explicitamente em P23 (3), é

$$L^P_i=B_{N_i}(A_i;p_A) B_{N_i}(W_i;p_W^P),\quad
B_N(x;p)={N\choose x}p^x(1-p)^{N-x}.\tag{G2.3}$$

As binomiais têm $N$ tentativas, não $N-A$. A mistura usa **a mesma classe** para as duas respostas: $\sum_z\pi_z B_N(A;p_{A,z})B_N(W;p_{W,z})$. Produto de duas misturas separadas permitiria classes distintas e seria outro modelo.

## 2.1. Bernoulli, binomial e restrição física

Dois passos Bernoulli por eleitor, com categorias mutuamente exclusivas, produzem uma multinomial para $(A,W,O)$, não duas binomiais independentes. A equação (G2.3) tem massa total 1 em $\{0,\ldots,N\}^2$, mas não no triângulo (G2.1). Exemplo mínimo: $N=1,\tau=\nu=0,5,m=s=0$; (G2.3) atribui $0,5\times0,25=0,125$ ao evento impossível $A=W=1$. A massa no suporte físico é 0,875.

Portanto, tratar (G2.3) como produto de marginais/composite likelihood é uma escolha distinta de um gerador conjunto de votos fisicamente coerente. Se se condicionar o produto a $A+W\leq N$, é necessário dividir por uma constante que depende dos parâmetros. Uma alternativa generativa ilustrativa é

$$A\sim\mathrm{Bin}(N,p_A),\quad
W\mid A\sim\mathrm{Bin}\left(N-A,\frac{p_W^P}{1-p_A}\right),\tag{G2.4}$$

equivalente à multinomial com probabilidades $(p_A,p_W^P,1-p_A-p_W^P)$. Em caso degenerado $p_A=1$, $A=N,W=0$. Esta alternativa não é a likelihood de P23 nem de J/S e **não está autorizada como alvo de produção**.

# 3. Priors e hierarquia efetivas

## 3.1. Mistura: ordenação parcial, não total

P22/P23 (1) e J:13–18 especificam $H\sim U(0,1)$, $B,C\mid H\overset{ind}{\sim}U(0,H)$ e $\pi=(H,B,C)/(H+B+C)$. Com $U=B/H,T=C/H$, a densidade conjunta original $H^{-2}$ e o jacobiano $H^2$ se cancelam. Logo $H,U,T$ são independentes $U(0,1)$ e

$$\pi=\frac{(1,U,T)}{1+U+T}.\tag{G2.5}$$

Isso prova que remover $H$ é exato para a posterior dos parâmetros restantes: $H$ não entra na likelihood. S:134–150 implementa precisamente esta redução. O ponto $H=0$ tem probabilidade zero; a transformação é definida quase certamente, não nesse ponto.

Tomando $(\pi_2,\pi_3)$ como coordenadas do simplex, $U=\pi_2/\pi_1,T=\pi_3/\pi_1$, $\pi_1=1-\pi_2-\pi_3$. O determinante é $\pi_1^{-3}$, portanto

$$f(\pi_2,\pi_3)=\pi_1^{-3}\,
\mathbf1\{\pi_2,\pi_3\geq0,\ \pi_1\geq\max(\pi_2,\pi_3)\}.\tag{G2.6}$$

A integral é 1: para $p=\pi_1\in[1/3,1/2]$, a largura admissível de $\pi_2$ é $3p-1$; para $p\in[1/2,1]$, é $1-p$. Integra-se largura/$p^3$ nesses intervalos. Resultados: $E\pi_1=3\log3-4\log2=0,52324814$, $E\pi_2=E\pi_3=(1-E\pi_1)/2$ e $P(\pi_1>1/2)=1/2$.

Não há restrição $\pi_2\geq\pi_3$: ela ocorre com probabilidade 1/2. Ordenar as três classes acrescentaria uma restrição e um fator 2 à densidade na região menor. Uma Dirichlet(1,1,1) condicionada a $\pi_1$ ser maior tem densidade constante 6 na região, não $\pi_1^{-3}$. Esses três priors não são intercambiáveis. A restrição de mistura tampouco prova identificação das classes pelo dado.

## 3.2. Precisão, variância e desvio-padrão

Para cada bloco $b\in\{\tau,\nu,\iota_M,\iota_S,\chi_M,\chi_S\}$, J:86–112,134–139 usa

$$v_b\sim\mathrm{Exp}(\text{taxa}=5),\quad
\alpha_b\sim N(0,\text{variância}=1),\quad
h_{ib}\mid\alpha_b,v_b\sim N(\alpha_b,\text{variância}=v_b).\tag{G2.7}$$

Aqui $v_b$ são `tb,nb,imb,isb,cmb,csb`. `dnorm(alpha,1/v)` recebe **precisão** $1/v$, logo o desvio-padrão é $\sqrt v$. `dexp(5)` tem densidade $5e^{-5v}$ para $v>0$: média 0,2 e variância 0,04. O nome `*.beta` usado para precisão não é parâmetro de distribuição Beta. A frase de momentos da Exponencial no manual 4.3.0, p. 45, contém erro tipográfico na variância; aqui ela é rederivada da densidade, $\mathrm{Var}(v)=1/5^2$, não copiada como $1/5$.

Para $\sigma=\sqrt v$ e $\lambda=1/v$, os jacobianos dão

$$f_\sigma(s)=10s e^{-5s^2}\ (s>0),\qquad
f_\lambda(l)=5l^{-2}e^{-5/l}\ (l>0).\tag{G2.8}$$

$E\sigma=\sqrt\pi/(2\sqrt5)=0,39633273$, $E\sigma^2=0,2$, e $E\lambda$ diverge. Condicional em $\alpha$, integrar $v$ dá resíduo Laplace: $f(h-\alpha)=\sqrt{5/2}\exp[-\sqrt{10}|h-\alpha|]$, variância 0,2. A escala é compartilhada pelo bloco; integrar $v$ não torna os resíduos independentes marginalmente.

**Divergência material P/J:** P22 p. 6 e P23 p. 7 chamam explicitamente $\sigma$ de desvio-padrão e lhe atribuem Exp(5). Sob essa leitura, $E\sigma^2=2/25=0,08$, diferente de 0,2. Não se pode sanar isso mudando apenas o nome do parâmetro. S:120–125,171–183 usa $\alpha+\sqrt v\,z$, $z\sim N(0,1)$ e $v\sim\mathrm{Exp}(5)$, equivalente a J nesse bloco. A igualdade de densidade inclui $dh/dz=\sqrt v$; parametrizar $z$ e dar-lhe prior Normal padrão já realiza essa mudança de variável, sem acrescentar jacobiano outra vez.

## 3.3. Intercepto pequeno, alpha e covariáveis

J:22–79 define matrizes chamadas `sigma.beta.*`, mas as passa a `dmnorm`, que usa **precisão**, não `dmnorm.vcov`. A primeira diagonal é 10000; as demais são 1. Assim o vetor efetivamente usado, `beta.*1`, tem intercepto $b_{0b}\sim N(0,10^{-4})$ e inclinações $\beta_{jb}\sim N(0,1)$ independentes, usando variâncias nesta notação. O desvio-padrão do intercepto é 0,01, não 100 nem $10^{-4}$.

O preditor de J é

$$\eta_{ib}=b_{0b}+x_{i,-0}'\beta_b+\alpha_b+\sqrt{v_b}z_{ib}.\tag{G2.9}$$

J:24 e linhas análogas criam um vetor de apresentação `beta.*`, substituindo seu primeiro componente por `alpha`. **Esse vetor não é usado no produto interno**, que usa `beta.*1` (J:127–132). Portanto, monitorar `beta.tau` igual a `tau.alpha` não prova que $b_0=0$ nem que ele foi integrado. Na likelihood, $b_0$ e $\alpha$ aparecem apenas pela soma, uma direção fracamente identificada pelo prior.

A redução exata dessa soma, quando só interessa o preditor, seria $\widetilde\alpha=\alpha+b_0\sim N(0,\text{variância}=1{,}0001)$, não $N(0,1)$. S omite $b_0$ e mantém $\alpha\sim N(0,1)$. A diferença é pequena no prior, mas não é identidade; inferência sobre o $\alpha$ original exigiria ainda reconstruí-lo condicionalmente. Isso vale também com covariáveis e primeira coluna constante 1. Para desenhos sem intercepto na primeira coluna, a redução acima não vale.

P22/P23 escrevem $N(0,1/10000)$ para **todos** os coeficientes. A convenção do segundo argumento não é explicitada para essa frase; nas linhas seguintes os autores usam explicitamente desvio-padrão na hierarquia. Não é justificável resolver a ambiguidade por conveniência. Com qualquer leitura uniforme (variância, desvio-padrão ou precisão), a frase não descreve a diagonal heterogênea `(10000,1,...)` efetiva de J. A interpretação de trabalho de J está definida sem ambiguidade pelo código/manual.

R-Z constrói dummies de zona com intercepto e referência no primeiro nível do fator, **apenas nos quatro blocos de magnitude**; participação e escolha continuam intercept-only. R-S usa o mesmo tipo de desenho quando a opção geográfica está ativa, retirando o intercepto. Esses efeitos são fixos com priors independentes, não uma hierarquia espacial de zonas nem seis efeitos geográficos automaticamente iguais. O índice `j` dos efeitos $h_j$ é a seção, apesar do comentário “individual” em J.

Exemplo de regularização geográfica: ignorando o resíduo específico da seção, a variância da localização na zona de referência é 1,0001 em J; em uma zona não referência, 2,0001. Covariâncias entre localidades dependem das dummies compartilhadas. Reescolher a referência e manter os mesmos priors independentes pode mudar o prior sobre contrastes: contraste com a referência tem variância 1, entre duas não referências tem variância 2. Não se deve chamar recodificação geográfica de invariância automática.

## 3.4. Transformações logísticas e contagens

Se $g(x)=1/(1+e^{-x})$, J:142–149 define $\tau=g(\eta_\tau)$, $\nu=g(\eta_\nu)$, $\mu_{I,l}=k g(\eta_{I,l})$ e $\mu_{E,l}=k+(1-k)g(\eta_{E,l})$, $l\in\{M,S\}$, $k=0,7$. Para $\eta\sim N(\ell,v)$, condicional em coeficientes e escala, a densidade de $p=g(\eta)$ é

$$\frac{\phi(\operatorname{logit}p;\ell,\sqrt v)}{p(1-p)}.\tag{G2.10}$$

As densidades transformadas de $u=k g(\eta)$ e $e=k+(1-k)g(\eta)$ usam, respectivamente, jacobianos $k/[u(k-u)]$ e $(1-k)/[(e-k)(1-e)]$, aplicados às Normais nos argumentos $\log[u/(k-u)]$ e $\log[(e-k)/(1-e)]$. As constantes $k$ e $1-k$ não podem ser omitidas quando se muda a variável de integração. Nenhum fator manual é necessário quando se mantém $\eta$ como parâmetro e as probabilidades como transformações determinísticas.

**J acrescenta**, J:157–177, quatro contagens condicionalmente independentes:

$$R_{I,M}\sim\mathrm{Bin}(N,\mu_{I,M}),\quad R_{I,S}\sim\mathrm{Bin}(N,\mu_{I,S}),\quad
R_{E,M}\sim\mathrm{Bin}(N,\mu_{E,M}),\quad R_{E,S}\sim\mathrm{Bin}(N,\mu_{E,S}).\tag{G2.11}$$

Estas contagens têm denominador **N aptos**, não abstenções verdadeiras nem votos do adversário; não são diretamente números realizados de votos manufactured/stolen. Para a classe ativa, $m=g_N(R_M)$, $s=R_S/N$, com $g_N(r)=r/N$ se $r<N$ e $g_N(N)=0,999$. Todos os valores $r=0,\ldots,N$ têm massa positiva quando $0<\mu<1$. Assim, $k$ separa **probabilidades/médias das binomiais**, não o suporte das frações realizadas: uma classe incremental pode gerar fração 1 (ou 0,999), e a extrema pode gerar 0.

A substituição de 1 por 0,999 é transformação de um átomo, não truncamento renormalizado. Exatamente,

$$E[m]=\mu-0,001\mu^N,\quad
E[m^2]=\mu^2+\frac{\mu(1-\mu)}N-0,001999\mu^N.\tag{G2.12}$$

Para $N=1000$, $r=999$ e $r=1000$ se acumulam no mesmo valor; para $N>1000$, a transformação decresce no último passo. Não há correção análoga em $s$, que pode valer 1. Nenhuma contagem latente é truncada aos limiares $k$. As linhas de `N.tau` e `N.nu` são comentários, não nós ativos.

S:139–144 usa diretamente as probabilidades logísticas como magnitudes contínuas e não contém (G2.11). Portanto o Stan aproxima J por substituição, não por marginalização dessas contagens. Nos artigos P22/P23 as magnitudes são as transformações contínuas; (G2.11) não aparece nas especificações examinadas.

# 4. Abstenção observada, suporte e clamp

J:187–197 usa $p_A$ de (G2.2), mas, para a classe ativa,

$$p_W^J=\nu\frac{1-s}{1-m}(1-m-q)+q\frac{m-s}{1-m}+s
=c+\frac{q}{1-m}(m-c),\quad c=\nu+(1-\nu)s.\tag{G2.13}$$

No componente sem fraude, $p_W^J=\nu(1-q)$. A fatorização efetiva é $B_N(A;p_A)B_N(W;p_W^J(A/N))$, isto é, a segunda resposta depende da primeira observada. Substituir $q=(1-\tau)(1-m)$ em (G2.13) recupera (G2.2); **isso é uma identidade na média condicional de A, não igualdade entre likelihoods**. Exemplo: $\tau=0,6,\nu=0,4,m=0,2,s=0,3$ dão $p_W^P=0,428$. Com $q=0,1$, J dá 0,5325; só com $q=0,32$ coincide.

Outra forma elucidativa é $t^*=1-q/(1-m)$ e $p_W^J=\nu t^*+m(1-t^*)+s t^*(1-\nu)$. Se $q>1-m$, então $t^*<0$: deixa de existir uma interpretação física como participação verdadeira. O $\tau$ latente de J continua sendo usado em $p_A$; $t^*$ não o substitui em todo o modelo.

## 4.1. Região válida e contraexemplos mínimos

Para $0\leq q,\nu,s\leq1$ e $0\leq m<1$, $p_W^J$ é afim em $q$. Seus valores nos extremos são $c\geq0$ e $m(1-c)/(1-m)\geq0$. Portanto não pode ser negativo em aritmética exata nesse domínio. O risco principal é exceder 1 e/ou a restrição física. Além disso,

$$q+p_W^J=c+(1-c)\frac{q}{1-m}.\tag{G2.14}$$

Se $q\leq1-m$, $p_W^J\leq1-q\leq1$. Para $c<1$, essa condição é também necessária para $q+p_W^J\leq1$. Se $c=1$, há igualdade em (G2.14), mesmo quando a reconstrução $t^*$ é negativa; por isso as duas noções de suporte devem permanecer distintas. Para todos os $q\in[0,1]$, $p_W^J\leq1$ se e somente se $m(2-c)\leq1$. Estas propriedades não são garantidas pelos priors de J.

**F1, suporte probabilístico:** $N=A=R_M=1$, $R_S=0$, $\nu=\tau=0,5$. J transforma $m$ em 0,999 e produz $p_W^J=499,5$. O evento $A=1$ tem probabilidade 0,0005 e ambas as contagens latentes têm massa positiva. A deficiência persiste em uma vizinhança aberta dos parâmetros, não depende de um ponto de prior contínua com massa zero. Não existe distribuição Binomial com essa probabilidade. O código não especifica `T(...)`, normalizador ou política estatística para esse caso. Não foi executado JAGS nesta auditoria; erro, rejeição e detalhes de compilação não são confundidos com uma distribuição normalizada.

**F2, suporte físico:** mesmo no componente sem fraude, $N=2,A=1,\nu=0,5$ dá $W\mid A\sim\mathrm{Bin}(2,0,25)$, que admite $W=2$. Com $\tau=0,5$, esse evento impossível tem massa $0,5\times0,25^2=0,03125$. A massa física conjunta é 0,96875. Uma Binomial$(N-A,\nu)$ tem a mesma média condicional, mas outra variância e outro suporte. A diferença de variância é $(N-A)\nu^2A/N$.

## 4.2. Normalização: três operações distintas

Para testar algebricamente a soma finita, define-se **apenas para diagnóstico** $K(A,W;\theta)$ como o produto das binomiais quando seus parâmetros são válidos, e zero nos demais estados. Isso não presume que o JAGS execute exatamente essa política. Se se quiser transformar esse kernel em uma distribuição de dados, é necessário escolher domínio $D$ e usar

$$C_D(\theta)=\sum_{(A,W)\in D}K(A,W;\theta),\qquad
P_D(A,W\mid\theta)=K(A,W;\theta)/C_D(\theta).\tag{G2.15}$$

$D$ pode ser o retângulo ou o suporte físico; as escolhas produzem distribuições distintas. No exemplo F1, com $m,s,\nu$ fixos, $C_{\square}=0,9995$ quando $\tau=0,5$, mas 0,9998 quando $\tau=0,8$. Portanto descartar parâmetros inválidos não equivale a ignorar uma constante de likelihood.

Restringir latentes condicionalmente ao A observado também é outra operação: ela exige normalizar as probabilidades latentes no subconjunto admitido, com um fator dependente de A e dos hiperparâmetros. Condicionar o produto ao domínio físico exige (G2.15). Multiplicar uma prior por indicadores e renormalizar globalmente a posterior pode definir um kernel bayesiano útil, mas não demonstra que cada likelihood de dados está normalizada. Nenhum desses reparos está implícito na notação `dbin` de J.

## 4.3. O que o Stan altera

S:27–44 aplica $\operatorname{clamp}(p)=\min(1-\epsilon,\max(\epsilon,p))$, $\epsilon=10^{-9}$, e troca o denominador $1-m$ por $\max(\epsilon,1-m)$. S:188–193 também limita $p_A$ e o componente sem fraude. Isso é uma mudança de alvo, não só prevenção de arredondamento: com valores contínuos admissíveis na classe incremental, $q=0,9,\nu=0,1,m=0,6,s=0,05$, a expressão bruta vale 1,16875, mas o Stan usa $1-10^{-9}$.

O clamp remove probabilidades exatamente 0/1, dá massa positiva a certos eventos antes impossíveis e cria regiões planas e pontos não diferenciáveis nos limites. A proteção do denominador altera a álgebra quando $1-m<\epsilon$; as identidades de (G2.13–14) referem-se ao denominador original. Na classe incremental com $k=0,7$ o piso do denominador não é acionado; na extrema pode ser. Mesmo a logística de argumento finito pode arredondar para 1 em ponto flutuante.

O Stan define um modelo condicional normalizado **no retângulo**: para cada A as probabilidades limitadas pertencem a $(0,1)$, $\sum_W B_N(W;p_W(A))=1$, e a soma em A também é 1. Isso não sana $A+W>N$, não recupera J nem (G2.3), e não aprova a interpretação eleitoral. As fronteiras $k=0,1$ admitidas na declaração de dados de S degeneram componentes; o runner auditado fornece 0,7. Um contrato de uso deveria fixar esse valor ou aprovar explicitamente outra especificação.

# 5. Marginalização exata e custo

Fixe todos os parâmetros contínuos por unidade, incluindo os seis efeitos hierárquicos, $\pi$ e as quatro probabilidades latentes. A dificuldade discreta não exige enumerar sempre quatro contagens conjuntamente. Dado $Z=2$, apenas $(R_{I,M},R_{I,S})$ afeta o kernel; o par extremo integra a 1. Para $Z=3$, ocorre o inverso; para $Z=1$, todos integram a 1. Defina

$$L_z=\sum_{r=0}^N\sum_{t=0}^N B_N(r;\mu_{z,M})B_N(t;\mu_{z,S})
K(A,W;\tau,\nu,g_N(r),t/N),\quad z=2,3.\tag{G2.16}$$

Então, para a política explícita de kernel escolhida,

$$L=\pi_1 K(A,W;\tau,\nu,0,0)+\pi_2L_2+\pi_3L_3.\tag{G2.17}$$

A fatorização é uma igualdade de somas finitas, não uma aproximação. Os testes com $N=1,2,3$, todos os 29 pares $(A,W)$, comparam (G2.17) à enumeração de quatro contagens e classe, incluindo as fronteiras. Ela é exata para o **kernel rejeita-inválidos especificado no teste**, não uma certificação da semântica JAGS para pais inválidos. Como todas as expressões de classes não ativas permanecem finitas após 0,999, não se acrescentou indevidamente uma restrição de suporte a classes inativas.

O algoritmo direto usa $1+2(N+1)^2$ avaliações de kernel por unidade, contra $3(N+1)^4$ na enumeração ingênua. O custo total de likelihood é $O(\sum_i N_i^2)$; implementação com acumulação pode usar memória $O(1)$ além de pesos, ou $O(N)$ ao precomputá-los. Isto é custo de uma soma condicional: os parâmetros contínuos ainda precisam ser integrados/estimados, e diferenciação automática pode ter custo de memória adicional.

Por exemplo, $N_i=300$ em 6748 unidades requer 1.222.757.844 avaliações nessa implementação direta **por avaliação completa da likelihood**. É contagem de operações, não benchmark nem prova de inviabilidade. G2 não fez medição de HMC, geração de código eficiente, FFT, recorrências ou implementação nacional. O comentário de S que chama a soma de “intractable” não substitui uma análise de custo.

Se se escolher normalizar o kernel rejeita-inválidos, o par ativo também permite

$$C_{D,z}=\sum_{r,t,A} B_N(r;\mu_M)B_N(t;\mu_S)B_N(A;p_A)
\mathbf1_{[0,1]}(p_W^J)H_D(A,p_W^J),\tag{G2.18}$$

com $H_\square=1$ e $H_{\triangle}=P[\mathrm{Bin}(N,p_W^J)\leq N-A]$. Somar W por sua CDF evita uma quarta soma. A implementação direta deste normalizador é $O(N^3)$; não se afirma que seja um limite inferior ótimo. O normalizador da mistura é $\sum_z\pi_z C_{D,z}$. Normalizar cada componente separadamente preservando os mesmos $\pi$ constitui outra escolha, diferente de normalizar a mistura inteira. Os testes conferem a fórmula com enumeração explícita.

## 5.1. Por que substituir pela média não é integrar

Os fatores $\binom Nr$ e $\binom Nt$ variam com os índices somados e não podem ser descartados. Por exemplo, para $N=2,\mu=0,5$, a soma das massas sem os coeficientes binomiais é 0,75, não 1. Já $\binom NA\binom NW$ é comum às classes e aos latentes para dados fixos: pode ser fatorado em razões posteriores, mas deve permanecer para probabilidades preditivas e somas em A/W.

Em geral $E[K(R_M/N,R_S/N)]\neq K(E[R_M/N],E[R_S/N])$. Caso reproduzível: $N=2,A=W=1,\tau=0,6,\nu=0,4,\mu_M=0,2,\mu_S=0,3$. A soma exata do kernel definido acima é 0,171900319424; a substituição por $(0,2,0,3)$ dá 0,19600864. O clamp e a correção 0,999 são diferenças adicionais.

Para uma função suave $h$ em domínio afastado de $m=1$ e das fronteiras, uma expansão de Taylor pode controlar erros em termos da Hessiana e de $\mu(1-\mu)/N$. Isso **não** estabelece automaticamente erro $O(1/N)$ para a likelihood eleitoral: sua curvatura também depende de N, e as fronteiras inválidas/clamp quebram as hipóteses uniformes. N grande e médias próximas não certificam essa aproximação. Qualquer aproximação futura precisará fixar alvo, domínio e tolerâncias antes dos testes.

# 6. Estimandos, classificação e margem

Em um draw conjunto $d$, com classe e parâmetros latentes definidos pelo alvo escolhido, as quantidades dos artigos são

$$M_i^{(d)}=N_i m_{i,Z_i^{(d)}}^{(d)}(1-\tau_i^{(d)}),\qquad
S_i^{(d)}=N_i s_{i,Z_i^{(d)}}^{(d)}\tau_i^{(d)}(1-\nu_i^{(d)}),\tag{G2.19}$$

zero em $Z=1$. $M_i$ são manufactured esperados, $S_i$ stolen esperados, $F_{t,i}=M_i$, $F_{w,i}=M_i+S_i$. São intensidades/contagens esperadas, possivelmente fracionárias, não uma reconstrução observada de cédulas. As contagens auxiliares (G2.11) não são esses valores. Uma distribuição de números inteiros realmente transferidos precisaria de um mecanismo gerador adicional; não deve ser inventada no pós-processamento.

É necessário somar **no mesmo draw**: $M^{(d)}=\sum_i M_i^{(d)}$, $S^{(d)}=\sum_i S_i^{(d)}$, $F_w^{(d)}=M^{(d)}+S^{(d)}$. Calcular quantis depois preserva dependências. Somar quantis por seção ou multiplicar médias de parâmetros não produz o quantil/esperança do total em geral. O teste usa duas unidades perfeitamente anticorrelacionadas cujos totais sempre valem 100.

Com classes marginalizadas, as responsabilidades são $r_{iz}(\theta)=P(Z_i=z\mid A_i,W_i,\theta)$, obtidas pelos pesos de (G2.17) com normalização apropriada ao alvo. S:228–265 soma $r_{i2}g_{i2}(\theta)+r_{i3}g_{i3}(\theta)$. Assim `Ft`, `Fw` e as contagens de unidades do Stan são **esperanças condicionais às magnitudes contínuas daquele draw**, não sorteios das classes nem a distribuição completa de (G2.19).

A esperança posterior dessas quantidades pode ser estimada por Rao–Blackwellização. Seus quantis entre draws não são, porém, quantis do total com Z incerto. Pela variância total, falta $E[\mathrm{Var}(F\mid\theta,D)]$. Exemplo: uma unidade com $P(Z=2\mid\theta,D)=0,25$ e quantidade 100 nessa classe tem média 25 e variância condicional 1875; guardar só 25 elimina essa incerteza. Para totais completos, pode-se amostrar a classe condicional e, no alvo discreto, o par de contagens condicional compatível, ou integrar suas distribuições conjuntas. Isto é definição, não implementação G3.

P22 p. 7 e P23 p. 8 classificam unidades pelo maior número de draws em cada classe. Isso define $\widetilde Z_i=\arg\max_z P(Z_i=z\mid D)$, com desempate a especificar. $\sum_i\mathbf1(\widetilde Z_i\neq1)$, $\sum_i P(Z_i\neq1\mid D)$ e $\sum_i\mathbf1(Z_i^{(d)}\neq1)$ são três objetos diferentes. Nenhum é uma contagem observada de fraudes comprovadas.

Os runners históricos fresh_v2 monitoram hiperparâmetros, não os quatro pares completos de magnitude por unidade; zoneFE acrescenta Z, `mu.tau` e `mu.nu`, mas não as frações latentes necessárias a (G2.19). Não é possível reconstruir exatamente todos esses totais a partir apenas dos monitores declarados, sem informação adicional. Esta constatação não autoriza nova estimação.

## 6.1. Origem de stolen e efeito sobre o segundo colocado

Seja $D_{obs}=W_{obs}-R_{obs}$ a margem observada sobre o segundo colocado fixado. Seja $S_R$ a parte de S proveniente desse candidato. Sob um contrafactual que remove M e devolve os votos S a suas origens, sem reações estratégicas nem votos perdidos adicionais,

$$W_0=W_{obs}-M-S,\quad R_0=R_{obs}+S_R,\quad
D_0=D_{obs}-M-S-S_R.\tag{G2.20}$$

O modelo binário não identifica $S_R$ quando o resíduo contém múltiplas alternativas ou votos inválidos. Sem informação adicional, apenas $0\leq S_R\leq S$, produzindo

$$D_{obs}-M-2S\leq D_0\leq D_{obs}-M-S.\tag{G2.21}$$

Esses limites são aritméticos condicionais à validade do mecanismo e à viabilidade dos totais; não são intervalos de confiança nem identificação de fraude intencional. Restrições adicionais de origem/capacidade podem estreitá-los. Se uma hipótese substantiva definir $S_R=\rho S$, deve-se declarar $\rho\in[0,1]$, sua fonte e sensibilidade. Apenas com duas alternativas válidas e hipótese de que todo S veio do adversário se justifica $\rho=1$. Incluir brancos/nulos em O invalida esse automatismo, mesmo no segundo turno brasileiro.

Exemplo: $N=100,\tau=0,6,\nu=0,5,m=0,2,s=0,1$ dá $M=8,S=3$. Para margem observada 20, a margem contrafactual fica entre 6 e 9. O indicador $F_w/(D_{obs}+1)$ usado nos artigos mede magnitude relativa; não é a redução da margem, não determina troca de vencedor e o `+1` é regularização de denominador, não uma identidade eleitoral. Com vários candidatos, devolver votos também pode mudar quem é o segundo colocado.

Se (G2.19) produzir $M+S>W_{obs}$ ou outras impossibilidades de reconstrução, (G2.20) não é uma contagem viável de votos daquela amostra. Como (G2.19) são quantidades esperadas de um modelo probabilístico, não estão automaticamente limitadas pelos votos realizados observados. Não fazer clipping posterior para esconder essa diferença; verificar o alvo e explicitar o limite interpretativo.

## 6.2. Identificação, convergência e interpretação

São perguntas separadas: a distribuição está definida e normalizada? Os dados distinguem parâmetros/mecanismos? O algoritmo explorou essa posterior? O parâmetro representa manipulação intencional no caso substantivo? Bom R-hat responde só parcialmente à terceira pergunta. Prior, covariáveis omitidas, comportamento estratégico e votos perdidos podem afetar identificação/interpretação mesmo com convergência perfeita.

Uma magnitude incremental com preditor zero vale 0,35; extrema vale 0,85. Um `alpha` negativo desloca essas médias, mas não torna a magnitude zero, não informa sozinho Z e não prova ausência de fraude. P23 discute multimodalidade como possível sintoma de má especificação, inclusive votos perdidos, mas também reconhece outras causas. Não se deduz de multimodalidade um mecanismo causal único, nem se substituem diagnósticos MCMC por um rótulo substantivo.

# 7. Histórico de execução e hipótese do usuário

A hipótese “JAGS rodou direito, então não acho que seja prioris; HMC deveria ser melhor” permanece hipótese, não resultado. HMC é também MCMC; não fornece dominância universal sobre outros samplers, especialmente com misturas, multimodalidade e alvos diferentes.

O resumo fresh_v2, congelado por hash em G0 e copiado sem alteração para esta rodada, registra término em 11/4/2026, 1921,9 s (32,03 min), 6748 seções, quatro cadeias, adaptação 1500, burn-in 5000 e 5000 draws por cadeia. G0 recarregou o fit e recalculou R-hat clássico: `pi[2]` 1,2468 e `iota.s.alpha` 1,7138. O resumo também reporta `iota.m.alpha` aproximadamente 4,170. O resumo zoneFE registra `pi[2]` 4,615 e `iota.s.alpha` 13,506. Nesta rodada os fits não foram recarregados; estes são resultados históricos inspecionados, com a checagem G0 distinguida da inspeção G2.

O Stan n2000 registra 541,7433 s de sampling/warmup e 9,62 s de compilação, duas cadeias, warmup 500, amostragem 250, `rhat_max=1,2294` e `ess_bulk_min=8,2398`. Amostra, número de iterações, número de cadeias e alvo diferem de fresh_v2. Não há comparação controlada de desempenho nem evidência para excluir priors como fator. O runner seleciona as primeiras `n_keep` linhas, não uma amostra aleatória; esses timings não são extrapolação nacional validada. Não foi demonstrado nesta auditoria que todo detalhe da versão final do snapshot Stan seja idêntico ao binário que produziu cada fit histórico; o log identifica explicitamente sua aproximação.

# 8. Mapa fonte, equação e implementação

Tabela 1. Mapa completo dos blocos executáveis de J e das partes correspondentes de S. Números são linhas dos snapshots definidos na seção 1.1. Blocos repetidos são listados conjuntamente; comentários inativos não constituem especificação.

| Parte | Fonte escrita | J | S | Resultado |
|:--|:--|:--|:--|:--|
| Limiar $k$ | P22 (2c–d), P23 (4c–d) | 7 | 53, 139–144; R-S fixa 0,7 | Mesma constante no runner; P23 omite `k` em (4d) |
| Prior de mistura | P22/P23 (1) | 13–18 | 74–78, 134–150 | Redução exata (G2.5–6); ordenação parcial |
| Vetores reportados e matrizes | P22 p. 6; P23 p. 7 | 22–68 | 107–113, 162–169 | `beta.*` reportado difere de `beta.*1` usado |
| Normais multivariadas | Mesmas páginas | 74–79 | 155–169 | Precisão `(10000,1,...)`; texto do paper não a descreve |
| Exp e inversos | Mesmas páginas | 86–91, 100–105 | 90–97, 171–176, 215–220 | J/S: variância Exp; paper: desvio-padrão Exp |
| Médias hierárquicas | Mesmas páginas | 107–112 | 83–88, 155–160 | Normal padrão; omitido $b_0$ em S |
| Preditores fixos | P22 (2), P23 (4) | 127–132 | 120–125 | J usa vetor com sufixo `1` |
| Efeitos por seção | Mesmas equações | 134–139 | 99–105, 120–125, 178–183 | Não centralização exata isoladamente |
| Probabilidades logísticas | Mesmas equações | 142–149 | 139–144 | J: probabilidades das contagens; S: magnitudes |
| Quatro contagens | Ausentes na especificação lida | 157–160 | Ausentes | Divergência material |
| Classe comum às respostas | P22 p. 6; P23 (2–3) | 166 | 185–206 | Soma em Z exata para o alvo S |
| Frações e átomo 0,999 | Ausentes na especificação lida | 174–177 | Ausentes | Transformação discreta, não truncamento |
| Probabilidade de A | P22 p. 6; P23 antes de (3) | 187–189 | 188–190 | Fórmula comum antes do clamp e da diferença de magnitudes |
| Probabilidade de W | Mesma passagem | 191–193 | 31–44, 191–193 | J/S dependem de A observado; não o paper |
| Binomiais e suporte | P23 (3) | 196–197 | 196–206 | N tentativas; normalização física não garantida |
| Clamp e piso | Ausentes | Ausentes | 27–44, 188–193 | Mudança de alvo |
| Totais e classes | P22 p. 7; P23 p. 8 | Não definidos em J literal | 222–265 | Esperanças condicionais, não draws completos |
| Dummies e dados | Aplicação/runner, não prior universal do paper | R-F, R-Z | R-S | Codificação e alcance geográfico específicos |

As linhas J:1, 22–68, 123–154, 198–199 de abertura/fechamento delimitam os blocos acima. Comentários sobre Dirichlet, Uniformes, `N.tau`, `N.nu` e contagens duplicadas (J:10–12, 73, 81–84, 93–98, 114–119, 155–156, 169–172, 178–183) são inativos. O nome histórico “qbl” não torna (G2.11) dispensável.

# 9. Decisões pendentes e critério de entrega

**D1, alvo:** escolher entre fidelidade literal ao kernel J documentando sua política de estados inválidos, uma likelihood normalizada em domínio declarado, o produto de marginais dos artigos, ou um gerador multinomial fisicamente coerente. As últimas escolhas alteram o modelo; nenhuma é autorizada silenciosamente por esta auditoria. Se o objetivo for primeiro reproduzir o software, o kernel deve ser rotulado como tal e sua semântica runtime verificada em G3, sem apresentá-lo automaticamente como distribuição geradora válida.

**D2, priors e geografia:** escolher explicitamente a escala Exp (variância J ou desvio-padrão do texto), o tratamento do intercepto fixo e a parametrização de covariáveis. A prior parcial de mistura está derivada; impor ordem total exigiria decisão adicional.

**D3, estimandos:** definir se o alvo de incerteza é a quantidade completa por draw ou sua esperança condicional; para efeito na margem, aprovar hipótese sobre origem de S ou conservar limites. Não alterar o denominador de A sob o rótulo de mera limpeza de dados.

A entrega implementadora cobre G2-T1 a T4 com derivações e testes. G2-T5 contém marginalização, custo e contraexemplos, mas **não está done enquanto faltar sua rederivação independente**. Também não se satisfaz ainda o último critério de aceitação do gate. Os achados F1/F2 e as divergências P/J/S não desaparecem porque os testes do diagnóstico passaram: eles são precisamente resultados esperados nesses testes.

Reprodução: `Rscript --vanilla tests/mebane/algebra/run_tests.R`. Os resultados ficam em `quality_reports/results/mebane_gates/G2/round1/results/`. Foram executados testes determinísticos R/base, sem RNG, MCMC ou instalação. Eles verificam álgebra, constantes, densidades, fronteiras, enumerações pequenas e definições de estimandos; não medem identificação empírica, potência, calibração, convergência ou viabilidade nacional. O manifesto congela os bytes deste contrato e do código de auditoria. **Completar o goal de entrega do candidato não aprova G2.**
