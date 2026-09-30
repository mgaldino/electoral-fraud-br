# Mebane no Brasil: proposta para retomar a validação

30 de setembro de 2026. Proposta metodológica para decisão do usuário. Não é uma nova estimação, uma portagem exata nem uma especificação de produção aprovada.

## 1. Resultado e decisão recomendada

Recomendo manter o `qbl` literal como referência de software e desenvolver, em ramo separado, uma **candidata multinomial com mecanismo explícito de transferências**. Ela preserva a contabilidade média que motiva os artigos, respeita os totais eleitorais e permite somar exatamente as três classes latentes. Essa recomendação trata da próxima especificação a estudar, não de sua validade empírica para detectar fraude.

A rodada G3 terminou com parecer independente **inconclusivo**. O reparo dos diagnósticos foi reproduzido pela revisão; as médias do pequeno caso condicionado concordaram com enumeração exata. Permanecem problemas na definição do modelo literal e uma limitação do critério de diagnóstico para variáveis discretas. O fechamento documental das fontes históricas é independente desses problemas científicos.

Há dois contraexemplos importantes. Se existe um eleitor, esse eleitor se abstém e uma contagem auxiliar assume seu valor máximo, a expressão literal pode produzir probabilidade de voto igual a 499,5. Em outro caso, com dois eleitores, o código atribui massa 1/32 a uma abstenção e dois votos no líder. O primeiro viola o intervalo de uma probabilidade; o segundo excede a quantidade de eleitores. Esses exemplos pertencem ao código congelado, não a uma conclusão sobre dados brasileiros.

O comentário do usuário de que o JAGS rodou deve continuar registrado. Terminar uma execução informa sobre aquela trajetória computacional; não demonstra que todos os estados permitidos pelo modelo sejam válidos. Tampouco prova que as dificuldades do Stan sejam causadas pelas prioris. Hamiltonian Monte Carlo (HMC), usado pelo Stan, também é MCMC: sua vantagem depende da geometria e da parametrização do alvo. A comparação de velocidade só será informativa entre implementações do mesmo modelo, com diagnósticos e precisão comparáveis.

**Decisão reservada ao usuário:** escolher qual candidata deve receber um contrato matemático novo e implementação experimental. A autorização atual cobre este diagnóstico e a proposta, sem adotar a alternativa recomendada nem iniciar nova MCMC.

## 2. Alternativas e suas diferenças

**A. Preservar o qbl/JAGS literal.** Mantém integralmente o código e serve para reproduzir seu comportamento, localizar diferenças entre versões e estudar resultados dos autores. Não oferece, neste momento, um gerador integral validado. Mais iterações, prioris ordenadas ou substituição de sampler não corrigem automaticamente os contraexemplos. O histórico Stan continua classificado como aproximação: usa magnitudes contínuas, retira contagens auxiliares e limita probabilidades por `clamp`.

**B. Normalizar explicitamente um kernel no suporte físico.** Para uma classe z, sejam R suas contagens auxiliares e theta os parâmetros contínuos. Defina `K_z(A,W,R;theta)` como a massa-base das contagens multiplicada pelas duas binomiais literais, somente quando as probabilidades são válidas e `A+W<=N`; nos demais estados, defina zero. Escolha `C_z(theta)=sum_{A,W,R} K_z`. Uma distribuição nova é `P_z=K_z/C_z`, quando `C_z>0`. Misturar esses componentes normalizados com pesos pi preserva pi como distribuição da classe antes dos dados.

Essa escolha altera o modelo: depois da normalização, a distribuição marginal de R não é, em geral, a binomial original. Normalizar tudo de uma só vez, por `sum_z pi_z C_z`, mudaria também os pesos para `pi_z C_z/sum_j pi_j C_j`. Normalizar separadamente para cada R seria uma terceira especificação. Os normalizadores dependem dos parâmetros e não podem ser omitidos. A soma direta do normalizador por componente custa ordem `N^3` por seção, usando a função de distribuição binomial para somar W. Isso não é um limite inferior de complexidade nem um tempo medido. A proposta B é matematicamente definível, mas computacionalmente mais onerosa e menos transparente como mecanismo eleitoral.

**C. Usar as probabilidades dos artigos com duas binomiais independentes.** As probabilidades esperadas dos artigos estão no intervalo correto. Assim, o produto das duas binomiais é normalizado no retângulo `0<=A,W<=N`, corrigindo a origem específica da probabilidade inválida do JAGS. Entretanto, a independência continua permitindo `A+W>N`, mesmo quando as probabilidades esperadas somam menos que um. Essa alternativa é uma referência útil para fidelidade ao texto dos artigos, não a solução proposta para o suporte físico. As divergências entre prioris dos artigos e do código também precisariam de escolha explícita.

