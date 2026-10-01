# Memorando: significado das classes e propostas em espera

**Estado: awaiting_confirmation; noMCMC.** 01/10/2026. Curie / Codex, agente `01a0f756-1646-7910-ac2f-986ab89aac82`. Este memorando curto tem precedência sobre a apresentação no anexo `proposal.md`. A confirmação do usuário continua necessária; nenhum modelo, priori, fit ou gate foi alterado.

## Esclarecimento prioritário

**Os dois mecanismos descritos pelo usuário estão nos textos. Nos dois PDFs locais conferidos, porém, os nomes incremental/extrema classificam sua magnitude, não reservam um mecanismo a cada classe.** Isso é uma conclusão sobre estas versões específicas, não sobre todo uso desses termos nem sobre o paper ainda não identificado que o usuário leu.

### 2022: narrativa e equações distinguem magnitude e origem

Mebane, Ferrari, McAlister e Wu, *Measuring Election Frauds*, versão de 6/03/2022, seção 2.1:

- **p. impressa 5 / PDF 7:** o texto primeiro distingue votos retirados da oposição de votos produzidos a partir de não votantes. Logo depois define os dois tipos pela quantidade deslocada: “with ‘incremental fraud’ moderate proportions and with ‘extreme fraud’ almost all of the votes are shifted.” Aspas tipográficas normalizadas; palavras preservadas.
- **p. impressa 6 / PDF 8:** o primeiro parágrafo associa \(\iota_i^M,\iota_i^S\) a fabricação e transferência sob fraude incremental, e \(\upsilon_i^M,\upsilon_i^S\) aos mesmos mecanismos sob fraude extrema. As equações **(2c), (2d)** usam \(l\in\{M,S\}\) em ambas as classes, com \(k=.7\); a equação **(3)** soma fabricação e transferência tanto para \(Z_i=2\) quanto para \(Z_i=3\).

Fonte: [PDF local de 2022](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive/measfrauds_2022-03-06.pdf).

### 2023: os dois mecanismos continuam em cada classe

Walter R. Mebane, Jr., *Lost Votes and Posterior Multimodality in the eforensics Model*, versão de 2/07/2023, seção 2.1:

- **p. impressa 5 / PDF 7:** fabricação vem de não votantes; transferência vem da oposição agregada para o líder.
- **p. impressa 6 / PDF 8:** as equações **(2a), (2b)** mantêm \(M\) e \(S\) em incremental e extrema. O texto logo abaixo explica os quatro símbolos. A equação **(1)** só garante \(\pi_1\geq\pi_2,\pi_3\). O autor declara: “I use this prior to deter label switching”. Essa motivação merece registro; não demonstra que a falha atual seja troca de rótulos, nem que falte ordenar mecanismos.

Em notação dos artigos, o aumento fraudulento do voto no líder é
\[
p_{wi}=
\begin{cases}
\iota_i^M(1-\tau_i)+\iota_i^S\tau_i(1-\nu_i),&Z_i=2,\\
\upsilon_i^M(1-\tau_i)+\upsilon_i^S\tau_i(1-\nu_i),&Z_i=3.
\end{cases}
\]
O primeiro termo usa o reservatório de abstinentes; o segundo usa votos da oposição. Nenhuma das duas linhas elimina um deles.

**Cautela de versão:** na p. impressa 7 / PDF 9, a equação **(4d)** de 2023 aparece visualmente com um sinal “+” sem o \(k\) aditivo anterior. A equação (2d) de 2022 e o `qbl` incluem esse \(k\). Trato a omissão como discrepância aparente de impressão, não a corrijo silenciosamente nem a interpreto como nova teoria. Os textos também descrevem \(\mathrm{Exp}(5)\) sobre um desvio-padrão, enquanto o código inspecionado o aplica a uma variância. Este memorando não certifica identidade integral paper/código.

Fonte: [PDF local de 2023](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive/pm23_2023-07-02.pdf).

### O que efetivamente faz o qbl arquivado

No [qbl instalado, commit 3017de5](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags):

| Localizador | Evidência |
|---|---|
| Linhas 37, 45, 53, 61 | Quatro blocos nomeados: incremental/fabricados, incremental/roubados, extrema/fabricados, extrema/roubados. |
| Linhas 145-149 | `mu.iota.m/s` usam \(k\,logistic\); `mu.chi.m/s` usam \(k+(1-k)logistic\). `chi` corresponde aqui ao papel de \(\upsilon\) dos artigos. |
| Linhas 157-177 | Quatro contagens binomiais auxiliares separadas; suas frações realizadas não têm separação rígida pelo limiar .7, embora suas médias tenham. |
| Linhas 187-193 | `p.a` contém fabricação nas duas classes; `p.w` contém `iota.m/s` para \(Z=2\) e `chi.m/s` para \(Z=3\). |
| Linhas 13-18; 86-105 | Ordem parcial dos pesos; exponencial sobre variâncias, usadas via precisão recíproca. |

D JAGS e D Stan preservam essa distinção classe/mecanismo, mas sua verossimilhança multinomial é experimental e não deve ser atribuída literalmente ao artigo ou ao qbl.

