---
title: "G2: parecer independente de matemática"
subtitle: "Round1: changes_requested por decisões materiais pendentes"
author: "QA-MATEMATICA"
date: "29 de setembro de 2026 (UTC)"
lang: pt-BR
fontsize: 10pt
geometry: margin=24mm
---

# 1. Parecer e achados

**Status: `changes_requested`.** O diagnóstico matemático do candidato é sustentado pelas fontes congeladas e pela rederivação independente. Não encontrei defeito material de derivação ou de fidelidade documental no contrato. Os cinco achados G2-F1 a G2-F5 do executor estão **CONFIRMED no alcance que efetivamente afirmam**. Isso não aprova um modelo de produção: permanecem três decisões materiais explicitamente abertas no candidato. A severidade abaixo se refere ao bloqueio de aceitação do gate, não a uma falha de escrita.

**G2-QA-D1, major: alvo estatístico ainda não selecionado.** Localizadores: contrato, linhas 163–208 e 297; JAGS, linhas 187–197; Stan, linhas 27–44 e 185–206. O JAGS permite parâmetros binomiais inválidos; os produtos dos artigos e os condicionais de JAGS/Stan também diferem quanto ao suporte físico. O candidato identifica corretamente esses fatos e apresenta alternativas, mas não escolhe entre elas. Consequência: não há alvo único contra o qual certificar G3. Opções reservadas ao usuário: reprodução do software com política de estados inválidos documentada; kernel com normalização explícita e domínio declarado; produto dos artigos, com sua interpretação delimitada; ou mecanismo físico alternativo. Não são reparos equivalentes. Resolver a decisão não exige apagar o diagnóstico do candidato.

**G2-QA-D2, major: especificação de priors e geografia ainda aberta.** Localizadores: contrato, linhas 85–118 e 299; JAGS, linhas 22–79, 86–112 e 127–149; Stan, linhas 120–169. Exp(5) governa a variância em J/S, mas o texto dos artigos diz desvio-padrão. O pequeno intercepto adicional do JAGS não foi exatamente integrado pelo Stan. A referência das dummies altera a prior dos contrastes. Consequência: é preciso registrar quais priors, desenho e tratamento de intercepto definem o alvo de comparação. Preservar J, adotar o texto dos artigos ou aceitar uma aproximação são decisões distintas. A redução exata da soma dos interceptos é matematicamente disponível, mas não a implemento nem a escolho pelo usuário.

**G2-QA-D3, major: estimandos e hipóteses de margem ainda abertos.** Localizadores: contrato, linhas 220–252 e 301; Stan, linhas 228–265; wrappers R-F, linhas 81–87, e R-Z, linhas 78–85. Os totais do Stan integram a classe em cada draw; seus quantis não são quantis de totais com classe incerta. A origem dos votos stolen não identifica automaticamente a parcela do adversário, inclusive no T2 se o resíduo inclui brancos/nulos. Consequência: escolher a distribuição-alvo dos totais e aceitar limites de margem ou aprovar hipóteses de origem. Não preencher essas lacunas com classificação modal, clipping ou hipótese silenciosa de que todo stolen veio do segundo colocado.

Não há finding novo contra a redação ou as equações do candidato. Um defeito confirmado na fonte e uma decisão material pendente não são automaticamente defeitos do documento que os diagnostica. Este parecer não substitui a adjudicação do coordenador e não altera o ledger.

## 1.1. Identidade e independência

Revisor/goal nativo: `01a0eb0d-15b5-7c51-8e6f-c5b5b93f6011`.
Executor: `01a0eaee-01df-7773-bd63-d321db26a47c`.

O manifesto revisado tem SHA-256 iniciado por `783cfb036f8f26bf`; o SHA canônico do contrato começa por `f834bc1d12d88b4b`. Os valores integrais estão em `review.json` e `integrity.json`. Conferi todos os 73 arquivos, seus tamanhos, a identidade do run e os três hashes de aprovação de G0 fornecidos no despacho. O SHA bruto do JSON estático começa por `6c85a1b83643f5df`: ele difere legitimamente do SHA canônico porque a canonicalização elimina espaços e ordena chaves. Não houve alteração do candidato.