**D. Modelo multinomial de transferências, recomendado como candidata.** Usa as probabilidades esperadas dos artigos dentro de uma distribuição conjunta de categorias mutuamente exclusivas. Corrige as duas falhas de suporte por construção. Em relação ao JAGS, muda a verossimilhança, abandona a substituição pela abstenção observada dentro de pW e retira as quatro contagens auxiliares binomiais de denominador N. Em relação ao produto de binomiais dos artigos, preserva suas marginais binomiais para A e W, mas muda a dependência entre elas: `Cov(A,W)=-N pA pW`, em vez de zero. Portanto, não é uma correção puramente computacional nem uma reprodução exata dos autores.

O `clamp` não é recomendado como quinta candidata: limitar probabilidades resolve o intervalo numérico, mas não o suporte eleitoral, e cria outro alvo sem um mecanismo declarado.

## 3. Candidata D: mecanismo, equações e limites

Uma unidade é uma seção em um turno. N é o eleitorado apto; A, a abstenção; W, votos no líder escolhido para aquele turno; e `O=N-A-W`, o resíduo. Para o Brasil, O inclui outros candidatos, brancos e nulos quando A é N menos comparecimento. Não se deve chamar todo esse resíduo de votos no adversário.

Condicionalmente à classe da seção, tau é a probabilidade de comparecer antes das transferências; nu, a probabilidade de escolher o líder entre esses participantes; m, a probabilidade de converter uma abstenção em voto no líder; e s, a probabilidade de transferir uma unidade do resíduo original para o líder. Esses são parâmetros de um mecanismo hipotético, não fatos observados sobre eleitores.

**Exemplo de médias.** Com `N=1000`, `tau=0,6`, `nu=0,4`, `m=0,2` e `s=0,3`, existem, em média, 400 abstenções originais, 240 votos originais no líder e 360 unidades no resíduo original. O mecanismo converte 80 abstenções e transfere 108 unidades do resíduo. Resultam 320 abstenções, 428 votos no líder e 252 no resíduo: a soma continua sendo 1000.

O modelo em contagens, condicionalmente aos parâmetros e à mesma classe z, é:

- (1) `(A0,L0,O0) ~ Multinomial(N; 1-tau, tau*nu, tau*(1-nu))`.
- (2) `M|A0 ~ Binomial(A0,m)` e `S|O0 ~ Binomial(O0,s)`, independentemente dados os totais originais.
- (3) `A=A0-M`, `W=L0+M+S`, `O=O0-S`.

Os denominadores de M e S são os reservatórios disponíveis. Logo `M<=A0`, `S<=O0`, `M+S<=W` e `A+W+O=N` em toda realização. Isso difere das contagens auxiliares do qbl, que usam N como denominador e não são números de votos efetivamente transferidos.

Somando os estados não observados, a distribuição observacional é:

- (4) `(A,W,O) ~ Multinomial(N; pA,pW,pO)`.
- (5) `pA=(1-tau)*(1-m)`; `pW=tau*nu+(1-tau)*m+tau*(1-nu)*s`; `pO=tau*(1-nu)*(1-s)`.

