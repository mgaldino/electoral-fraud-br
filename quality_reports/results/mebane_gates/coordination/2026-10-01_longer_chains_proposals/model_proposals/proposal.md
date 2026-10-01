# Proposta de prioris e regras prospectivas de precisão

> Anexo técnico anterior à prioridade de esclarecimento terminológico. A apresentação principal e as qualificações source-bound estão em `proposals.md`; nenhuma escolha ou execução foi aprovada.

Data: 01/10/2026. Autor: Curie / Codex, agente `01a0f756-1646-7910-ac2f-986ab89aac82`.

**Estado: proposta entregue, aguardando adjudicação e confirmação do usuário. Nenhuma execução ou alteração de priori está autorizada por este documento.**

## 1. Conclusão

A dificuldade atual não se resume a caudas de classes raras. Os resumos congelados mostram problemas centrais em `pi[1]`, `pi[2]`, intensidades incrementais e funcionais de votos, enquanto `pi[3]` tem boa mistura pelos diagnósticos disponíveis. Tampouco há fundamento para afirmar que uma mistura nunca poderá alcançar ESS 400. Recomendo preservar o piso de precisão central, permitir apenas relatos explicitamente parciais quando falharem quantis e separar um baseline mais longo de, no máximo, duas sensibilidades substantivas de priori.

O código distingue **classes** sem fraude, incremental e extrema. Fabricação e transferência de votos são **mecanismos dentro das classes com fraude**. Portanto, ordenar os pesos incremental/extremo não ordena a importância de fabricação/transferência.

Esta análise usa o caso D.C. 2010, mesmas 143 unidades, fontes A/D e `comparison_final01` identificados no manifesto. Não trata de estimação brasileira ou boliviana. A revisão independente da rodada antiga confirmou fidelidade numérica, não precisão. Seus resultados, critérios e gates permanecem inalterados. O ranking empírico completo, traços e proposta detalhada de burn-in/warmup pertencem ao agente Maxwell; aqui há apenas leitura de alvos nominais já publicados.

## 2. O que as equações permitem concluir

### Classes e mecanismos

Em D, sejam \(\tau\) a participação basal, \(\nu\) a fração basal do vencedor entre participantes, \(m\) a intensidade de fabricação e \(s\) a de transferência dos demais candidatos:

\[
p_A=(1-\tau)(1-m),\quad
p_W=\tau\nu+(1-\tau)m+\tau(1-\nu)s,\quad
p_O=\tau(1-\nu)(1-s).
\]

A observação é multinomial em \((A,W,O)\), condicionada a \(N\). Os funcionais de contagens esperadas são \(M=N(1-\tau)m\) e \(S=N\tau(1-\nu)s\); não são contagens observadas de cédulas fraudulentas.

| Classe \(Z\) | Fabricação \(m\) | Transferência \(s\) |
|---|---|---|
| 1, sem fraude | 0 | 0 |
| 2, incremental | \(0.7\,\mathrm{logistic}(\eta_{im})\) | \(0.7\,\mathrm{logistic}(\eta_{is})\) |
| 3, extrema | \(0.7+0.3\,\mathrm{logistic}(\eta_{cm})\) | \(0.7+0.3\,\mathrm{logistic}(\eta_{cs})\) |

Os oponentes estão agregados em \(O\): não existe matriz de transferências entre candidatos individualizados. Fixar \(m<s\), fixar \(M<S\) e fixar \(\pi_2>\pi_3\) são hipóteses diferentes. Por exemplo, \(N=1000,\tau=.3,\nu=.6,m=.2<s=.4\) produz \(M=140>S=48\), pois os reservatórios diferem.

A usa médias de intensidade com as mesmas transformações, mas sorteia proporções auxiliares binomiais: suas realizações podem cruzar 0.7. A ainda tem a transformação literal de extremos fabricados iguais a 1 para .999 e duas verossimilhanças binomiais, com \(p_W\) dependente de \(A\) observado. Não se deve transferir a interpretação física exata de D para A. Os problemas F1, probabilidade inválida em estados com priori positiva, e F2, suporte permitindo \(A+W>N\), não são corrigidos por cadeias maiores.

Fontes locais: [A literal](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags:123), [D JAGS](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/models/experimental/mebane_ad/d_multinomial.jags:38), [D Stan](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/models/experimental/mebane_ad_stan/d_multinomial.stan:1).

