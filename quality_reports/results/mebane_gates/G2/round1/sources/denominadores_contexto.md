# Eleitorado, votos depositados e votos válidos no eforensics

Data da checagem: 28 de setembro de 2026 (America/Sao_Paulo).

## Resultado e escopo

A checagem não confirmou que usar comparecimento como `V_i` seja um erro em relação ao eforensics de Mebane. A definição geral do artigo de 2023 usa votos depositados (*votes cast*), e há uma aplicação que inclui expressamente votos em branco. Há também evidência textual de uma aplicação que inclui votos classificados como inválidos, com a limitação de acesso descrita abaixo.

Isso sustenta a existência de precedente para nossa codificação, não sua superioridade nem sua validade empírica no Brasil. Não estabelece uma regra universal de inclusão de brancos e nulos. O pacote aceita as contagens fornecidas pelo usuário, mas não decide sua interpretação substantiva.

O pedido foi verificar e documentar os denominadores. Nenhum modelo foi reestimado; não foram alterados dados, scripts analíticos, priors, dependências ou decisões dos gates. A inclusão desta nota não equivale à aprovação de um gate ou de um resultado nacional.

## 1. A dúvida e as fontes

### Artigo secundário: Kalinin (2022)

Kalinin descreve `V_i` como o número de votos válidos. Se essa definição for adotada para a eleição presidencial brasileira, brancos e nulos ficam fora de `V_i`. Entretanto, essa frase isolada não determina uma convenção universal do eforensics e não deve substituir a consulta ao modelo e às aplicações de Mebane.

Referência: KALININ, Kirill. *An Empirical Comparison of Parametric and Nonparametric Methods Applied to the Measurement of Election Fraud*. Manuscrito de 1 de abril de 2022, preparado para a Annual Meeting of the Midwest Political Science Association, Chicago, 7–10 de abril de 2022. [SSRN 4073770](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4073770). Cópia local: `ssrn-4073770.pdf`.

### Artigo primário: Mebane (2023)

Na seção 2.1, p. 5 da numeração impressa, Mebane define:

- `N_i`: número de pessoas aptas a votar na unidade eleitoral;
- `W_i`: votos para o líder, isto é, a alternativa analisada pelo modelo;
- `V_i`: número de votos depositados (*votes cast*);
- `A_i = N_i - V_i`: abstenções;
- `O_i = V_i - W_i`: votos da oposição, como categoria residual.

A definição geral não usa a expressão *valid votes*. Mais decisivamente, na seção 3.4, p. 31, sobre o primeiro turno argentino de 2015, o autor afirma: “Blank votes are included as votes cast”. Portanto, nesse caso os votos em branco entram em `V_i`, e não em `A_i`.

Há uma cautela textual adicional: notas de tabelas do próprio artigo, inclusive a tabela 24 sobre a Argentina, usam a expressão *valid votes*. Assim, a terminologia não é uniforme. A afirmação explícita sobre a inclusão de brancos é evidência mais específica que o rótulo genérico das tabelas; não se deve inferir a codificação de todas as aplicações apenas desse rótulo.