Cada termo é não negativo e a soma é um. A normalização segue do teorema multinomial. Uma fatorização equivalente é `A~Binomial(N,pA)` e `W|A~Binomial(N-A,pW/(pW+pO))`. Quando `pW+pO=0`, o caso é degenerado: `A=N,W=0`. O denominador como soma de células evita cancelamento numérico. Trocar apenas N por N-A no qbl, sem recalcular a probabilidade condicional, não produz essa equivalência. A distribuição e sua implementação básica estão descritas no [manual oficial do Stan](https://mc-stan.org/docs/functions-reference/multivariate_discrete_distributions.html); a aplicação de transferências aqui é uma derivação nossa.

**Mistura e prioris propostas.** Manter três classes por seção, com `m=s=0` na primeira. Na incremental, usar `m=0,7*logistic(eta_m)` e transformação análoga para s; na extrema, `m=0,7+0,3*logistic(eta_m)`, idem s. As frações são contínuas, como na especificação matemática examinada dos artigos. Não se conservam as quatro contagens auxiliares nem a transformação de 1 em 0,999 do JAGS.

Para isolar a mudança de verossimilhança, a primeira candidata manteria os seis preditores hierárquicos do código: `eta_ib=alpha_b+b0_b+x_i beta_b+sqrt(v_b)*z_ib`, com `v_b~Exp(taxa=5)`, `alpha_b~Normal(0,variância=1)`, `b0_b~Normal(0,variância=0,0001)`, inclinações de variância 1 e `z_ib~Normal(0,1)`. O desenho inicial seria intercept-only. Exp(5) incide na **variância**, conforme JAGS; atribuí-la ao desvio-padrão, como descrito nos artigos, seria uma sensibilidade separada. Preservar também a prior original de pi: `u1~U(0,1)`, `u2,u3|u1~U(0,u1)` e `pi=u/sum(u)`. Isso impõe `pi1>=pi2,pi3`, não `pi2>=pi3`. Preservar essa restrição nesta candidata não demonstra que ela seja adequada ao Brasil.

Somar a classe é exato: `L_i=sum_z pi_z Multinomial(A_i,W_i,O_i; p_i,z)`. São três termos por seção; não há soma de ordem N ao quadrado sobre contagens auxiliares. Stan pode calcular a mistura com `log_sum_exp`, conforme sua [documentação de misturas finitas](https://mc-stan.org/docs/stan-users-guide/finite-mixtures.html). A hierarquia ainda teria seis efeitos por seção, e a geometria pode continuar difícil. Não há medição de desempenho ou promessa de convergência nesta proposta.

**Votos esperados e contagens posteriores são objetos diferentes.** Os funcionais esperados são `N*(1-tau)*m` e `N*tau*(1-nu)*s`. Para reconstruir as contagens M e S compatíveis com os votos observados, defina `pL=tau*nu`, `pM=(1-tau)*m` e `pS=tau*(1-nu)*s`. Condicionalmente à classe, aos parâmetros e a W, `(L0,M,S)` tem distribuição `Multinomial(W; pL/pW,pM/pW,pS/pW)`, para `pW>0`. Então `A0=A+M` e `O0=O+S`. No exemplo, se W observado for 400, as médias condicionais de M e S são aproximadamente 74,77 e 100,93, distintas de 80 e 108.

Uma implementação futura deve primeiro reconstruir a classe de sua distribuição posterior e depois as transferências condicionadas aos dados, preservando o mesmo draw ao agregar seções. Não deve sortear transferências novamente da prior nem substituir quantis dos totais por somas de quantis locais. Se `pW=0`, somente W=0 tem suporte, e as três contagens dessa célula são zero. Inferência sobre a margem entre candidatos exige separar no resíduo o adversário de brancos e nulos; atribuir todo S ao adversário produziria uma interpretação indevida.

**Limite central: identificação.** Para qualquer par interior de probabilidades observáveis `(pA,pW)` no triângulo, o componente sem transferências reproduz essas mesmas probabilidades com `tau0=1-pA` e `nu0=pW/(1-pA)`. No exemplo, `tau0=0,68` e `nu0=0,6294118` geram exatamente as mesmas médias e a mesma distribuição observada, sem transferências. Isso é uma equivalência por seção, condicional a parâmetros livres; não prova equivalência das distribuições marginais de modelos hierárquicos com restrições distintas. Mostra por que suporte correto não identifica sozinho m e s. A informação adicional vem das restrições entre seções, covariáveis, prioris e hipóteses do mecanismo, cuja adequação terá de ser avaliada. Não há aqui evidência de fraude nem de sua ausência em 2022.

## 4. Diagnósticos, verificação e próximos gates

O G3 histórico continuará inconclusivo. O erro que misturava cadeias já foi corrigido sem nova amostragem: o pós-processador preserva uma matriz de 2000 iterações por quatro cadeias. Os nove valores indefinidos de ESS de cauda são outra questão. ESS é o tamanho efetivo da amostra; MCSE é o erro-padrão Monte Carlo. A [documentação de posterior](https://mc-stan.org/posterior/reference/ess_tail.html) define ESS de cauda por indicadores de quantis e explica por que cadeias constantes podem produzir NA. A página consultada é 1.7.1; o ambiente da rodada era 1.7.0. Não houve atualização de pacote.

Proponho um protocolo novo, prospectivo, para testes discretos. Manter R-hat rank-normalized abaixo de 1,01 e ESS bulk de pelo menos 400 nos alvos em que essas estatísticas são definidas. Para a massa dos estados e a função de distribuição acumulada em limiares inteiros previamente escolhidos, calcular MCSE por cadeia e comparar com probabilidades exatas quando o suporte for enumerável. A precisão absoluta requerida e os limiares devem ser justificados e congelados antes de nova MCMC. Indicadores demonstrados analiticamente constantes recebem tratamento exato; indicadores apenas constantes na amostra, com probabilidade teórica entre zero e um, são inconclusivos, não aprovados por omissão de NA. Não se alteram retroativamente os critérios da rodada antiga. Em produção contínua, os diagnósticos de cauda e os específicos de HMC continuam necessários quando pertinentes.

A checagem desta proposta é exclusivamente determinística: enumeração de mecanismos e probabilidades em N pequeno, incluindo fronteiras; comparação da multinomial com sua fatorização sequencial; reconstrução condicional de M/S; e demonstração da diferença entre normalização por componente e global. O script e seus resultados ficam separados deste texto. Testes finitos corroboram o código da demonstração; as identidades e restrições acima explicam o resultado para o domínio geral. Não foi ajustado nenhum modelo novo.

Roteiro proposto, com entregas e decisões delimitadas:

1. Fechar documentalmente a rodada G3, com adjudicação do parecer, fontes históricas recuperadas ou lacunas explicitadas, e registro central inconclusivo. Não converter o reparo em aprovação do modelo.
2. Após escolha explícita da candidata, abrir contrato G2 novo, mantendo a referência literal anterior intacta. Fixar likelihood, prioris, unidade, candidatos, estimandos, tratamento de brancos/nulos e protocolo de diagnóstico. Obter revisão independente antes de implementar ou estimar.
3. Implementar a candidata em escopo experimental, validar probabilidades e gradientes quando aplicável e comparar JAGS/Stan somente no mesmo alvo. Autorizar simulação e pilotos por contrato; não usar concordância entre samplers como teste de identificação.
4. Concluir a replicação externa G10 antes dos pilotos inferenciais de G4, conforme as dependências atuais. D.C. 2010 tem dados e chamada dos autores, mas falta saída numérica imutável; Bolívia 2019 tem números de referência, mas falta o input limpo correspondente. A localização correta desse alvo boliviano é página impressa 30, página física 31 do PDF, conforme errata já arquivada. Um modelo modificado não deve ser ajustado para coincidir com o original nem substituí-lo nessa replicação.
5. Em G4, avaliar recuperação, multimodalidade, falsas detecções sob heterogeneidade legítima e sensibilidade a prioris e geografia. Só depois medir escala em G5 e estimar o Brasil 2022 em G6. Resultados antigos e seus tempos não substituem medições do novo alvo.
6. Em paralelo, completar o conversor auditado dos arquivos brutos oficiais para o formato normalizado de 2026. G7 aprovou preparação operacional delimitada, não votos reais de 2026 nem análise inferencial. Manter os gates de cada turno e as condições de disponibilidade oficial.

Não se propõe remover artefatos, reinstalar pacotes, contactar autores ou publicar resultados nesta etapa. Buscar documentos públicos permanece dentro da preparação; comunicação com autores exigiria autorização específica.

## 5. Referências e evidências para leitura

- Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. 2022. **Measuring Election Frauds**. Manuscrito, versão de 6 de março de 2022. Especificação nas páginas impressas 3-7. [Fonte dos autores](https://websites.umich.edu/~wmebane/measfrauds.pdf). Cópia local congelada: `coordination/measfrauds_2022-03-06.pdf`, sob os resultados dos gates; SHA-256 começa com `ad3b1cd473d48540`.
- Mebane, Walter R., Jr. 2023. **Lost Votes and Posterior Multimodality in the eforensics Model**. Trabalho preparado para PolMeth 2023, Stanford University, 9-11 de julho; versão de 2 de julho de 2023. Especificação nas páginas impressas 5-8. [Fonte do autor](https://websites.umich.edu/~wmebane/pm23.pdf). A consulta remota de hoje expirou; usamos a cópia local congelada `coordination/pm23_2023-07-02.pdf`, SHA-256 começa com `615ddab21034e22c`.
- UMeforensics. **eforensics_public**, pacote R e código qbl, versão instalada 0.0.4, commit `3017de537450f97a01872d0157462a68bea348ee`. [Código fixado](https://github.com/UMeforensics/eforensics_public/tree/3017de537450f97a01872d0157462a68bea348ee). Referência de software distinta das especificações impressas.
- Vehtari, Aki; Gelman, Andrew; Simpson, Daniel; Carpenter, Bob; Bürkner, Paul-Christian. 2021. **Rank-Normalization, Folding, and Localization: An Improved R-hat for Assessing Convergence of MCMC (with Discussion)**. Bayesian Analysis 16(2): 667-718. [DOI: 10.1214/20-BA1221](https://doi.org/10.1214/20-BA1221). Identidade bibliográfica conferida na documentação primária de posterior; este lote não realizou nova leitura integral do artigo.
- Stan Development Team. **Stan Functions Reference**, versão 2.40, “Multivariate Discrete Distributions”; **Stan User's Guide**, versão 2.40, “Finite Mixtures”. Documentação primária consultada em 30/09/2026, nos links das seções 3-4. As versões da documentação não afirmam atualização do ambiente local.
- Bürkner, Paul-Christian; Gabry, Jonah; Kay, Matthew; Vehtari, Aki. **posterior: Tail effective sample size**, documentação online 1.7.1, consultada em 30/09/2026. Implementação local 1.7.0 examinada pela QA anterior.

Evidências internas: `appendices/mebane_model_contract.md` é o contrato do benchmark literal; `G3/round1/review/review.md` é o parecer final sobre revision3; ambos permanecem inalterados. Os caminhos G3 e coordination acima são relativos a `quality_reports/results/mebane_gates/`. Esta proposta não reescreve esses contratos nem suas aprovações delimitadas.