**Resposta sugerida ao usuário:** “Sua descrição identifica corretamente os mecanismos de fabricação e transferência. Nos textos de 2022 e 2023 que localizamos, incremental/extrema distinguem a intensidade: ambas permitem os dois mecanismos. Se o paper que você leu reserva incremental para fabricação e extrema para transferência, precisamos comparar esse trecho específico, pois pode ser outra formulação.”

## Consequência para as propostas

Não confundir três decisões científicas: ordenar prevalências \(\pi_2\geq\pi_3\); ordenar intensidades \(m\) e \(s\); ou tornar os mecanismos mutuamente exclusivos por classe. A última exigiria, por exemplo, retirar transferência de \(Z=2\) e fabricação de \(Z=3\), mudando substantivamente os modelos atuais. **Não a acrescento como quarto braço nem como reparo autorizado.**

Mantêm-se no máximo três braços, ainda não escolhidos:

1. **Baseline, prioris intactas:** A/JAGS e D/JAGS com 100 mil retidas por cadeia; D/Stan com 5 mil, a confirmar. Quatro cadeias paralelas, um fit pesado por vez. Burn-in/warmup fixos e seus valores exatos dependem da proposta consolidada de Maxwell/coordenador. Recursos informados: 14 cores, 36 GiB RAM e 268 GiB de disco.
2. **Sensibilidade somente D, pesos ordenados:** condicionar a priori vigente a \(\pi_1\geq\pi_2\geq\pi_3\), preservando os dois mecanismos por classe. Isso afirma menor prevalência extrema, não prioridade de fabricação sobre transferência. A densidade correta é 2 no triângulo \(0<r_3<r_2<1\); não confundir com prioris uniformes sequenciais diferentes.
3. **Sensibilidade somente D, intensidade/shrinkage:** candidato já calculado, não recomendado por resultado: \(\alpha_{im},\alpha_{is}\sim N(-1.791759,.5^2)\), \(\alpha_{cm},\alpha_{cs}\sim N(0,.5^2)\), quatro variâncias de fraude \(\mathrm{Exp}(20)\), demais prioris intactas. Mediana incremental .10 e intervalo marginal a priori de 95% [.0376,.2298], em vez de .35 e [.0730,.6270]. O usuário precisa endossar esse conteúdo substantivo antes de qualquer mudança; não há justificativa externa específica para escolher 10% neste caso.

As tabelas determinísticas de intensidade e primeiros momentos preditivos já existentes permanecem disponíveis; nenhum cálculo adicional de priori foi executado após a mudança de prioridade.

## Precisão: proposta prospectiva, não dispensa geral

Os resumos congelados de D Stan já mostram ESS bulk de aproximadamente 7.78 para \(\pi_1,\pi_2\), contra 9005.57 para \(\pi_3\). Isso impede tratar a dificuldade como exclusivamente cauda rara; não é um novo ranking.

Proponho manter R-hat <1.01 e ESS bulk combinado >=400 nos contínuos obrigatórios. Para médias, usar MCSE direto; para intervalos centrais de 95%, avaliar quantis .025/.975, não apenas o `ess_tail` padrão de .05/.95. Proposta numérica para confirmação: MCSE da média <=5% do SD, também <=.001 para pesos e <=.00010 para \(M/N_T,S/N_T\); nos quantis, ESS >=400 e MCSE <=5% do IQR, também <=.0025 para pesos e <=.00025 para essas taxas. \(N_T=\sum_iN_i\). Esses tetos são escolhas operacionais propostas, não mandatos da literatura. [Stan](https://mc-stan.org/learn-stan/diagnostics-warnings.html), [posterior: quantis](https://mc-stan.org/posterior/reference/ess_quantile.html), [posterior: MCSE](https://mc-stan.org/posterior/reference/mcse_quantile.html).

Para indicadores de classe, avaliar a probabilidade de classe, propondo MCSE <=.005, ESS da média >=400 e R-hat <1.01 quando definidos. Responsabilidades Rao-Blackwellizadas podem avaliar essa mesma média em D, sem converter cadeias constantes/NA em precisão zero. Quantis binários degenerados podem ser “não aplicáveis ao estimando”, mas apenas com a precisão da probabilidade demonstrada. Os quantis de \(M_{\rm RB}\) não substituem os de \(M_{\rm ativo}\). Se somente as caudas falharem, relatar “centro satisfaz a regra prospectiva; caudas imprecisas”, sem PASS integral ou reclassificação histórica. [posterior: tail ESS](https://mc-stan.org/posterior/reference/ess_tail.html), [Vehtari et al., 2021](https://arxiv.org/abs/1903.08008).

**Confirmações pendentes:** qual é o paper/trecho que sustenta a interpretação alternativa; quais dos três braços o usuário deseja; e quais configurações fixas/tolerâncias prospectivas aceita. A adjudicação do coordenador não substitui essa confirmação.

## Verificação e escopo

Leitura direta com Poppler dos dois PDFs locais e inspeção visual de cinco páginas: 2022 PDF 7-8; 2023 PDF 7-9. Extrações e PNGs permanecem neste diretório. Hashes, fontes exatas e evidências estão em `proposals.json` e `source_manifest.json`. Não certifico igualdade com versões remotas atuais, nem identidade do paper ainda não identificado pelo usuário.

Somente este memorando e sua proposta foram concluídos: **noMCMC, awaiting_confirmation, sem prioris/modelos/gates alterados**. `proposal.md` é anexo técnico anterior, não autorização nem decisão executada.

