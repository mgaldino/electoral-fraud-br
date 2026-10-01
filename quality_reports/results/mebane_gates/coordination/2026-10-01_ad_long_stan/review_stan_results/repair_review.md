# Revisão independente do reparo de representação Stan

**Status: PASS restrito ao reparo.** Nenhum achado bloqueante na candidata congelada. O bloco local de normalização preserva os dados e elimina a dependência do despacho S3 na extração das quatro cadeias. Este parecer não aceita os resultados numéricos de `stan_diagnostics02`, a comparação ou o PDF.

Revisor: `01a0f717-7535-72e3-baf8-4db20da81abb`, diferente dos executores `019d795a-acfa-72c2-a210-d55a46c606c2` e `01a0f4b5-4434-7b83-91b9-69ced11b40ba`. Emitido em 2026-10-01, 11:58:40 UTC. A autorização utilizada foi exclusivamente a janela de QA do reparo. O goal maior permanece ativo.

## Candidata Vinculada

Manifesto: `../stan_diagnostic_repair_candidate.json`, SHA-256 `cd9540e5df61933740a61c65800b63030163c045f539e593c73f8f2c96abf78b`.

O wrapper `R/experimental/mebane_ad_long/postprocess_stan_v2.R`, SHA-256 `c9942429e543e521c83db799166b470fab32cf793c27b5afd737240546efb5e0`, difere do original somente no próprio caminho de snapshot, linha 13, e no bloco das linhas 24–32. Remover esse bloco e restaurar o caminho produz texto exatamente igual ao original congelado. O supervisor v2, SHA-256 `80587de9b918f15a1b705ee15b772575a08474f2c5e661d4f3207ca362a47f34`, altera somente o caminho Rscript na linha 19.

Foram reconferidos os manifestos da preparação (`2ad3246c…789bfb`), do adaptador original (`3562d593…8bb08b0`) e da amostragem (`99fd59f1…06f151`), incluindo os fontes congelados. Modelo Stan, fonte JAGS D, script de amostragem, contratos, critérios, bridge e adaptador continuam byte-idênticos às entradas vinculadas. Os hashes completos e os caminhos estão em [repair_review.json](repair_review.json) e [input_binding.json](repair_checks01/input_binding.json).

## Evidência Executada

Passaram **115/115 verificações de vínculo, hashes, diff e execução**, além de **52/52 verificações independentes de representação**. Os 84 arquivos vinculados permaneceram com o mesmo hash antes e depois. A tentativa falha foi preservada, inclusive log, supervisor, inventário de arquivos e snapshots.

| Verificação | Evidência observada |
|---|---|
| Draws originais | `2000 × 4 × 4890`; classes `draws_array`, `draws`, `array` |
| Sampler original | `2000 × 4 × 6`; mesmas classes |
| Extração antes de carregar `posterior` | `as.matrix()` de uma variável retorna `2000 × 4` nos dois objetos |
| Extração após `loadNamespace("posterior")` | A mesma operação retorna `8000 × 1` nos dois objetos |
| Normalização v2 | Mantém a matriz `2000 × 4`, independentemente da ordem de carga do namespace |
| Preservação integral | Igualdade exata de 39.120.000 valores dos draws e 48.000 do sampler, dimensões, nomes e ordem linear |
| Objetos e arquivos originais | Hashes dos objetos R e SHA-256 dos RDS idênticos antes/depois |
| Fixture com classe real | `posterior::as_draws_array`, coordenadas determinísticas distinguindo variável, cadeia e iteração |
| Diagnóstico da fixture | A extração antiga é rejeitada; três linhas de métricas normalizadas e suas quatro médias de cadeia coincidem com cálculo independente |
| Extrações internas | Todas as 860 extrações do adaptador preservam forma, valores e ordem na fixture; o teste usa um verificador substituto de forma/valores, sem calcular diagnósticos empíricos |
| Critérios | Sentinelas confirmam `Rhat < 1.01`, ESS bulk/tail `>= 400`, faixa `<= 0.05` e falha quando há NA |