### Priori vigente e identificação

As seis \(\alpha\) têm priori \(N(0,1)\); o pequeno intercepto adicional \(b_0\) tem desvio-padrão .01. As seis \(v\sim\mathrm{Exp}(\mathrm{taxa}=5)\) são **variâncias**, não desvios-padrão: JAGS usa precisão \(1/v\); Stan usa \(\sqrt v\). Assim, \(E[v]=.2\), a mediana de \(\sqrt v\) é .3723 e seu percentil 95 é .7740. Isso já regulariza a heterogeneidade local; “priori insuficientemente informativa” é uma hipótese a investigar, não um diagnóstico estabelecido. Em D, a verossimilhança depende de \(\alpha+b_0\), sem identificação separada dessa decomposição pela verossimilhança.

A e D já impõem \(\pi_1\geq\max(\pi_2,\pi_3)\). Escrevendo \(r_2=u_2/u_1,r_3=u_3/u_1\), temos \(r_2,r_3\) independentes uniformes em \((0,1)\) e
\[
(\pi_1,\pi_2,\pi_3)=\frac{(1,r_2,r_3)}{1+r_2+r_3}.
\]
A priori não ordena \(\pi_2\) e \(\pi_3\), mas as classes têm equações e suportes distintos. A ausência dessa ordem não demonstra a simetria por permutação que caracteriza a troca clássica de rótulos. Ordenações podem excluir massa posterior, não apenas renomeá-la. [Stan, posteriors problemáticas](https://mc-stan.org/docs/stan-users-guide/problematic-posteriors.html).

Uma dificuldade plausível é compensação entre participação, preferência basal, prevalência e intensidade. Três configurações de D produzem exatamente \((p_A,p_W,p_O)=(.2,.5,.3)\):

| Configuração | \(\tau\) | \(\nu\) | \(m\) | \(s\) |
|---|---:|---:|---:|---:|
| Sem fraude | .8 | .625 | 0 | 0 |
| Incremental 1 | .75 | .5 | .2 | .2 |
| Incremental 2 | 2/3 | .4 | .4 | .25 |

Em geral, \(\tau=1-p_A/(1-m)\) e \(\nu=1-p_O/\{\tau(1-s)\}\) mantêm as probabilidades quando admissíveis. O exemplo prova a não unicidade da transformação local, não a não identificação global de todo o modelo hierárquico. Restrições entre unidades e prioris podem distinguir essas configurações. Traços e análise posterior são necessários para atribuir a falha computacional a esse mecanismo.

## 3. Âncoras empíricas, sem novo ranking

Valores apenas lidos de `comparison_final01/global_functionals.csv`. São ESS bulk combinados, não por cadeia:

| Ajuste congelado | \(\pi_1\) | \(\pi_2\) | \(\pi_3\) | \(\alpha_{im}\) | \(\alpha_{is}\) | \(M_{\rm total}\) | \(S_{\rm total}\) |
|---|---:|---:|---:|---:|---:|---:|---:|
| A JAGS 20k | 14.12 | 11.67 | 16996.63 | 4.48 | 4.61 | 5.08 | 4.79 |
| D JAGS 20k | 15.24 | 12.94 | 17651.97 | 10.40 | 21.56 | 7.36 | 8.53 |
| D Stan 2k | 7.78 | 7.78 | 9005.57 | 10.87 | 5.87 | 24.52 | 4.69 |

Em D Stan, \(\widehat R(\pi_1)\approx1.469\), \(\widehat R(\pi_2)\approx1.469\), \(\widehat R(\pi_3)\approx1.0001\), e \(\widehat R(S_{\rm total})\approx2.693\). São falhas centrais relevantes, mesmo com zero divergências e zero atingimentos da profundidade máxima. Uma priori pouco informada pelos dados também pode ser amostrada muito bem; ESS alto não demonstra identificação substantiva.

Os 21 registros nominais, incluindo R-hat, ESS tail e MCSE, estão em [selected_anchors.csv](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/model_proposals/selected_anchors.csv). Não foram reprocessados draws, calculados rankings ou produzidos novos diagnósticos MCMC.

## 4. Três braços, não combinados automaticamente

### Braço 1: baseline mais longo, mesmas prioris

Proposta sujeita à confirmação: A/JAGS e D/JAGS com **100.000 draws retidos por cadeia**, D/Stan com **5.000 retidos por cadeia**, quatro cadeias por ajuste, mesmos dados e modelos. Não interpretar esses números como totais somando cadeias ou incluindo warmup. Sensibilidades opcionais não substituem esse baseline.

O burn-in/warmup será fixo, não uma fração obrigatória do comprimento. A escolha numérica final pertence à consolidação com Maxwell. Manter os valores anteriores, JAGS adaptação 1.000 + burn-in 5.000 e Stan warmup 2.000, já deixa o descarte fixo; reduzi-los em números absolutos é outra decisão computacional. Não há, nesta análise, evidência de que um descarte menor seja suficiente. Warmup Stan adapta passo e métrica, não é apenas material descartado. [Stan Reference Manual, adaptação](https://mc-stan.org/docs/reference-manual/mcmc.html#automatic-parameter-tuning).

Recursos informados pelo coordenador: **14 cores, 36 GiB RAM, 268 GiB de disco**. Propor quatro processos/cadeias concorrentes, inicialmente um thread por cadeia, e somente um fit pesado por vez. Não usar 14 threads por cadeia. Capacidade observada não é autorização nem orçamento máximo: o coordenador deve congelar limites de memória, disco e tempo, sementes/IDs, inicializações, versões e monitoramento antes da execução. Falha ou limite excedido é preservado, sem extensão, descarte de cadeia ou reinício automático.

Mais draws podem ajudar, mas não permitem extrapolar ESS linearmente quando cadeias continuam discrepantes. A comparação com a rodada serial deve separar mudança de paralelismo, adaptação e comprimento. Não se promete precisão nem comparação válida de médias entre engines antes dos diagnósticos.

### Braço 2: sensibilidade de prevalência, pesos totalmente ordenados

Somente D, mantendo as demais prioris: condicionar a priori vigente a
\[
\pi_1\geq\pi_2\geq\pi_3.
\]
Conteúdo substantivo: a classe extrema é menos prevalente que a incremental. Não impõe qual mecanismo gera mais votos nem corrige automaticamente mistura.

A condicionante correta dá densidade 2 no triângulo \(0<r_3<r_2<1\). A construção \(\,r_2=\sqrt U,\ r_3=r_2V\,\), com \(U,V\) uniformes independentes, é uma descrição matemática dessa distribuição, não código implementado. Usar simplesmente \(r_2\sim U(0,1)\), \(r_3\mid r_2\sim U(0,r_2)\) daria densidade \(1/r_2\), outra priori.

| Priori | \(E\pi_1\) | \(E\pi_2\) | \(E\pi_3\) |
|---|---:|---:|---:|
| Parcial vigente | .523248 | .238376 | .238376 |
| Condicionada à ordem completa | .523248 | .323959 | .152793 |

Ela elimina metade do suporte de pesos a priori e muda os valores esperados. Não deve ser escolhida porque obtém ESS maior. A preservação da classe sem fraude como a mais prevalente também é uma hipótese já embutida, não conclusão empírica.

Se selecionado, usar fontes D separadas e pareadas JAGS/Stan com o mesmo alvo matemático, orçamento do braço 1 e revisão de densidade antes de executar. A literal permanece intacta. Não somar a mudança do braço 3 neste braço.

### Braço 3: sensibilidade substantiva de intensidade e heterogeneidade

Somente D, mantendo a ordem parcial original e as prioris de participação/preferência basal. **Candidato numérico para elicitação, ainda sem justificativa empírica externa específica para D.C.**:

\[
\begin{aligned}
\alpha_{im},\alpha_{is}&\sim N(-1.791759469,\;0.5^2),
&&-1.791759469=\mathrm{logit}(.10/.7),\\
\alpha_{cm},\alpha_{cs}&\sim N(0,\;0.5^2),\\
v_{im},v_{is},v_{cm},v_{cs}&\sim\mathrm{Exp}(20).
\end{aligned}
\]

Mantêm-se \(b_0\sim N(0,.01^2)\), \(\alpha_\tau,\alpha_\nu\sim N(0,1)\), \(v_\tau,v_\nu\sim\mathrm{Exp}(5)\), o limiar .7 e toda a verossimilhança. Normais acima estão na convenção média/variância; em eventual JAGS, SD .5 significa precisão 4. Nada foi editado.

A proposição substantiva é: mediana incremental de 10% do reservatório elegível para cada mecanismo, com menor heterogeneidade; extrema continua centrada em 85%, mas mais concentrada. Não significa 10% de todos os eleitores. Não há preferência introduzida entre fabricação e transferência. Caso essa crença não seja defensável antes do novo ajuste, **não executar o braço 3**; elicitar outra especificação, sem escolher valores pelo ESS ou resultado eleitoral.

A integração determinística inclui \(\alpha,b_0,v\) e o efeito local, em vez de transformar apenas \(\alpha\):

| Intensidade local de cada mecanismo | Mediana | Intervalo marginal a priori de 95% |
|---|---:|---:|
| Incremental vigente | .3500 | [.0730, .6270] |
| Incremental candidata | .1000 | [.0376, .2298] |
| Extrema vigente | .8500 | [.7313, .9687] |
| Extrema candidata | .8500 | [.7763, .9237] |

Sob \(\mathrm{Exp}(20)\), \(E[v]=.05\), mediana do SD local .1862 e percentil 95 .3870. Para um reservatório fixo de 200 oportunidades, a mediana da contagem **esperada condicional** incremental cai de 70 para 20; seu intervalo a priori passa de [14.59,125.41] para [7.53,45.96]. Não são quantis da contagem observada.

Há também consequência preditiva anterior aos dados: por quadratura, a intensidade incremental média candidata é .10883, não .10. Com \(E\tau=E\nu=.5\), independência a priori e uma unidade hipotética \(N=1000\), os primeiros momentos preditivos de D são:

| Braço | \(E[A]\) | \(E[W]\) | \(E[O]\) | \(E[M]/N\) | \(E[S]/N\) |
|---|---:|---:|---:|---:|---:|
| 1, priori vigente | 356.97 | 464.54 | 178.49 | .14303 | .07151 |
| 2, apenas ordem completa | 378.37 | 432.44 | 189.19 | .12163 | .06081 |
| 3, apenas intensidade candidata | 385.72 | 421.42 | 192.86 | .11428 | .05714 |

Essa tabela torna explícita a mudança científica: as sensibilidades já reduzem votos esperados atribuídos aos mecanismos **antes** de observar dados. Não é justificativa de que seriam verdadeiras. Primeiros momentos e quantis de intensidade não substituem validação preditiva completa do desenho das 143 unidades, inclusive caudas, padrões conjuntos e prevalências. Essa etapa futura também depende de confirmação; nenhuma simulação preditiva foi feita. [Stan, prior predictive checks](https://mc-stan.org/docs/stan-users-guide/posterior-predictive-checks.html#prior-predictive-checks).

Esta priori altera localização e dispersão conjuntamente; eventual efeito computacional não identificará a contribuição separada de cada mudança. Pode estabilizar regiões mal informadas ou, ao aproximar intensidades de zero, aumentar a sobreposição incremental/sem fraude. Não há garantia de melhor mistura. Qualquer sensibilidade motivada pelos diagnósticos atuais será rotulada exploratória.

## 5. Regra diagnóstica prospectiva proposta

### Separar mistura, precisão e identificação

Preservar integralmente a tabela de aprovação histórica. Na nova rodada, publicar lado a lado: critérios antigos sem alteração; diagnóstico central; precisão de cada estimando; e limitações de identificação. “Média suficientemente precisa pelo critério prospectivo” não deve ser convertido em PASS integral ou liberação inferencial.

Manter \(\widehat R<1.01\) e ESS bulk combinado \(\geq400\) para os 23 globais comuns, todos os contínuos locais já obrigatórios e coordenadas amostradas internas de Stan. Continuar auditando adaptação/HMC separadamente. Falha central em qualquer alvo obrigatório mantém o ajuste computacionalmente inconclusivo; não aceitar que mistura, cauda rara ou ausência de divergências dispensem esse controle. Quatro cadeias e piso 400 têm respaldo como triagem, não como prova matemática de convergência. [Stan, diagnósticos](https://mc-stan.org/learn-stan/diagnostics-warnings.html).

### Estimandos e erro de Monte Carlo

Para médias, definir \(\pi_c\), os 18 parâmetros hierárquicos comuns e os funcionais ativos conjuntos \(M_{\rm total},S_{\rm total}\). Relatar também \(r_M=M_{\rm total}/N_T\) e \(r_S=S_{\rm total}/N_T\), com \(N_T=\sum_iN_i\) explícito. Caso se deseje \(r_F=(M_{\rm total}+S_{\rm total})/N_T\), incluí-lo prospectivamente, sem trocar o denominador por votos válidos.

Para intervalos centrais de 95%, definir quantis .025 e .975; para a mediana, .5. `ess_tail` usa .05 e .95, não os extremos desse intervalo de 95%. Reportar o tail-ESS antigo e calcular separadamente `ess_quantile` e `mcse_quantile` nos quantis efetivamente comunicados. Um intervalo de 99.5% exigiria .0025 e .9975, não a mesma checagem. [posterior: tail ESS](https://mc-stan.org/posterior/reference/ess_tail.html), [ESS por quantil](https://mc-stan.org/posterior/reference/ess_quantile.html), [MCSE por quantil](https://mc-stan.org/posterior/reference/mcse_quantile.html).

**Tolerâncias propostas para confirmação, não padrões universais da literatura:**

| Alvo | Teto absoluto do MCSE da média | Teto absoluto do MCSE de cada quantil |
|---|---:|---:|
| \(\pi_c\) | .001 | .0025 |
| \(r_M,r_S\), e \(r_F\) se incluído | .00010 | .00025 |
| \(\alpha,v,b_0\) | Regra relativa abaixo | Regra relativa abaixo |

Além do teto absoluto, exigir MCSE da média \(\leq .05\,SD_{\rm posterior}\), com `mcse_mean` calculado diretamente, não inferido de ESS bulk. Para cada quantil contínuo comunicado, propor ESS do quantil \(\geq400\) e MCSE \(\leq .05\,IQR_{\rm posterior}\), além do teto absoluto quando definido. Nos parâmetros sem tolerância absoluta substantiva, aplica-se a regra relativa. Valores indefinidos ou IQR zero não geram aprovação automática. As tolerâncias dos totais equivalem a erros de 10 e 25 votos esperados por 100 mil eleitores no denominador. Devem ser confirmadas pelo usuário conforme o uso pretendido.

Se apenas a precisão de cauda falhar, permitir o rótulo **“centro satisfaz a regra prospectiva; caudas imprecisas”**, desde que todos os controles centrais pertinentes passem. Publicar MCSE, quantis e flags; intervalos insuficientemente precisos ficam exploratórios, sem conclusão apoiada em seu extremo. Não dispensar o ESS bulk nem transformar tal rótulo em aprovação integral. Esta é uma proposta de comunicação parcial, não um waiver universal de ESS tail.

R-hat/ESS/MCSE são complementares; MCSE estimado também pode ser enganoso com cadeias presas ou regiões não visitadas. Por isso a regra de precisão não substitui a triagem central. [Vehtari et al., 2021](https://arxiv.org/abs/1903.08008), [posterior: MCSE da média](https://mc-stan.org/posterior/reference/mcse_mean.html).

### Indicadores raros e quantis degenerados

Para \(I(Z_i=c)\), o estimando útil é a probabilidade \(\rho_{ic}=P(Z_i=c\mid y)\), não o quantil 95% de um Bernoulli. Exemplo: se esse quantil é 1, a transformação \(I\{X\leq1\}\) é constante, embora a probabilidade de \(X=1\) ainda possa ser estimada. Isso explica uma possível degeneração do diagnóstico, mas não autoriza classificar cadeias constantes como corretamente exploradas. O comportamento exato de NA depende da versão e deve ser testado em casos determinísticos antes do próximo relatório. [posterior: tail ESS](https://mc-stan.org/posterior/reference/ess_tail.html).

Proponho para a média de classe MCSE \(\leq.005\), ESS da média \(\geq400\) e \(\widehat R<1.01\) quando definidos, acompanhados das frequências por cadeia, transições e diferença máxima entre médias por cadeia \(\leq.05\), esta última preservada como triagem grosseira. Não transformar ausência de visitas em probabilidade zero com erro zero. [posterior: ESS da média](https://mc-stan.org/posterior/reference/ess_mean.html).

D Stan já calcula responsabilidades \(P(Z_i=c\mid\theta,y)\). Suas médias estimam \(\rho_{ic}\) sem a aleatoriedade adicional de `Z_rng\). Uma política prospectiva pode avaliar precisão dessa probabilidade Rao-Blackwellizada, mantendo os indicadores e seus NA visíveis. Isso exige mistura e precisão das responsabilidades e dos estados contínuos subjacentes; ruído aparentemente bem misturado em `Z_rng` não corrige cadeias contínuas presas. Em JAGS, qualquer extração equivalente precisará de especificação e teste prévios, sem presumir identidade entre A e D.

Somente quando o estimando de probabilidade satisfizer a regra escolhida poderá o quantil binário ser marcado **“não aplicável ao estimando”**. Probabilidade não resolvida continua não resolvida. Para totais com massa em zero ou contagens discretas com quantis degenerados, relatar massa no átomo e limitações dos quantis; não importar automaticamente a exceção binária nem declarar precisão de extremo sem método adequado previamente especificado.

Por fim, \(M_{\rm RB}=E[M_{\rm ativo}\mid\theta,y]\) tem a mesma média posterior de \(M_{\rm ativo}\), mas **não a mesma distribuição ou quantis**. A lei da variância total dá
\[
\mathrm{Var}(M_{\rm ativo}\mid y)=
\mathrm{Var}(M_{\rm RB}\mid y)+
E\{\mathrm{Var}(M_{\rm ativo}\mid\theta,y)\mid y\}.
\]
Não substituir intervalos dos totais ativos por intervalos mais estreitos de `M_RB`/`S_RB`. A redução da variância condicional não é garantia, por si só, de menor MCSE para qualquer cadeia dependente.

## 6. Perguntas para confirmação do usuário

1. **Baseline:** confirmar D.C. 2010, A/JAGS e D/JAGS com 100 mil retidas por cadeia e D/Stan com 5 mil, quatro cadeias paralelas e um fit pesado por vez? Antes de confirmar a execução, a proposta consolidada deve trazer os números exatos de adaptação/burn-in/warmup e os limites de recursos sugeridos por Maxwell/coordenador.
2. **Sensibilidades:** além do baseline, incluir somente a ordem \(\pi_1\geq\pi_2\geq\pi_3\), incluir também a priori de intensidade explicitada no braço 3, ou manter ambos apenas como propostas? A mediana incremental de 10%, intervalo marginal [.0376,.2298] e heterogeneidade menor representam crenças defensáveis sobre o reservatório de cada mecanismo? Sem resposta substantiva afirmativa, não executar o braço 3.
3. **Relato de precisão:** confirmar a separação centro/caudas e as tolerâncias propostas para médias, quantis de 95% e probabilidades de classe? Incluir \(r_F\)? Uma resposta afirmativa muda apenas a política prospectiva documentada; não reclassifica as rodadas antigas nem autoriza por si só mudanças de modelo.

Não há braço escolhido ou nova execução aprovada neste documento. A escolha dos braços 2/3 deverá explicitar engines e custos; se ambos forem aceitos nas duas engines D, serão quatro fits adicionais, além dos três do baseline, todos sequenciais entre ajustes.

## 7. Verificação e limites desta entrega

Foram executadas somente integrações determinísticas em R base: prioris dos pesos; quantis marginais das intensidades; primeiros momentos preditivos de D; identidades de probabilidades; e seleção de 21 linhas nominais de CSV já existente. Todos os testes determinísticos passaram. Não houve MCMC, compilação, instalação, simulação aleatória, mudança de modelo/priori, alteração de critério histórico ou escrita fora de `model_proposals/`.

Reprodução: `Rscript --vanilla quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/model_proposals/deterministic_checks.R`, executado a partir da raiz do repositório. O script usa apenas R base, não altera outputs existentes divergentes e não chama engines. Avisos de locale do R ao iniciar foram limitados ao fallback para C.

As referências técnicas são documentação primária e um artigo metodológico; não fornecem evidência eleitoral para escolher 10%, SD .5 ou taxa 20. O arquivo [sources.md](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/model_proposals/sources.md) separa essas bases. A entrega encerra somente este goal de proposta e não B1-B5, G3, G10, adoção de D, produção ou inferência.