Referência: MEBANE, Walter R., Jr. *Lost Votes and Posterior Multimodality in the eforensics Model*. Versão de 2 de julho de 2023; versão original de 29 de junho de 2023. Preparado para PolMeth 2023, Stanford University, 9–11 de julho de 2023. [PDF do autor](https://websites.umich.edu/~wmebane/pm23.pdf). Cópia local examinada: `quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf`. As passagens relevantes foram conferidas no texto extraído da cópia local, não apenas em resultados de busca.

### Evidência complementar: votos inválidos na Turquia

No relatório *eforensics Analysis of the Turkish 2023 Presidential Election*, a discussão do referendo de 2017, p. 3, inclui votos classificados como inválidos no total depositado. O autor justifica a escolha pelo voto obrigatório e pela hipótese de que esses votos incluem votos em branco, distinguindo-os da não participação.

O trecho indexado informa 49.651.009 votos depositados: 25.075.936 em “Yes”, 23.715.116 em “No” e 859.957 inválidos. Essa evidência mostra uma escolha contextual do autor. A categoria turca de inválidos não deve ser equiparada automaticamente à categoria brasileira de nulos; a discussão é sobre sua inclusão no agregado de participação.

Referência: MEBANE, Walter R., Jr. *eforensics Analysis of the Turkish 2023 Presidential Election*. 2023. [PDF do autor](https://websites.umich.edu/~wmebane/Turkey2023.pdf), p. 3. Acesso em 28 de setembro de 2026: passagem recuperada por busca no texto indexado do PDF hospedado pelo autor. O acesso direto ao PDF falhou; o documento completo não foi inspecionado nem arquivado nesta checagem. A referência é corroborativa: o resultado principal sobre a ausência de uma regra universal de exclusão de brancos já é sustentado pelo PDF local de Mebane (2023).

## 2. O pacote instalado e os scripts locais

Foi inspecionado `eforensics` 0.0.4, de `UMeforensics/eforensics_public`, commit `3017de537450f97a01872d0157462a68bea348ee`. Referência de software: [repositório nesse commit](https://github.com/UMeforensics/eforensics_public/tree/3017de537450f97a01872d0157462a68bea348ee).

A documentação descreve respostas de votos para o líder e abstenções, além do número de eleitores aptos. Na função interna `eforensics_main_par`, as respostas extraídas das fórmulas são repassadas como `w` e `a`, e `eligible.voters` fornece `N`. Não há uma entrada separada para brancos/nulos nem uma recodificação automática dessas categorias.

No modelo `qbl`, `a[j]` e `w[j]` entram em distribuições binomiais com `N[j]` tentativas. No componente sem fraude, a probabilidade de voto no líder é `mu.nu[j] * (1 - a[j]/N[j])`. Logo, a escolha de `a` altera tanto a medida de participação quanto a interpretação da probabilidade de escolha do líder. O fato de o modelo aceitar uma contagem não valida a decisão de codificação.

O diagnóstico JAGS em `R/05_eforensics_qbl_fresh_diagnostic.R`, linhas 57–69, usa `N = first(QT_APTOS)`, `comparec = first(QT_COMPARECIMENTO)`, `a = N - comparec` e `w` igual aos votos em Lula. `R/05_stan_eforensics_qbl_calibrate.R`, linhas 117–123, usa a mesma construção de `N` e `a`. Essa coincidência das entradas não demonstra equivalência entre as duas implementações probabilísticas.

Tabela 1. Correspondência das quantidades na codificação atual. A unidade é a seção eleitoral em um turno; todas as quantidades são contagens.

| Quantidade | Correspondência local | Interpretação |
|---|---|---|
| `N_i` | `QT_APTOS` | Eleitores aptos, inclusive ausentes |
| `V_i` implícito | `QT_COMPARECIMENTO` | Comparecimento, incluindo brancos e nulos |
| `A_i` | `QT_APTOS - QT_COMPARECIMENTO` | Abstenções efetivas |
| `W_i` | Votos no candidato analisado | No diagnóstico citado, Lula |
| `O_i` implícito | `QT_COMPARECIMENTO - W_i` | Votos nos demais candidatos, brancos e nulos |

Fonte: inspeção dos scripts e do pacote instalado em 28 de setembro de 2026. A decomposição de comparecimento foi conferida contabilmente para Brasília, segundo turno, na seção seguinte.

## 3. Verificação das contagens

A base examinada foi `data/processed/brasil_2022_secao_clean.parquet`. As quantidades da seção se repetem nas linhas de candidatos. Para verificar os totais, foram selecionadas apenas as chaves e as quantidades, removendo as repetições idênticas. A chave foi `(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO)`; não foram encontrados registros conflitantes para a mesma chave nessa seleção.

Tabela 2. Checagem de eleitorado e participação na base limpa existente. Cada observação é uma seção-turno; isso não é uma reconciliação da cobertura com um novo extrato oficial do TSE.

| Turno | Seções-turno | Ausências em aptos/comparecimento/abstenções | Violações de `aptos = comparecimento + abstenções` |
|---|---:|---:|---:|
| 1 | 472.024 | 0 | 0 |
| 2 | 472.027 | 0 | 0 |
| Total | 944.051 | 0 | 0 |

Fonte: leitura direta do parquet em R, com `Rscript --vanilla`, `arrow` e `data.table`. Não foram encontrados valores negativos nos três campos ou comparecimento superior ao eleitorado. Essa verificação não certifica todas as demais colunas, exclusões ou escolhas do pipeline.

Tabela 3. Totais observados de Brasília no segundo turno de 2022, nas 6.748 seções da base limpa. Filtro: `CD_MUNICIPIO == 97012` e `NR_TURNO == 2`.

| Quantidade | Contagem |
|---|---:|
| Eleitores aptos | 2.207.628 |
| Comparecimento | 1.838.492 |
| Votos nominais válidos | 1.770.626 |
| Brancos | 29.663 |
| Nulos | 38.203 |
| Abstenções | 369.136 |

Fonte: mesmo parquet. O resíduo de `comparecimento - nominais - brancos - nulos` foi zero em cada uma das 6.748 seções, além de ser zero no agregado. Essa seleção não apresentou campos ausentes ou chaves conflitantes. A checagem dessa decomposição relatada aqui foi restrita a Brasília, segundo turno.

Na codificação atual, a soma de `A_i` é 369.136. Se `V_i` fosse redefinido como apenas os 1.770.626 votos válidos, a soma de `A_i = N_i - V_i` seria 437.002: abstenções mais 67.866 votos brancos e nulos. Nessa alternativa, `A_i` deixaria de representar apenas ausência à seção e passaria a representar ausência de voto válido. Isso é uma mudança de interpretação, não uma correção aritmética inócua.

## 4. Implicações e limites

1. Não há fundamento, nesta checagem, para substituir automaticamente comparecimento por votos válidos sob a alegação de que Mebane sempre exige essa exclusão.
2. A codificação atual agrupa brancos e nulos com os votos que não foram para o líder. Isso não afirma que esses eleitores apoiem politicamente a oposição. É a categoria residual do modelo binário.
3. A escolha afeta a interpretação dos mecanismos: com comparecimento, uma transferência desse grupo residual ao líder entra conceitualmente no mecanismo de votos roubados; com votos válidos, brancos e nulos compõem o conjunto de não votos válidos do qual o modelo pode representar votos fabricados. O modelo não identifica separadamente cada origem desses votos.
4. Precedentes do autor e execução sem erro não demonstram adequação ao Brasil, convergência das cadeias, ausência de viés ou robustez das estimativas. Nenhuma dessas propriedades foi testada aqui.
5. Uma comparação futura entre as codificações deve manter amostra, candidato, covariáveis e especificação probabilística comparáveis, tratar explicitamente seções sem votos válidos e verificar convergência separadamente. Ainda não foi executada e não se presume que produzirá resultados semelhantes.
6. Para 2026, não se presume que os arquivos ou o tratamento de registros especiais sejam idênticos aos de 2022. Os conceitos devem ser mapeados ao esquema e às regras dos dados efetivamente obtidos.

## 5. Identificação dos artefatos inspecionados

Tabela 4. SHA-256 dos arquivos locais usados para vincular esta checagem aos bytes inspecionados. Hash não substitui validação da fonte ou dos dados.

| Arquivo | SHA-256 |
|---|---|
| `data/processed/brasil_2022_secao_clean.parquet` | `af9795bb2b5065c1f2386e5c426c8fee54cd16126426e16b5da1a022944ef413` |
| `quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf` | `615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431` |
| `R/05_eforensics_qbl_fresh_diagnostic.R` | `9faf09a91562adef904d94192c734de76e8741a172f68b73e7f1c095c0823a87` |
| `R/05_stan_eforensics_qbl_calibrate.R` | `1892b565f942e247fb5a6a2d5f2cfa4e53bc99f064d9a6216df202c8e611ebf9` |

Os caminhos desta nota são relativos à raiz do repositório. Não foi reconstruída a aquisição histórica dos dados, não foi executado MCMC e não se avaliou a sensibilidade posterior à escolha do denominador.

## 6. Revisão crítica com devils-advocate

Procedimento: aplicação local da skill `devils-advocate`, com leitura crítica da nota antes da entrega e nova checagem das contagens em R. A conversa lateral proíbe interação com subagentes; a revisão foi realizada pelo mesmo assistente em uma etapa separada. Portanto, não é uma revisão independente e não substitui a checagem independente prevista nos gates. A entrega permaneceu em Markdown por ser documentação do repositório ligada ao README.

### Vulnerabilidade principal

A existência de aplicações em que Mebane inclui brancos ou inválidos não demonstra que essa seja a codificação empiricamente mais adequada para o Brasil. O argumento sobrevive somente com o alcance delimitado: não se confirmou uma obrigação universal de excluir essas categorias e, por isso, a passagem de Kalinin não basta para exigir uma alteração automática dos scripts.

### Ataques por dimensão e resposta documental

1. **Lógica interna e generalização, importância alta:** a regra universal de excluir brancos é refutada pelo exemplo argentino, mas isso não prova a regra universal contrária. A nota rejeita expressamente ambas as generalizações. Não há bloqueio documental remanescente nesse ponto.
2. **Mecanismo e interpretação, importância alta:** incluir brancos e nulos no grupo residual não os transforma em apoio político aos adversários. A seção 4 explicita essa diferença e a mudança na interpretação dos mecanismos ao trocar a codificação. A adequação empírica desse agrupamento permanece sem teste.
3. **Evidência e proveniência, importância média:** a passagem turca foi recuperada do índice de busca, não da leitura integral do PDF. A nota identifica a limitação, distingue inválidos turcos de nulos brasileiros e usa a passagem como corroboração, não como prova de adequação ao Brasil. Conferir e arquivar a fonte completa permanece pendente.
4. **Verificação numérica e escopo, importância média:** identidades no agregado poderiam ocultar resíduos de sinais opostos entre seções. Na revisão, a decomposição de Brasília foi verificada também por seção e não apresentou violações. A identidade de eleitorado foi novamente testada nos 944.051 registros seção-turno; a cobertura da base contra controles oficiais não foi certificada por esses testes.
5. **Evidência contrária e literatura, importância média:** o termo *valid votes* aparece tanto em Kalinin quanto em notas de tabelas de Mebane. A nota preserva essa tensão terminológica e fundamenta a conclusão na definição e no exemplo explícito, sem apresentar uma revisão exaustiva de todas as versões ou aplicações do eforensics.

### O que sobrevive ao escrutínio

A separação entre aptos, comparecimento e votos válidos está documentada; o mapeamento dos scripts corresponde ao código inspecionado; os números relatados passaram por nova checagem com asserções em R; e há evidência primária local de inclusão de votos em branco em uma aplicação de Mebane. Não foi identificado bloqueio para publicar esta nota interna com suas ressalvas. Continuam pendentes a avaliação empírica da codificação no Brasil, a inspeção integral da fonte turca e a revisão por um verificador independente.
