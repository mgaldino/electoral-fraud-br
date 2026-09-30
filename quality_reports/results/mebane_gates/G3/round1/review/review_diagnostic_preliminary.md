# Finding delimitado: G3-QA-R2-DIAG-01

**Defeito major confirmado; reparo somente de pós-processamento.** Alias da coordenação: `G3-COORD-DIAG-01`. Este finding pede correção do candidato, mas não constitui o parecer final do gate.

Revisor: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`. Executor: `01a0ee04-c901-7831-8ac6-0160da2e3883`.

- Manifesto revision2: `de779221e40964b9729bdd928a814e7e7dfd9738df866b91f6ee97307a14bd0f`.
- RDS congelado: `66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d`.
- Contraprova JSON: `d7441f10f448121dc472c02a87bac76e8eb11bbf375c9c3db465f010b0f30b15`.

## Localização e efeito

O snapshot `revision2/snapshots/tests/mebane/likelihood/g3_draw_postprocess.R`, linhas 87–91, SHA `d3a488bd3694eeb9b0545fbae66977dd4c9dbc91de43b41f4401c001683e4ec2`, passa `draws_array` às funções escalares de diagnóstico. O mesmo padrão aparece no snapshot de `g3_jags.R` de revision1, linhas 158–162.

No `posterior` 1.7.0 instalado, `.split_chains()` chama `as.matrix()`. A entrada `2000 × 4 × 1` torna-se `8000 × 1` e é dividida em `4000 × 2`. A forma correta, com quatro cadeias originais, é `2000 × 4`, dividida em `1000 × 8`. A operação errada altera a comparação entre cadeias e pode esconder desacordo entre elas. Os onze alvos não constantes publicados reproduzem exatamente esse caminho errado.

| Alvo e estatística | Publicado, cadeias concatenadas | Correto, quatro cadeias |
|---|---:|---:|
| N.iota.s, Rhat | 1.00020832622997 | 1.00120757086769 |
| N.iota.s, ESS bulk | 5930.43967667792 | 5984.97063394254 |
| Z, ESS tail | 4477.53299137056 | 4495.26249801662 |

## Contraprova e reparo seguro

O script independente `final_checks/diagnostic_shape_counterexample.R` lê somente o RDS congelado e contrapõe as duas formas. Os resultados completos e o código das funções instaladas estão em `diagnostic_shape_counterexample/`; não houve nova amostragem.

```r
# x: iterações nas linhas, quatro cadeias nas colunas
stopifnot(is.matrix(x), identical(dim(x), c(2000L, 4L)))
posterior::rhat(x)
posterior::ess_bulk(x)
posterior::ess_tail(x)
```

O reparo deve salvar novos resultados e uma regressão determinística adversarial de separação entre cadeias em revision3, preservando revision2. Não requer MCMC, seed nova, mudança de modelo ou tolerância. Nenhum arquivo do candidato foi alterado por QA.

**Limite que permanece:** nove ESS de cauda continuam indefinidos na forma correta porque o indicador de quantil de cauda é constante nos alvos discretos. Isso não prova falta de convergência, mas o critério congelado não foi satisfeito. `S=0` é uma constante no suporte condicionado positivo e recebe tratamento analítico separado. O reparo não resolve F1/F2 nem valida produção.

A coordenação já confirmou o alias em `diagnostic_shape_adjudication.json`, SHA `4b22c41804b4421f765229b0d85c60b3c38073ca1aaecad86dd7a7b98f499c84`. Esse registro delimita a autorização; a evidência do defeito é a contraprova independente.
