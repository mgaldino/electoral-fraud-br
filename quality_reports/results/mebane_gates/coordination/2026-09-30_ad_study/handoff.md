# Estudo A/D: estado para retomada

30 de setembro de 2026. A revisão independente e a adjudicação da entrega estão
concluídas: fidelidade quantitativa/documental aprovada, precisão posterior não
aprovada. O encerramento e seus hashes estão em `completion.json`.

## Resultado do lote

A, o qbl literal dos autores, foi preservado. D, a candidata multinomial de
transferências, foi implementada separadamente em JAGS e em funções R para
validação. As duas alternativas foram aplicadas às mesmas 143 unidades de
D.C. 2010, sem exclusões, mantendo a codificação original dos autores.

Contrato prospectivo: `contract_v2.json`. Uma tentativa por modelo, quatro
cadeias, 1.000 iterações de adaptação, 5.000 de aquecimento e 2.000 amostras
retidas por cadeia. Nenhuma extensão ou alteração de prioris após os resultados.

| Medida | A | D |
|---|---:|---:|
| Geração, processo completo | 102,57 s | 68,25 s |
| Geração + diagnóstico, processos completos | 124,92 s | 89,97 s |
| Maior R-hat entre os 23 globais | 3,451 | 2,472 |
| Menor ESS bulk entre os globais | 4,41 | 4,84 |
| Alvos obrigatórios que não passaram | 1.605/2.171 | 1.021/1.742 |
| Desses, alvos com diagnóstico indefinido | 432 | 392 |

As duas execuções terminaram sem erro, mas a comparação é
**computacionalmente inconclusiva**. R-hat mede a concordância das cadeias;
o limite prospectivo era menor que 1,01. ESS é o tamanho efetivo da amostra,
uma medida da informação Monte Carlo; exigimos pelo menos 400 no centro e nas
caudas. Os mínimos próximos de quatro não satisfazem esse requisito. Há falhas
globais, incluindo M e S, além de indicadores discretos indefinidos. Indefinição
amostral isolada não prova classe impossível ou não convergência.

Em D, as médias de M por cadeia foram 168,23; 1.269,17; 0; e 956,02. A média
reunida de 598,36 esconde essa variação. Esses são funcionais estatísticos,
não votos fraudulentos observados. A revisão independente os recompôs dos raw.

As médias brutas dos pesos da mistura são próximas, mas isso não estabelece
equivalência dos modelos ou dos resultados. D foi mais rápida nesta tentativa;
sem precisão adequada, não há ranking validado de eficiência. A preservação de
A também não resolve os contraexemplos anteriores de suporte físico. D melhora
o suporte por construção, mas sua identificação substantiva não está demonstrada.

## Onde estão os artefatos

- `release_v1.json`: fontes e protocolo que foram efetivamente liberados.
- `pilot01/A` e `pilot01/D`: entradas, inicializações, cadeias brutas, estado final,
  tempos por fase e fontes consumidas. Nenhuma MCMC continua rodando.
- `pilot01/A_diagnostics` e `pilot01/D_diagnostics`: diagnósticos por alvo,
  resultados por cadeia, funcionais conjuntos e classificações.
- `comparison01`: CSVs comparativos e relatório Markdown, gerados dos outputs.
- `comparison_A_D_DC2010_v1.pdf`: relatório legível com referências completas.
- `review_contract`, `review_preflight`, `review_preflight_delta`, `review_results`:
  revisões independentes, fixtures e vínculos de integridade.
- `RUNS.md`: histórico de tentativas técnicas preservadas, inclusive falhas.
- `study_state.json`: todos do lote, separados dos gates históricos brasileiros.

Código de D: `models/experimental/mebane_ad/d_multinomial.jags` e
`R/experimental/mebane_ad/model_d.R`. Orquestração e diagnóstico ficam em
`R/experimental/mebane_ad/`; testes em `tests/mebane/ad_study/`.
Os caminhos deste parágrafo são relativos à raiz do repositório; os demais
caminhos desta nota são relativos à pasta do estudo.

## Próxima investigação proposta

1. Examinar a mistura das cadeias e os parâmetros responsáveis pelos problemas,
   usando primeiro as amostras já preservadas. Não mudar as regras desta rodada.
2. Traduzir **D**, não uma aproximação de A, para Stan: marginalizar a classe
   discreta, estudar parametrização não centrada e preservar exatamente prioris,
   inclusive Exponencial(5) sobre variâncias. Antes de estimar, testar igualdade
   da densidade-alvo em pontos fixos e em casos pequenos. HMC pode melhorar a
   exploração; não se presume que resolverá multimodalidade ou identificação.
3. Repetir a comparação de engine no mesmo D.C. e com protocolo novo, preservando
   este piloto. Qualquer adaptação do orçamento ou dos diagnósticos deve ser
   prospectiva e justificada, nunca escolhida para obter aprovação retroativa.
4. Completar a replicação externa e os testes de identificação/heterogeneidade
   legítima antes de escolher o alvo de produção para Brasil 2022. O exemplo dos
   autores tem dados e código públicos, mas ainda falta uma saída numérica externa
   congelada para certificar a reprodução de um resultado publicado.

Não iniciamos esses novos ajustes neste lote. G3 permanece inconclusivo, G10
permanece pendente, e os gates de escala/produção brasileiros não foram liberados.
O ensaio de ingestão de 2026 não é uma análise eleitoral de 2026. Não houve
instalação, exclusão de arquivos ou edição do modelo A.
