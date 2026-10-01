# Dicionário da referência numérica B1

Fonte fixa: `archive/Bolivia2019.pdf`, SHA-256
`ddcdb42bebf8160abf80b6c189db37951db8ead7f0f763d5469423778f870fb7`.
O PDF tem 36 páginas; a capa é a página PDF 1, sem número impresso, e
`printed_page = pdf_page - 1` para todas as células extraídas. O CSV é gerado
por `python3 extract_reference.py`, usando `pdftotext -layout` e uma exigência
de 51 registros. Os números são strings dos algarismos publicados, sem
arredondamento nem cálculo de novas estimativas.

## Escopo das 51 linhas

| Bloco | Páginas impressas (PDF) | Registros | Fase e comando |
|---|---:|---:|---|
| 4 cadeias x 9 parâmetros globais | 30-31 (31-32) | 36 | Amostra final: `summary(efout)` após `Estimation Completed` e `save(efout, ...)` na p. 29 (PDF 30). |
| 9 parâmetros globais combinados | 34 (35) | 9 | Pós-processamento: carrega `runef4_Bolivia2019Clean_4c.RData` e chama `summary(efout, join.chains=TRUE)`. |
| 2 funcionais de votos x 2 níveis | 35 (36) | 4 | Pós-processamento: `effrauds_obs(dat, efout)` e vetor `evec` rotulado `COMBO`. |
| 2 contagens de classificação | 35 (36) | 2 | Pós-processamento: `print(v)` sob `COMBO`. |

As páginas impressas 26-28 (PDF 27-29) mostram a etapa anterior de 2.000
iterações de verificação por cadeia e a nova etapa de 2.000 amostras finais;
não publicam ali outra tabela de parâmetros globais. A mensagem `# A tibble:
0 x 4` do diagnóstico MCMCSE na p. 29 não certifica convergência. `n.iter=2000`
na chamada da p. 26 não deve ser lido como total de todo o fluxo.

## Colunas do CSV

- `record_id`: chave única estável; a linha de resumo global termina no número
  de linha impresso de 1 a 9.
- `phase`: `final_draws_summary`, `postprocessing_joined_chains` ou
  `postprocessing_fraud_functional`; não intercambiáveis.
- `source_section`: nome do log reproduzido no PDF.
- `chain`: cadeia 1-4 ou `combined` para o resumo/post-processamento conjunto.
  `combined` não é uma quinta cadeia independente.
- `parameter`, `covariate`: identificador e rótulo impressos; `pi[1:3]`
  correspondem a No Fraud, Incremental Fraud e Extreme Fraud. Os seis `beta.*`
  são interceptos.
- `statistic`: `posterior_mean` quando `estimate` é média; ou
  `classified_mesas_count`, uma contagem sem erro-padrão ou intervalo.
- `estimate`, `sd`, `interval_lower`, `interval_upper`: strings numéricas como
  impressas. `sd` é desvio-padrão do resumo de amostras, **não** MCSE.
  Campo vazio significa não publicado ou não aplicável, nunca zero.
- `interval_level`: probabilidade nominal decimal, 0.95 ou 0.995; vazio
  para contagens.
- `interval_type`: `HPD` nas tabelas globais, pois os cabeçalhos dizem
  `HPD.lower/upper`. O nível 95% é inferido da chamada sem `prob` ao
  `coda::HPDinterval` em `archive/ef_summary_3017de5.R`, cujo padrão é 0,95;
  o commit instalado na Bolívia não foi publicado. Para os totais,
  `credible_unspecified`: o PDF usa `95` e `995` e chama o intervalo de
  credibilidade, mas não informa se é HPD, caudas iguais ou outro cálculo.
  `not_applicable` nas contagens.
- `unit`: parâmetro, votos ou mesas.
- `pdf_page`, `printed_page`, `source_locator`: localizador reabrível da célula.
- `definition_status`, `notes`: limite de identificação. A definição
  operacional dos funcionais e da classificação depende de scripts externos
  ainda não localizados.

## Definições dos agregados

`Nfraudtotalmean`/`Ntotal95`/`Ntotal995` são o total de votos modelados como
fraudulentos para MAS. A p. 1 (PDF 2) arredonda a média 22519.818 para
22519.8 e o intervalo de 99,5% [20479.794, 24663.779] para
[20479.8, 24663.8]. `Ntfraudtotalmean`/`Nttotal95`/`Nttotal995` referem-se
à parcela manufaturada a partir de abstenções: a p. 1 arredonda 5295.798
para 5295.8 e [4751.090, 5880.218] para [4751.1, 5880.2]. Esses são
totais posteriores da função de pós-processamento, não médias de `pi` e
não estatísticas de uma cadeia individual. Os intervalos de 95% também
estão na p. 35 (PDF 36), embora a p. 1 destaque 99,5%.

O log imprime 34.277 mesas `no fraud` e 274 `fraud`, somando 34.551. O
código visível obtém `n` da primeira dimensão de
`elist$CIcombo[["all"]][["Nfraud95"]]`; sem `obsfrauds_ciS.R` e `wrkef.R`,
a regra exata que põe uma mesa nesse subconjunto é **desconhecida**. A
associação entre 274 e mesas com contagens fraudulentas é afirmada pelo
texto da p. 2 (PDF 3), mas não deve ser tratada como validação do algoritmo.

As Tabelas 1-18 são saídas por mesa, não tabelas de resumo de parâmetros
globais e não foram transcritas neste alvo B1. Células truncadas das linhas
de código na p. 35 não foram reconstruídas: o CSV captura somente as linhas
de saída legíveis. A inspeção visual do executor cobriu PDF 31, 32, 35 e 36;
o revisor separado ainda precisa conferir a transcrição.
