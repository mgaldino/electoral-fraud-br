# Parecer de Execution (Framework Edmans)

**Data**: 2026-04-10
**Paper**: "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano)
**Framework**: Edmans, A. (2025). "Learnings From 1,000 Rejections." *Financial Management*, 54(2), 419-444.

## Score: 4/10

## Tipo de paper: Empirico (research note descritivo-forense)

## Resumo da estrategia empirica
Os autores aplicam *electoral fingerprint analysis* (joint distribution turnout × vote share) aos dados do TSE de 2022, em dois niveis de agregacao (municipio e secao eleitoral) e nos dois turnos, com inspecao visual de histogramas bidimensionais. A partir da ausencia de concentracao no canto superior direito e da continuidade das distribuicoes, concluem que nao ha padrao compativel com fraude sistematica e descrevem o exercicio como "teste implicito" entre H0 (eleicao limpa) e H1 (manipulacao organizada).

## Principio "Dados vs. Evidencia"

Aqui esta o cerne do problema. Os autores apresentam **dados** (mapas de calor de turnout × vote share) e os convertem em **evidencia de ausencia de fraude** — mas esse salto e o mais fragil do paper. O metodo do fingerprint e tipicamente descrito na literatura como tendo **poder assimetrico**: detecta bem ballot stuffing crua, em larga escala e geograficamente concentrada (cenario Russia 2011, Turquia 2017); detecta mal fraude dispersa, targeted, digital ou realizada sem inflar turnout. O paper nao reconhece essa assimetria. Em consequencia, confunde "ausencia da assinatura especifica deste teste" com "ausencia de fraude" — exatamente o tipo de inferencia que o principio Edmans procura disciplinar. Alem disso, a aplicacao a eleicoes **100% eletronicas** (urna brasileira, sem cedula fisica) merece discussao explicita sobre o que o teste pode e nao pode detectar nesse contexto, e essa discussao nao ocorre.

## Avaliacao por dimensao

### Mensuracao — Adequada (para o que mede), questionavel (para o que alega)
Turnout (votantes/aptos) e vote share (votos validos do candidato/validos totais) sao construcoes diretas, sem erro de medida relevante, e os dados do TSE sao censitarios. Contudo, o **conceito** que o paper alega medir e "fraude eleitoral", e o fingerprint e no maximo um proxy parcial: mede a presenca/ausencia de uma assinatura especifica de um subconjunto de tipos de fraude. A distancia entre a variavel medida e o conceito de interesse nao e tratada.

Um problema adicional: a propria bimodalidade observada e interpretada pelos autores como heterogeneidade regional — interpretacao plausivel, mas nao testada. Johnston, Schroder e Mallawaaratchy (1995), citado nas referencias mas nao discutido no texto, alerta justamente para artefatos estatisticos na razao de quantidades discretas (como turnout e vote share). A referencia esta na bibliografia sem funcao argumentativa.

### Robustez — Fraca
Esta e a dimensao mais fragil do paper:

1. **Nenhum teste formal.** A conclusao e derivada de inspecao visual. Nao ha estatistica de teste, threshold, intervalo de confianca, nem regra de decisao explicita. A afirmacao de "teste implicito de hipoteses" (p. Results) nao tem contrapartida formal — nenhum H0 e operacionalizado em uma estatistica.

2. **Nenhuma quantificacao de poder.** Um resultado nulo so e interpretavel se soubermos qual e o poder do teste contra desvios economicamente/politicamente relevantes. Sem isso, "ausencia de anomalia visual" e compativel com varios cenarios — de eleicao impecavel a fraude sofisticada ou distribuida.

3. **Nenhum benchmark comparativo.** O paper poderia (e deveria): (a) comparar fingerprints de 2022 com eleicoes brasileiras anteriores (2018 ja foi analisada pelos proprios autores), (b) comparar com eleicoes-benchmark conhecidas como limpas e fraudulentas (Klimek et al. 2012 fornece esse exercicio), (c) simular contrafactuais com fraude injetada artificialmente para mostrar o que o metodo detectaria.

4. **Nenhum metodo complementar.** Beber e Scacco (2012), Mebane (2006) e outros testes digit-based estao nas referencias; o proprio Klimek et al. (2012) propoe uma mistura gaussiana parametrica com estimacao explicita de fracao de unidades suspeitas. Nada disso e usado. Os autores reconhecem isso nas Conclusoes ("future analyses may benefit from integrating complementary methods"), mas essa limitacao nao e periferica — e central para a conclusao alegada.

5. **Nenhum teste de robustez no sentido estrito.** Robustez a escolhas de binning do histograma, a exclusao de outliers regionais, a subamostras (por estado, por regiao), a restricoes (so secoes acima de X eleitores) — nada disso aparece.

### Selecao amostral — Sem problemas
Amostra e a populacao (todas as secoes, todos os municipios). Nao ha questoes de representatividade ou selecao.