O código independente não importa as funções algébricas do executor. Apenas avalia, isoladamente, a expressão R que define `qbl()` como texto, para compará-la ao literal JAGS congelado. Nenhum modelo é compilado ou estimado. O script do executor foi lido, não executado nesta revisão. A primeira execução do meu script obteve 68/70: duas quadraturas usavam a tolerância padrão do integrador, insuficiente para os critérios predefinidos. Preservei esses resultados em `first_run/`, aumentei a precisão da integração sem relaxar as tolerâncias e acrescentei cinco verificações. A execução final passou em **75/75**.

## 1.2. Convenção de fontes

Os caminhos integrais e hashes estão no manifesto do candidato. Para os localizadores deste parecer:

- **C**: `appendices/mebane_model_contract.md`, SHA iniciado por `ec0046bd386d048a`; PDF de 13 páginas, SHA iniciado por `6e55a3a5f3ebd88a4`.
- **J**: `G0/round1/qbl_installed_3017de5.jags`; literal da função `qbl` em `ef_models_3017de5.R`, commit fixado `3017de5`. J:1 corresponde à linha 985 do arquivo R.
- **S**: `G0/round1/final_state/stan/eforensics_qbl.stan`.
- **R-F, R-Z, R-S**: wrappers `05_eforensics_qbl_fresh_diagnostic.R`, `05_jags_qbl_zone_fe.R` e `05_stan_eforensics_qbl_calibrate.R`, respectivamente, no diretório R de `G0/round1/final_state/`.
- **P22/P23**: PDFs congelados `measfrauds_2022-03-06.pdf` e `pm23_2023-07-02.pdf`, sob `coordination/`.
- **Manual**: PDF arquivado do manual JAGS 4.3.0, páginas impressas 45, 47, 50 e 53. Sua densidade Exponencial, não a frase errada sobre sua variância, fundamenta os momentos abaixo.

Os caminhos abreviados G0 e coordination pertencem a `quality_reports/results/mebane_gates/`. Extraí texto novamente dos quatro PDFs originais, em `review/`; não usei somente a extração do executor. As especificações P22, pp. 5–7, e P23, pp. 5–8, foram lidas e as páginas de equações examinadas visualmente. P23, pp. 15–16 e 31, sustenta as ressalvas sobre multimodalidade e a inclusão de votos em branco no exemplo argentino. Não reavaliei os resultados empíricos desses artigos.

# 2. Verificação dos achados do executor

Tabela 1. Classificação independente dos cinco achados, com alcance e contraprovas a interpretações excessivas. As classificações não constituem a adjudicação final do coordenador.

| ID | Classificação e localização | Evidência e limite |
|:--|:--|:--|
| G2-F1 | CONFIRMED; defeito do modelo-fonte; J:157–177, 191–197; C:163 | Estado com massa positiva produz probabilidade 499,5. Não demonstra qual erro/rejeição ocorre no runtime JAGS; isso não foi executado. |
| G2-F2 | CONFIRMED; incompatibilidade com gerador físico; P22 p. 6, P23 eq. (3), J:196–197 | Massas físicas 0,875 e 0,96875 nos exemplos mínimos. Contraprova à alegação mais forte: o produto dos artigos é normalizado no retângulo. Não é uma distribuição matematicamente inválida nesse domínio. |
| G2-F3 | CONFIRMED; divergência entre alvos; C:128–216; S:139–144, 185–206 | Observado A substitui a média, faltam as quatro contagens e há clamp. A redução da escala auxiliar de mistura e a soma em Z isoladamente são exatas: não se deve condenar toda reparametrização. |
| G2-F4 | CONFIRMED; discrepância de especificação; C:85–118; P22 p. 6, P23 p. 7 | Variância Exp versus SD Exp; variância do intercepto colapsado 1,0001 versus 1. O tamanho pequeno da segunda diferença não a transforma em identidade nem prova impacto empírico relevante. |
| G2-F5 | CONFIRMED; distinção de estimandos/identificação; C:220–252; S:228–265 | A esperança posterior pode ser estimada corretamente por Rao–Blackwellização, mas seus quantis têm outro alvo. A ausência de origem de stolen afeta a margem, não é prova de inexistência de fraude. |

Não houve achado do executor refutado, parcial ou inconclusivo. Permanecem inconclusivos, fora das afirmações acima, a semântica operacional de rejeição JAGS, a adequação empírica nacional e a magnitude prática dos efeitos dos priors. Não transformei esses limites em findings matemáticos fictícios.

# 3. Rederivação das priors

## 3.1. Ordenação parcial e densidade

