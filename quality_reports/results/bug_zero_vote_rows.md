# Bug TSE: linhas QT_VOTOS = 0 omitidas em `votacao_secao_YYYY_BR.csv`

**Data da descoberta**: 2026-04-10
**Contexto**: Bloco 1 (reconstrucao metodologica electoralFraud, 2022)
**Impacto**: data quality, forward-looking para qualquer analise futura com dados TSE (2018, 2014, etc.)
**Status**: CORRIGIDO em `R/01_load_tse.R` (passo 4.5)

## 1. O problema

O arquivo `votacao_secao_YYYY_BR.csv` publicado pelo TSE (repositorio de dados abertos) **nao reporta linhas** para combinacoes `(secao, turno, candidato)` em que `QT_VOTOS = 0`. Candidatos que receberam zero votos nominais em uma secao sao simplesmente omitidos da tabela daquela secao. O CSV funciona como uma lista esparsa de votos nao-zero, nao como uma matriz densa `secao x candidato`.

Isto **nao** e' um bug de exportacao — e' uma decisao de formato do TSE, valida desde pelo menos 2018 e observada no dataset de 2022. Mas e' um missing silencioso: o arquivo nao sinaliza de nenhuma forma que faltam linhas, e nenhuma mensagem de warning e' emitida na leitura.

## 2. Por que isso e' grave

### 2.1 Quebra identidade formal no 2o turno

No 2o turno presidencial (so dois candidatos nominais: 13 e 22, mais branco/nulo), `QT_VOTOS_NOMINAIS = QT_VOTOS_13 + QT_VOTOS_22` para cada secao. Consequentemente:

$$\text{vote\_share\_nominais}_{13} + \text{vote\_share\_nominais}_{22} = 1$$

Se o candidato 13 tem vote share 100% numa secao, o candidato 22 tem obrigatoriamente vote share 0%. Mas com o CSV esparso, a linha do candidato 22 com `QT_VOTOS = 0` nao existe no arquivo — portanto nao aparece no parquet, e a secao de 0% do candidato 22 desaparece da analise. Quem tenta verificar a identidade quebra:

```
Lula T2 == 1.0 : 141 secoes    (observado no parquet esparso)
Bolso T2 == 0.0:   0 secoes    (deveria ser 141; sao 0)
```

### 2.2 Distorce a cauda baixa do fingerprint

Em eleicoes com muitos candidatos (1o turno), minor candidates (Ciro, Tebet, Soraya, etc.) aparecem com vote share 0 em muitas secoes do pais. Sem densificacao, essas secoes somem do registro do candidato menor. O fingerprint 2D entao **subestima a massa** proxima de `vote_share = 0` para esses candidatos, criando a ilusao de que a cauda inferior e' menos povoada do que realmente e'.

Para os dois candidatos principais (Lula e Bolsonaro), o efeito e' menor — eles raramente recebem zero votos em secoes populosas — mas ainda existe em ~100-150 secoes do Nordeste rural (Lula dominante) e em algumas secoes isoladas (Bolsonaro dominante).

### 2.3 Contamina analises cross-candidato

Qualquer analise que compare N, distribuicao ou propriedades entre candidatos esta sujeita a vies sistematico: candidatos menores tem menos linhas do que deveriam, e a diferenca nao e' aleatoria — e' correlacionada com regioes e perfis de secao especificos (sertao, regioes isoladas).

### 2.4 Impacto empirico no dataset de 2022

Na base bruta do TSE 2022 (presidencial, turnos 1 e 2):

| metrica | valor |
|---|---:|
| linhas no `votacao_secao_2022_BR.csv` apos filtro presidente + T1/T2 | 5.380.736 |
| linhas esperadas (matriz densa) | 8.025.275 |
| linhas faltando (candidatos com 0 votos omitidos) | 2.644.539 |
| fracao do universo dense que faltava | ~33% |