### Explicacoes alternativas — Nao enderecadas
O paper nao lida seriamente com as principais interpretacoes rivais da ausencia de assinatura visual:

- **Fraude nao detectavel pelo metodo**: localizada, dispersa, ou via manipulacao do software da urna (que nao precisa inflar turnout).
- **Heterogeneidade regional mimicking patterns**: reconhecida como explicacao para a bimodalidade quando conveniente, mas nao submetida a teste.
- **Eleicao eletronica**: o mecanismo fisico de ballot stuffing que gera a assinatura classica nao tem analogo direto em urna eletronica. O metodo pode estar respondendo perguntas erradas neste contexto.
- **Framing H0/H1**: o proprio enquadramento e estatisticamente problematico. Nao rejeitar H0 nao e evidencia de H0, especialmente sem analise de poder. Esse ponto basico de inferencia e invertido no texto ("the empirical evidence supports the null hypothesis").

## Questoes tecnicas especificas

1. **Ausencia de qualquer decisao quantitativa.** O "upper-right corner" nao e definido. Nao ha limiar de turnout × vote share a partir do qual uma concentracao seria "excessiva". Sem regra de decisao, nao ha teste.

2. **Binning arbitrario.** Histograma 2D e sensivel a escolha de bins. Sem discussao nem robustez, diferentes escolhas podem gerar visualizacoes distintas.

3. **Ausencia de referencia a Mebane (2016) no texto.** E citado no abstract/introducao mas sem engajamento com sua critica metodologica a fingerprints e sua proposta de e-forensics.

4. **"Implicit test" sem funcao operacional.** Usar a linguagem de teste de hipoteses sem a contrapartida formal enfraquece ao inves de fortalecer o paper. Melhor seria assumir o exercicio como descritivo.

## Veredicto geral sobre execution

O leitor **nao pode tirar a conclusao que os autores alegam** a partir dos dados apresentados. O paper executa adequadamente uma **descricao visual** das distribuicoes turnout × vote share de 2022 e mostra que nao ha um padrao visualmente obvio de ballot stuffing em larga escala. Isso e util e, como descricao, defensavel. Mas a conclusao de que "statistical evidence indicates that the 2022 Brazilian presidential election does not exhibit patterns consistent with systematic electoral manipulation" excede o que o metodo permite afirmar em pelo menos quatro dimensoes: (i) nenhum teste formal foi conduzido, (ii) o poder do metodo contra formas plausiveis de fraude em eleicao eletronica e desconhecido, (iii) nenhum benchmark comparativo foi apresentado, (iv) a inferencia "nao rejeitar H0 = aceitar H0" e logicamente invalida sem analise de poder. O exercicio e honesto, reproduzivel e transparente — atributos importantes — mas a distancia entre o que os dados mostram e o que o texto conclui e grande demais para o padrao de uma nota tecnica que pretende pacificar uma disputa publica sobre integridade eleitoral.

## Sugestoes construtivas

1. **Reduzir o escopo das conclusoes.** Reescrever abstract, results e conclusao para afirmar "ausencia de assinatura visual classica de ballot stuffing em larga escala", nao "ausencia de fraude". Essa ja e uma contribuicao valida e defensavel.

2. **Formalizar o teste.** Implementar o modelo de mistura parametrica de Klimek et al. (2012) para estimar a fracao de unidades com comportamento anomalo, com intervalo de confianca. Isso transforma "teste implicito" em teste de verdade.

3. **Incluir baseline comparativo.** Apresentar fingerprints de (a) 2018 brasileiro, (b) uma eleicao reconhecida como limpa (ex.: Alemanha) e (c) uma eleicao com fraude documentada (ex.: Russia 2011 ou Turquia 2017). Isso permite calibrar visualmente o que os graficos de 2022 mostram.

4. **Analise de poder por simulacao.** Injetar fraudes artificiais de diferentes magnitudes e padroes nos dados de 2022 e mostrar a partir de qual nivel o metodo as detectaria. Isso da credibilidade ao nulo.

5. **Engajar com a especificidade da urna eletronica.** Discutir honestamente quais tipos de fraude sao e quais nao sao detectaveis por fingerprint em eleicao totalmente eletronica. Reconhecer que fraude via software nao necessariamente produz assinatura de turnout.

6. **Triangular com metodos complementares.** Executar — nao apenas recomendar para o futuro — testes digit-based (Beber-Scacco last-digit, Benford de segundo digito) e reportar conjuntamente. A triangulacao e exatamente o que faltava para converter dados em evidencia.

7. **Discutir Johnston, Schroder e Mallawaaratchy (1995) no texto.** Se esta nas referencias, deveria estar sustentando argumento. Tratar artefatos estatisticos da razao turnout/vote share como ameaca a validade, nao como citacao decorativa.

8. **Tratar a bimodalidade formalmente.** Se a interpretacao e "heterogeneidade regional", mostrar isso: condicional em regiao/estado, a bimodalidade desaparece? Se nao, a interpretacao esta aberta.