Escreva $H=\widetilde\pi_1$, $B=\widetilde\pi_2$ e $C_3=\widetilde\pi_3$. A densidade conjunta é $H^{-2}$ no domínio $0<H<1$, $0<B,C_3<H$. Na transformação $B=HU$, $C_3=HT$, o determinante absoluto é $H^2$. A densidade de $(H,U,T)$ é, portanto, 1 no cubo unitário. Eliminando H, que não aparece na likelihood:

$$\pi=\frac{(1,U,T)}{1+U+T},\qquad U,T\overset{ind}{\sim}U(0,1).$$

A matriz da transformação direta de $(U,T)$ para $(\pi_2,\pi_3)$ tem determinante $(1+U+T)^{-3}=\pi_1^3$. Logo, relativamente a $d\pi_2d\pi_3$,

$$f(\pi_2,\pi_3)=\pi_1^{-3}
\mathbf1\{\pi_j\geq0,\ \pi_1\geq\pi_2,\pi_3\},
\quad\pi_1=1-\pi_2-\pi_3.$$

Integrei independentemente em fatias de $\pi_2$, com limite superior de $\pi_3$ igual a $\min(1-2\pi_2,(1-\pi_2)/2)$, e obtive 1. A integral de $(1+U+T)^{-1}$ no quadrado confirma $E\pi_1=3\log3-4\log2=0,5232481438$. O evento $\pi_1>1/2$ equivale a $U+T<1$ e tem área 1/2. Não há ordem entre as classes 2 e 3. A densidade não é a constante 6 de uma Dirichlet uniforme condicionada à maior primeira coordenada. Tampouco a restrição identifica, por si, os mecanismos substantivos.

## 3.2. Precisão, interceptos e escala

J passa a `dmnorm` uma matriz de precisão diagonal $(10000,1,\ldots)$. Sua inversa dá variâncias $(10^{-4},1,\ldots)$. O intercepto usado no produto interno é $b_0\sim N(0,10^{-4})$, enquanto o vetor de apresentação substitui esse componente por $\alpha$. Ler apenas o vetor monitorado perderia $b_0$.

Com primeira coluna constante 1, o preditor é $b_0+\alpha+x'\beta+\sqrt v z$. As priors independentes dão $\widetilde\alpha=b_0+\alpha\sim N(0,\mathrm{var}=1{,}0001)$; conferi também a convolução das densidades. Se fosse necessário recuperar o $\alpha$ original, sua distribuição condicional a $\widetilde\alpha=a$ seria Normal com média $a/1{,}0001$ e variância $10^{-4}/1{,}0001$. O Stan usa variância 1, portanto não faz essa redução exata. Na likelihood, a decomposição da soma não é identificada; a separação posterior vem das priors.

Para $v\sim\mathrm{Exp}(5)$ e precisão $1/v$, a variância condicional do efeito é v, não $v^2$. Pela transformação de variáveis:

$$f_\sigma(s)=10s e^{-5s^2},\qquad
f_\lambda(l)=5l^{-2}e^{-5/l},\qquad s,l>0,$$

onde $\sigma=\sqrt v$ e $\lambda=1/v$. Os momentos são $Ev=0,2$, $\mathrm{Var}(v)=0,04$, $E\sigma=\sqrt\pi/(2\sqrt5)$ e $E\sigma^2=0,2$. Para $l\geq5$, $e^{-5/l}\geq e^{-1}$; assim $E\lambda$ domina uma constante vezes $\int_5^\infty l^{-1}dl$ e diverge. Se, como no texto P22/P23, o desvio-padrão tiver Exp(5), a variância residual média será $E\sigma^2=2/25=0,08$.

Integração de $N(0,v)$ contra $5e^{-5v}$ dá a densidade Laplace $\sqrt{5/2}e^{-\sqrt{10}|x|}$. A escala compartilhada induz dependência marginal entre resíduos, embora sejam independentes condicionalmente a v. A não centralização é exata pois $f_h(\alpha+\sqrt v z)\sqrt v=\phi(z)$; não se acrescenta novamente esse jacobiano em um modelo parametrizado por z.

As dummies de zona estão apenas nos quatro blocos de magnitude em R-Z:54–71 e R-S:142–179. O contraste com a referência tem variância 1, e entre duas não referências, 2; a localização da referência tem variância 1,0001. Logo recodificar a referência e reiniciar as mesmas priors independentes não preserva automaticamente a distribuição dos contrastes. Não há uma hierarquia espacial de zonas nesse código.