Um terco da matriz dense estava ausente do arquivo bruto. Apos densificacao, todos os 11 candidatos do 1o turno tem exatamente o mesmo N de secoes (471.010 no Brasil), e a identidade `Lula_100% <=> Bolsonaro_0%` no 2o turno passa a valer.

## 3. Como detectar o bug em qualquer ano

Tres sanity checks sao suficientes:

### Sanity check A: contagem por candidato-turno

```r
votacao[, .N, by = .(NR_TURNO, NR_VOTAVEL)]
```

Se os `N` forem diferentes entre candidatos no mesmo turno, o CSV esta esparso (bug presente). Se todos os `N` do mesmo turno forem iguais, o CSV ja esta denso.

Dado TSE historico: **sempre esparso**. Esperar bug presente.

### Sanity check B: mirror do 2o turno (presidencial)

No turno 2 com 2 candidatos nominais (13 e 22):

```r
t2 <- merged[NR_TURNO == 2]
n13_100 <- t2[NR_VOTAVEL == 13 & vote_share_nominais == 1, .N]
n22_0   <- t2[NR_VOTAVEL == 22 & vote_share_nominais == 0, .N]
stopifnot(n13_100 == n22_0)
```

Se `n22_0 == 0` mas `n13_100 > 0`, bug presente (o parquet nao tem linha para Bolsonaro nas secoes onde ele teve 0).

### Sanity check C: dimensoes do cross-join esperado

```r
n_secoes_t1 <- detalhe[NR_TURNO == 1, .N]
n_secoes_t2 <- detalhe[NR_TURNO == 2, .N]
n_cand_t1   <- uniqueN(votacao[NR_TURNO == 1, NR_VOTAVEL])
n_cand_t2   <- uniqueN(votacao[NR_TURNO == 2, NR_VOTAVEL])
n_expected  <- n_secoes_t1 * n_cand_t1 + n_secoes_t2 * n_cand_t2
n_actual    <- nrow(votacao)
stopifnot(n_actual == n_expected)  # falha se bug presente
```

## 4. A correcao (reutilizavel para qualquer ano)

Inserir este passo apos o filtro de cargo+turno e **antes** do merge com `detalhe_votacao`:

```r
# Universo de secoes-turno (detalhe_votacao e' denso por construcao)
secao_universe <- detalhe[, .(ANO_ELEICAO, NR_TURNO, SG_UF, CD_MUNICIPIO,
                              NM_MUNICIPIO, NR_ZONA, NR_SECAO,
                              CD_CARGO, DS_CARGO)]

# Universo de candidatos por turno (quem apareceu em ao menos uma secao)
cand_universe <- unique(votacao[, .(NR_TURNO, NR_VOTAVEL, NM_VOTAVEL)])

# Cross-join sobre NR_TURNO
votacao_dense <- merge(secao_universe, cand_universe,
                       by = "NR_TURNO", allow.cartesian = TRUE)

# Left-join com votos reais
votacao_actual <- votacao[, .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO,
                              NR_TURNO, NR_VOTAVEL, QT_VOTOS)]
votacao_dense <- merge(votacao_dense, votacao_actual,
                       by = c("SG_UF","CD_MUNICIPIO","NR_ZONA",
                              "NR_SECAO","NR_TURNO","NR_VOTAVEL"),
                       all.x = TRUE)

# Preencher zeros
votacao_dense[is.na(QT_VOTOS), QT_VOTOS := 0L]

# Substituir e liberar memoria
votacao <- votacao_dense
rm(votacao_dense, secao_universe, cand_universe, votacao_actual)
invisible(gc())
```

Implementacao na pratica: ver `R/01_load_tse.R`, passo 4.5.

### Validacao pos-fix

Apos rodar a densificacao, rodar os tres sanity checks acima. Os tres devem passar:
- A: todos os N iguais por candidato dentro do mesmo turno
- B: `n13_100 == n22_0`
- C: `n_actual == n_expected`

Se qualquer falhar, a correcao nao foi aplicada corretamente.

## 5. Observacoes importantes

### 5.1 `detalhe_votacao_secao` NAO tem o bug