O teste executou as cinco expressões reais do bloco de normalização, extraídas da árvore sintática do wrapper. Somente a escrita de metadados foi substituída por captura em memória. O pós-processador completo não foi chamado. A fixture é implementação independente desta revisão; o teste do executor foi lido e vinculado por hash, mas não usado como substituto da verificação independente.

**Defeito original confirmado e reparado, REP-01.** A localização da falha é `R/experimental/mebane_ad_long/stan_bridge.R:47`: a extração S3 fornece uma coluna em vez das quatro exigidas por `ad_diagnostic_row()`. O log preservado `../stan_diagnostics01.log` registra exatamente `ncol(x) == 4L is not TRUE`. O caminho Rao-Blackwellizado, `postprocess_stan_v2.R:38`, usa a mesma operação de extração e recebe agora o array normalizado na fronteira, linhas 27–28.

A nuance do namespace foi reproduzida em processo R limpo. No fluxo real, `diagnostics_stan.R:4` já exige o namespace `posterior` durante o carregamento dos fontes. Portanto, um probe isolado que apenas lê o RDS antes de carregar o pacote pode parecer correto e não representar o comportamento efetivo do wrapper. O teste independente verificou explicitamente ambos os estados.

Hashes preservados dos brutos: draws `682bcc18ab392004be25c9a87abb52f4fb299e53eb53d5f536ff9ba267f2a15a`; sampler `bdc58529fa1f3a51c0b522e0b818bf35c0fe0c988aa67da866945e49aecfee15`. O supervisor da tentativa 01 mantém retorno 1, sem timeout, e `11.42581279197475 s` de tempo externo; esse custo não foi apagado nem convertido em execução produtiva.

## Limites e Próxima Etapa

- O PASS cobre o reparo local e a preservação dos inputs, não a correção numérica integral ou a convergência dos resultados de `stan_diagnostics02`. O código posterior às linhas 32 do wrapper não foi executado em bloco por este revisor.
- As 860 extrações foram verificadas na fixture com uma função substituta que confere forma e conteúdo. Os 860 Rhat/ESS empíricos, os 23 globais, HMC e as 1.742 decisões comuns continuam pendentes da QA de resultados.
- Igualdade dos valores e da ordem existente nos RDS não certifica ainda sua correspondência aos CSVs, sementes ou funcionais. Esses vínculos pertencem à próxima revisão.
- O R emitiu avisos de locale e utilizou `C`; as verificações numéricas e de nomes ASCII passaram. Não houve instalação ou alteração de locale.
- Comparação, tempos produtivos versus tentativa falha e inspeção visual do PDF não eram requisitos deste marco e não foram revisados. O harness antigo da QA final não foi executado.

Não houve MCMC, novos draws empíricos, resampling, compilação, instalação, exclusão ou edição das candidatas. A decisão técnica fica disponível para adjudicação pelo coordenador; não encerra o goal da entrega final nem libera produção ou gates históricos.

## Reprodução e Arquivos

```sh
python3 quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review_stan_results/run_repair_checks.py --released-scope diagnostic-repair-only --attempt repair_checksNN
```

`repair_checksNN` deve ser um diretório novo; nunca sobrescrever a tentativa 01. Uma repetição depende de janela de execução autorizada. Scripts: [repair_checks.R](repair_checks.R) e [run_repair_checks.py](run_repair_checks.py). Evidências: [representation_checks.json](repair_checks01/representation_checks.json), [preservation_checks.json](repair_checks01/preservation_checks.json), [scoped_source.diff](repair_checks01/scoped_source.diff) e [checks_manifest.json](repair_checks01/checks_manifest.json). O manifesto das checagens tem SHA-256 `c762e2324ded089abd639b76cee944d22a57c9aa9636c2d0072a4c50ae5e20a5`.