## 3.3. Logísticas e contagens

Para $p=a+(b-a)g(\eta)$, $\eta\sim N(\ell,v)$, a densidade transformada é

$$f(p)=\phi\!\left(\log\frac{p-a}{b-p};\ell,\sqrt v\right)
\frac{b-a}{(p-a)(b-p)},\qquad a<p<b.$$

As escolhas $(a,b)=(0,1),(0,k),(k,1)$ produzem as três expressões de C. Verifiquei a normalização por integração. J contém quatro contagens independentes condicionalmente aos parâmetros, cada uma com N tentativas, não uma contagem de abstenções ou de votos roubados. Seus suportes são todos $0,\ldots,N$, mesmo quando as probabilidades binomiais estão em intervalos separados por k.

Para $R\sim\mathrm{Bin}(N,\mu)$, a fração manufactured substitui o átomo $R=N$ por 0,999. Só esse átomo muda, com peso $\mu^N$. Por isso

$$E[m]=\mu-0,001\mu^N,\qquad
E[m^2]=\mu^2+\frac{\mu(1-\mu)}N-0,001999\mu^N.$$

Conferi N=1, 2, 4, 999, 1000 e 1001. Há colisão de dois átomos em N=1000 e diminuição no último passo para N>1000. Isso não é truncamento nem renormalização. A classe incremental pode produzir fração 1 para stolen, e a extrema pode produzir zero. O Stan não contém esses átomos.

# 4. Probabilidades, suporte e condicionamentos

Para $z=1$, tome $m_z=s_z=0$; para $z=2,3$, use o par ativo correspondente. Todos os componentes têm

$$p_{A,z}=(1-\tau)(1-m_z).$$

Nos artigos, $p^P_{W,z}=\tau\nu+m_z(1-\tau)+s_z\tau(1-\nu)$. Em J, definindo $q=A/N$ e $c_z=\nu+(1-\nu)s_z$, obtenho da expressão literal

$$p^J_{W,z}=c_z+\frac{q}{1-m_z}(m_z-c_z).$$

Em particular $p^J_{W,1}=\nu(1-q)$, não $\nu\tau$. A igualdade com o paper requer substituir $q=(1-\tau)(1-m_z)$; não é identidade entre likelihoods para observações arbitrárias. A reescrita via $t^*=1-q/(1-m_z)$ confirma a álgebra, mas $t^*<0$ perde interpretação física.

Como a função é afim em q, os extremos são $c_z$ e $m_z(1-c_z)/(1-m_z)$. Não é negativa no domínio declarado. Estar em $[0,1]$ para todo q equivale a $m_z(2-c_z)\leq1$. Também

$$q+p^J_{W,z}=c_z+(1-c_z)\frac q{1-m_z}.$$

Para $c_z<1$, a restrição de médias físicas equivale a $q\leq1-m_z$. Para $c_z=1$, a soma é sempre 1; isso não resgata uma reconstrução com $t^*<0$. Estes resultados foram testados em 400 combinações, incluindo fronteiras. Médias fisicamente compatíveis ainda não bastam para restringir o suporte de uma Binomial com N tentativas.

**Contraprovas reproduzidas.** Em J, N=A=1, $R_M=1$, $R_S=0$, $\nu=\tau=0,5$ produz $p_W=499,5$ e $P(A=1)=0,0005$. O evento tem massa positiva nas contagens e numa região aberta dos parâmetros contínuos. Em P, N=1, $\tau=\nu=0,5$, sem fraude, dá massa 0,125 ao evento impossível A=W=1. Em J sem fraude, N=2, A=1, $\tau=\nu=0,5$ dá massa conjunta 0,03125 a W=2. Nenhuma dessas verificações depende de diagnóstico MCMC.

O clamp Stan substitui probabilidades fora de $[10^{-9},1-10^{-9}]$ por seus limites e limita o denominador. A configuração incremental $(q,\nu,m,s)=(0,9;0,1;0,6;0,05)$ dá probabilidade bruta 1,16875. Além desse contraexemplo, testei o piso do denominador na classe extrema em uma região não saturada. O modelo Stan é normalizado no retângulo porque cada condicional em W soma 1 e depois a marginal em A soma 1. Não é um gerador restrito a $A+W\leq N$. Num teste próprio com N=3, a massa no triângulo foi 0,8432159473, enquanto no retângulo foi 1.