O segundo CSV do TSE (`detalhe_votacao_secao_YYYY_BR.csv`) reporta uma linha por `(secao, turno)` com os totais (aptos, comparecimento, nominais, brancos, nulos). Esse arquivo e' denso — nao faltam secoes. O bug e' **exclusivo** do arquivo de votos por candidato (`votacao_secao`).

Por isso a correcao usa `detalhe` como universo de secoes: sabemos que ele nao tem gaps.

### 5.2 Candidatos brancos/nulos (NR_VOTAVEL = 95, 96)

O TSE representa voto branco e voto nulo como "candidatos" com codigos especiais (tipicamente 95 e 96). A densificacao adiciona linhas de zero para esses tambem, mas isso nao prejudica nada: na Fase B (`R/02_build_vars.R`) eles sao filtrados antes de calcular vote shares (pois `vote_share_nominais` > 1 seria invalido para branco/nulo, ja que o numerador QT_VOTOS_BRANCOS/NULOS nao esta no denominador QT_VOTOS_NOMINAIS).

### 5.3 Candidatos de candidatura invalida

Em eleicoes com candidatos cassados ou que desistiram apos a impressao dos boletins, o TSE pode ter "candidatos" com zero votos em todas as secoes. A densificacao gera linhas de zero para esses tambem. Apos densificacao, conferir `votacao[, sum(QT_VOTOS), by = NR_VOTAVEL]` para identificar candidatos com soma total = 0 e decidir caso-a-caso se devem permanecer na analise.

### 5.4 O bug nao e' uma "sensacao visual"

Quando observado num fingerprint 2D, a diferenca entre dataset esparso e denso pode ser sutil (a massa faltante na borda inferior e' absorvida visualmente pela escala log). Mas ela afeta quantitativamente qualquer estatistica que dependa de N exato, e quebra a identidade formal do 2o turno. Nao depender de inspecao visual para detectar.

## 6. Aplicacao a anos anteriores (2018 e outros)

Este bug existe **em todos os anos** em que o TSE publicou `votacao_secao_YYYY_BR.csv` no formato esparso. Isso e' pelo menos: 2018, 2020, 2022, 2024.

**Antes de rodar qualquer analise em dados TSE de outro ano**:
1. Rodar sanity check A (contagem por candidato-turno)
2. Se contagens diferem, aplicar a correcao do passo 4 acima
3. Rodar sanity checks B e C para validar

O bug e' sistematico, nao aleatorio — assumir presente por default.

## 7. Impacto no parecer metodologico atual

Este achado e' tambem um **ponto adicional para o parecer** sobre a research note de Figueiredo/Carvalho/Santano:

- Os autores tambem carregam o CSV esparso do TSE sem densificar (confirmado em `replication_authors/extracted/fingerprint_brazil/script_paper_sig.R`, passo de leitura + join sem cross-join-fill).
- Portanto o fingerprint que eles publicam tem a mesma distorcao na cauda inferior.
- A decisao e' menos danosa para eles porque o proposito deles e' inspecao visual, e visualmente a distorcao e' pequena no 2o turno (so para Lula/Bolsonaro como par, onde os casos extremos sao ~141 secoes em ~472.000).
- Mas e' uma falha de reproducibilidade: qualquer pessoa que rode o script dos autores sobre dados TSE brutos sem essa correcao vai ter resultados sutilmente diferentes dos que os autores publicariam se tivessem densificado.
- Entra como critica metodologica adicional na revisao do script, nivel **Major** (nao critico — o impacto visual e' pequeno — mas nao-trivial).

## 8. Referencias internas

- Codigo da correcao: `R/01_load_tse.R`, passo 4.5
- Log de execucao pos-fix: `quality_reports/results/01_data_build_log.md`, secao "Densificacao de votacao_secao"
- Revisao original do script dos autores: `quality_reports/reviews/2026-04-10_review-r-authors-script.md` (adicionar este ponto como addendum)
- Plano-mae: `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`, Bloco 1