Para o kernel diagnóstico que zera pais inválidos, um normalizador $C_D(\theta)$ depende do domínio D e dos parâmetros. No caso N=1 acima, ele vale 0,9995 para $\tau=0,5$ e 0,9998 para $\tau=0,8$. Condicionar a admissibilidade das contagens latentes dado A exige outro normalizador: por exemplo, somar suas massas no subconjunto admitido dado A não é somar a distribuição de todos os dados possíveis. Normalizar após integrar os latentes, normalizar cada estado latente antes de integrar, ou normalizar cada componente preservando $\pi$ são escolhas distintas. O candidato separa corretamente essas operações e não presume que o runtime JAGS implemente uma delas.

# 5. T5: rederivação independente efetiva

Fixe os parâmetros contínuos, incluindo efeitos locais e probabilidades de mistura. Denote as quatro contagens por $r_2,t_2,r_3,t_3$ e suas massas por $b_{M,2},b_{S,2},b_{M,3},b_{S,3}$. Pela lei da probabilidade total para o kernel diagnóstico explicitamente escolhido,

$$L=\sum_{z=1}^3\pi_z
\sum_{r_2,t_2,r_3,t_3}
\left[\prod_{j=2}^3 b_{M,j}(r_j)b_{S,j}(t_j)\right]K_z.$$

Em $z=2$, $K_2$ independe de $r_3,t_3$ e suas massas somam 1. O simétrico vale em $z=3$; em $z=1$, todas somam 1. Portanto

$$L=\pi_1K_1+\sum_{z=2}^3\pi_z
\sum_{r=0}^N\sum_{t=0}^N
B_N(r;\mu_{M,z})B_N(t;\mu_{S,z})K_z(r,t).$$

Esta prova depende de condicionar nos parâmetros contínuos: não presume independência marginal após integrar hiperparâmetros compartilhados. Também não acrescenta restrições aos pares inativos. As expressões de classes inativas são finitas porque a fração manufactured é menor que 1; uma política que rejeitasse toda configuração por uma classe inativa definiria outro kernel.

**Teste independente.** A rota completa usa produto de quatro massas `dbinom`, três classes e a fórmula literal de J. A rota reduzida usa coeficientes por fatoriais, apenas o par ativo e uma expressão de $p_W$ derivada via $t^*$. Comparei todos os pares A,W para N=1,2,3,4, em três configurações distintas: 162 casos. O erro absoluto máximo foi $4,4408921\times10^{-16}$, abaixo de $10^{-12}$. Há também prova simbólica acima; concordância numérica sozinha não seria prova geral.

Para normalizar, a soma em W é 1 no retângulo e é $H_D=P\{\mathrm{Bin}(N,p_W)\leq N-A\}$ no triângulo. Assim,

$$C_{D,z}=\sum_{r,t,A}B_N(r;\mu_{M,z})B_N(t;\mu_{S,z})
B_N(A;p_A)\mathbf1_{[0,1]}(p_W)H_D.$$

Comparei esta expressão com a enumeração explícita de W para N=1 a 4 e os dois domínios. Para normalização global da mistura, $C_D=\sum_z\pi_zC_{D,z}$; se componentes forem normalizados primeiro, a likelihood será $\sum_z\pi_zL_z/C_{D,z}$, em geral diferente de $(\sum_z\pi_zL_z)/C_D$. Um caso próprio produziu 0,1545689825 e 0,1545709769, respectivamente.

O custo direto por unidade é $1+2(N+1)^2$ avaliações, não quatro somas necessárias. O normalizador por CDF custa diretamente $O(N^3)$. Para 6748 unidades com N=300, a contagem de avaliações da likelihood é 1.222.757.844. Isso não é benchmark, limite inferior ou prova de inviabilidade. O custo de integração contínua e de diferenciação não foi medido.

**Substituição pela média não marginaliza.** Reproduzi o exemplo do executor: 0,171900319424 versus 0,19600864. Acrescentei uma contraprova que isola a não linearidade: fixando m=0 e condicionando em A=0, N=2, $\nu=0,4$ e $R_S\sim\mathrm{Bin}(2,0,3)$, tem-se $p_W=0,4+0,6R_S/2$. Para W=1,

$$E[2p_W(1-p_W)]=2\bar p(1-\bar p)-2\mathrm{Var}(p_W).$$

A soma é 0,4116 e a substituição por $\bar p=0,58$ produz 0,4872; a diferença é 0,0756. Todos os estados desse exemplo têm probabilidade válida, não há transformação 0,999 nem clamp, e m=0 ocorre com massa positiva na contagem latente. Portanto esses mecanismos adicionais não explicam nem eliminam a falha de equivalência. A prova por variância também se estende a uma vizinhança por continuidade.

**Conclusão de T5:** a parte independente requerida foi executada e sustenta as equações G2.16–18 no escopo de kernel expressamente declarado. Não resolve D1, não certifica a política operacional JAGS e não constitui implementação G3.

# 6. Totais, incerteza e identificação T1/T2

No draw conjunto, os funcionais dos artigos são $M_i=N_im_i(1-\tau_i)$ e $S_i=N_is_i\tau_i(1-\nu_i)$, zerados na classe sem fraude. São intensidades/quantidades esperadas condicionais aos parâmetros, e não as contagens auxiliares $R_M,R_S$. O total F é a soma dos funcionais no mesmo draw, preservando a dependência posterior entre unidades.

Se $g_{iz}$ é um funcional em cada classe e $r_{iz}$ a responsabilidade posterior condicional nos contínuos, o Stan guarda $\bar F(\theta)=\sum_{i,z}r_{iz}g_{iz}$. Sua média entre draws estima $E(F\mid D)$, mas

$$\mathrm{Var}(F\mid D)=\mathrm{Var}_\theta\{\bar F(\theta)\}
+E_\theta\{\mathrm{Var}(F\mid\theta,D)\}.$$

Condicional nos contínuos de um modelo local fatorizado, a parcela das classes é $\sum_i[\sum_zr_{iz}g_{iz}^2-(\sum_zr_{iz}g_{iz})^2]$. Se as contagens também foram integradas, é necessário incorporar sua distribuição posterior condicional, não sortear da prior binomial original. O teste independente de uma distribuição posterior discreta de dois estados de $\theta$ encontrou variância total 208,96, variância das esperanças condicionais 116,16 e parcela omitida 92,8. Não se trata de penalizar Rao–Blackwellização: ela é correta para a média e para o estimando de esperança condicional, não para substituir a distribuição completa.

Para adversário fixado R, sob a intervenção contábil declarada em C,

$$D_0=(W_{obs}-M-S)-(R_{obs}+S_R)
=D_{obs}-M-S-S_R.$$

Sem origem individual identificada, $0\leq S_R\leq S$ fornece

$$D_{obs}-M-2S\leq D_0\leq D_{obs}-M-S.$$

Esses limites são condicionais ao mecanismo e à viabilidade dos totais. Não são limites incondicionais sobre fraude verdadeira nem intervalos de confiança. Com M=8, S=3 e margem 20, obtive [6,9]. Limites de capacidade/origem podem estreitar o intervalo; se $M+S>W_{obs}$, a reconstrução de votos realizados não é viável.

No **T2**, mesmo dois candidatos não bastam para fixar $S_R=S$ se o resíduo do modelo inclui brancos/nulos. Os wrappers efetivamente usam comparecimento e W do código 13, deixando tais categorias no resíduo. Apenas a hipótese adicional de que todo stolen veio do adversário justifica o limite inferior como identidade. Convergência não identifica essa hipótese.

No **T1**, os votos devolvidos podem mudar o segundo colocado, de modo que a margem contra um adversário fixo não identifica a ordenação contrafactual inteira. Além disso, uma pergunta sobre superar metade dos votos válidos exige outro denominador. Como complemento algébrico, não certificação jurídica ou de dados, denote por $V_v$ os votos válidos observados e por $S_I$ o stolen cuja origem seria inválida. Sob o mesmo mecanismo,

$$V_{v,0}=V_v-M-S_I,\qquad
H_0=W_{obs}-M-S-\tfrac12(V_v-M-S_I).$$

Portanto, com $H_{obs}=W_{obs}-V_v/2$,

$$H_{obs}-M/2-S\leq H_0\leq H_{obs}-(M+S)/2.$$

Isso evidencia por que a margem entre dois candidatos não responde automaticamente à pergunta de maioria sobre votos válidos. Nenhuma hipótese sobre $S_I$ ou $S_R$ foi aprovada por este parecer. Esta extensão esclarece o uso em T1/T2, sem imputar ao contrato uma afirmação de vencedor que ele não fez.

Priors, multimodalidade, intenção e identificação permanecem dimensões distintas. P23 reconhece múltiplas origens para multimodalidade. Os R-hat e tempos históricos foram lidos, não recalculados; não há comparação controlada de HMC versus JAGS nem inferência nacional nesta revisão.

# 7. Completude, QA visual e critérios

## 7.1. Manifesto

**`manifest_complete: true` para o candidato matemático auditado.** Além dos hashes, cruzei os campos inputs/code/configuration/outputs de run, os comandos, `prepare_sources.py`, `build_candidate.py`, `inspect_pdf.py`, o filtro Lua, os dois scripts algébricos, os literais J/S, os três wrappers e as fontes efetivamente invocadas nas afirmações. Não encontrei insumo matemático material omitido.

As cinco cópias históricas/contextuais são aliases congelados de originais: conferi igualdade de bytes entre cada original e seu snapshot, bem como suas entradas de proveniência e inclusão no manifesto. Não exigi outra cópia redundante do mesmo conteúdo. As versões de fontes de produção usadas são os snapshots G0, não arquivos mutáveis atuais. Os dados/fits que os wrappers leriam não são inputs desta auditoria: os wrappers não foram executados e o candidato distingue os resultados históricos de nova execução.

O teste pontual de projeção do ledger relata uma leitura histórica; o insumo operacional revisado é o contrato estático completo com hash canônico conferido. Não usei o ledger mutável como fonte de critérios. `manifest_complete` não significa restauração fria do ambiente, reexecução de fits ou investigação dos binários históricos. A reprodução exata de fonte e renderização é mais estreita que a validação inferencial.

## 7.2. QA visual

Inspecionei as folhas de contato das 13 páginas, vinculadas ao PDF pelo manifesto, e novas renderizações das páginas 6 e 8, focadas nas equações G2.12–18. Também examinei a página 12 em detalhe para a tabela de correspondência. Não observei equações ilegíveis, caracteres substituídos por caixas, conteúdo não textual indevido ou cortes materiais. A tabela continua entre páginas 11–12, com cabeçalho repetido. Isso é QA pontual, não uma revisão tipográfica caractere por caractere.

Nas fontes primárias, a inspeção visual de P23, PDF p. 9 (impressa 7), confirmou que falta o k em (4d); P22, PDF p. 8 (impressa 6), contém k. O candidato assinala essa diferença em vez de corrigir silenciosamente a transcrição.

## 7.3. Aceitação e limites

Tabela 2. Critérios de aceitação do contrato estático.

| Critério | Resultado da revisão |
|:--|:--|
| Equivalências derivadas/testadas e divergências rotuladas | Atendido no alcance declarado; nenhuma equivalência integral indevida foi encontrada. |
| Exp(5) e parâmetros de escala correspondem ao código | Atendido; divergência em relação ao texto dos papers permanece explícita. |
| Suporte, discretização, constantes e transformações auditados | Atendido; defeitos das fontes e limites de interpretação permanecem, sem reparo silencioso. |
| Revisor independente rederiva e não resta questão material aberta | Rederivação realizada; critério global não atendido por D1–D3. |

G2-T1 a T4 têm cobertura de auditoria confirmada. G2-T5 agora conta com rederivação independente efetiva no escopo declarado. O coordenador pode usar esta evidência para atualizar o registro, mas o gate continua `changes_requested` até adjudicação e decisões materiais apropriadas. Não alterei status de todos, ledger, fontes ou candidato.

Os testes são determinísticos em R/base, sem dados eleitorais novos, RNG, MCMC, instalação ou G3. Não testei JAGS/Stan runtime, identificação empírica, calibração, potência, desempenho nacional, reconstrução de fits, autenticidade externa dos downloads ou regras eleitorais oficiais. Os avisos de locale não impediram a execução R. O hash integral da entrega e os resultados estão nos arquivos acompanhantes.

## 7.4. Reprodução

Todos os scripts e resultados deste revisor estão no diretório desta revisão. A partir da raiz do projeto:

```bash
REV=quality_reports/results/mebane_gates/G2/round1/review
python3 "$REV/verify_evidence.py"
Rscript --vanilla "$REV/independent_checks.R"
python3 "$REV/package_review.py"
```

O último comando valida o JSON, renderiza este Markdown em PDF com ferramentas já instaladas, registra comandos/versões, extrai o texto e produz um manifesto próprio sem autorreferência. Não reexecuta nenhum script do candidato. Uma nova execução atualiza somente os arquivos em `review/`, nunca os 73 arquivos congelados.
