# R/01_load_tse.R -- Bloco 1 Fase A: carregamento, filtro, merge, verificacao
# de encoding e verificacao empirica dos denominadores (TSE secao vs Nexojornal
# municipio).
#
# Produtos:
#   - data/processed/brasil_2022_secao.parquet
#   - data/processed/nexojornal_muni_2022.parquet
#   - quality_reports/results/01_data_build_log.md
#   - quality_reports/results/01_denominator_check.md
#
# Referencia: quality_reports/plans/2026-04-10_reconstrucao-metodologica.md
# Autor: Manoel Galdino
# Data: 2026-04-10

source(here::here("R", "00_setup.R"))
log_section("Bloco 1 Fase A -- carregamento e verificacao")

# ---- helpers locais ----

# Conversao segura de encoding latin1 -> UTF-8 para colunas character.
to_utf8 <- function(x) {
  if (requireNamespace("stringi", quietly = TRUE)) {
    stringi::stri_encode(x, from = "latin1", to = "UTF-8")
  } else {
    iconv(x, from = "latin1", to = "UTF-8")
  }
}

# Normaliza nomes de municipio (upper, sem acento, trim) para chave de merge.
# Tenta primeiro tratar como UTF-8; se a string vier crua (latin1 declarado
# como "unknown"), converte via 'latin1' antes.
norm_name <- function(x) {
  # Forcar decodificacao robusta: tenta latin1 primeiro, se falhar usa UTF-8.
  x <- enc2utf8(iconv(x, from = "", to = "UTF-8", sub = "byte"))
  x <- toupper(x)
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- gsub("[^A-Z ]", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  x
}

# Quantis uteis para distribuicoes de tamanho.
qvec <- function(x) {
  stats::quantile(x, probs = c(0, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1),
                  na.rm = TRUE)
}

# Buffer de log em memoria. md() imprime no console E acumula no buffer;
# no final gravamos o buffer como markdown. Usamos message() diretamente
# para evitar que cli interprete { } como glue.
.md_buf <- character()
md <- function(...) {
  line <- paste0(...)
  .md_buf <<- c(.md_buf, line)
  message(line)
  invisible(NULL)
}
md_header <- function(title, level = 2) {
  md("")
  md(strrep("#", level), " ", title)
  md("")
}

t0 <- Sys.time()
md_header("Bloco 1 Fase A -- log de build", level = 1)
md("Data/hora: ", format(t0, "%Y-%m-%d %H:%M:%S %Z"))
md("R: ", R.version$major, ".", R.version$minor,
   " | data.table: ", as.character(utils::packageVersion("data.table")),
   " | arrow: ",       as.character(utils::packageVersion("arrow")))

# =============================================================================
# PASSO 0 -- arquivos de entrada
# =============================================================================

path_votacao <- file.path(PATH_RAW_AUTHORS, "votacao_secao_2022_BR.csv")
path_detalhe <- file.path(PATH_RAW_AUTHORS, "detalhe_votacao_secao_2022_BR.csv")
path_nexo    <- file.path(PATH_RAW_AUTHORS,
                          "votos_presidente_muni_nexojornal_2022.xlsx")

stopifnot(file.exists(path_votacao), file.exists(path_detalhe),
          file.exists(path_nexo))

md_header("Arquivos de entrada")
md("- `votacao_secao_2022_BR.csv`: ",
   round(file.info(path_votacao)$size / 1024^2, 1), " MB")
md("- `detalhe_votacao_secao_2022_BR.csv`: ",
   round(file.info(path_detalhe)$size / 1024^2, 1), " MB")
md("- `votos_presidente_muni_nexojornal_2022.xlsx`: ",
   round(file.info(path_nexo)$size / 1024^2, 1), " MB")

# =============================================================================
# PASSO 1 -- sanity check de encoding (amostra de 2000 linhas)
# =============================================================================

md_header("Encoding check")

# Usamos fread com nrows na leitura amostral. latin1 e UTF-8, mesma amostra.
enc_cols <- c("SG_UF", "CD_MUNICIPIO", "NM_MUNICIPIO")

sample_latin1 <- data.table::fread(
  path_votacao,
  nrows = 50000,
  sep = ";", dec = ",",
  encoding = "Latin-1",
  select = enc_cols,
  showProgress = FALSE
)
sample_utf8 <- tryCatch(
  {
    dt <- data.table::fread(
      path_votacao,
      nrows = 50000,
      sep = ";", dec = ",",
      encoding = "UTF-8",
      select = enc_cols,
      showProgress = FALSE
    )
    # Marcar explicitamente como UTF-8 para expor o mojibake sem erro do R.
    dt[, NM_MUNICIPIO := {
      v <- NM_MUNICIPIO
      Encoding(v) <- "UTF-8"
      # sub = "byte" substitui bytes invalidos por <xx> hex, evitando erro.
      iconv(v, from = "UTF-8", to = "UTF-8", sub = "byte")
    }]
    dt
  },
  error = function(e) {
    md("> `fread` falhou com `encoding = \"UTF-8\"`: ", conditionMessage(e))
    md("> Isto ja eh forte evidencia de que o arquivo NAO e UTF-8 valido.")
    NULL
  }
)

# Conjunto de alvo: normalizamos para achar os casos.
targets <- c("SAO PAULO", "BRASILIA", "GOIANIA", "JOAO PESSOA",
             "BELEM", "SALVADOR", "VITORIA", "FLORIANOPOLIS")

pick_one <- function(dt) {
  if (is.null(dt) || nrow(dt) == 0) return(data.table::data.table())
  dt <- data.table::copy(dt)
  # Garantir UTF-8 valido em NM_MUNICIPIO antes de qualquer regex.
  dt[, NM_MUNICIPIO := {
    v <- NM_MUNICIPIO
    # Para strings marcadas 'latin1', converter; para 'unknown', assumir
    # latin1 (TSE); para 'UTF-8' (leitura UTF-8), manter.
    is_latin <- Encoding(v) %in% c("latin1", "unknown")
    if (any(is_latin)) {
      v[is_latin] <- iconv(v[is_latin], from = "latin1", to = "UTF-8")
    }
    iconv(v, from = "UTF-8", to = "UTF-8", sub = "byte")
  }]
  dt <- unique(dt, by = "NM_MUNICIPIO")
  dt[, key := norm_name(NM_MUNICIPIO)]
  dt[key %in% targets, .(key, NM_MUNICIPIO)]
}

lat_pick <- pick_one(sample_latin1)
utf_pick <- pick_one(sample_utf8)

md("Amostra de 50.000 linhas da base `votacao_secao`:")
md("- linhas lidas (Latin-1): ", nrow(sample_latin1))
md("- linhas lidas (UTF-8):   ",
   if (is.null(sample_utf8)) "falha" else nrow(sample_utf8))
md("")
md("Exemplos de `NM_MUNICIPIO` encontrados na amostra:")
md("")
md("| chave normalizada | latin1 | utf-8 |")
md("|---|---|---|")
all_keys <- sort(unique(c(lat_pick$key, utf_pick$key)))
for (k in all_keys) {
  l_val <- lat_pick[key == k, NM_MUNICIPIO][1]
  u_val <- utf_pick[key == k, NM_MUNICIPIO][1]
  md("| ", k, " | `", ifelse(is.na(l_val), "-", l_val),
     "` | `", ifelse(is.na(u_val), "-", u_val), "` |")
}

# Heuristica: latin1 deve ter caracteres non-ASCII validos (ex. tilde, acento);
# UTF-8 lendo latin1 deve produzir mojibake com 'Ã' ou 'Â'. Aplicamos o teste
# na amostra COMPLETA, nao apenas nas cidades-alvo (que podem nao ter acento).
lat_all <- unique(sample_latin1$NM_MUNICIPIO)
lat_has_accent <- any(grepl("[\u00C0-\u00FF]", lat_all, useBytes = FALSE))

utf_all <- if (!is.null(sample_utf8)) unique(sample_utf8$NM_MUNICIPIO) else character(0)
utf_has_mojibake <- if (length(utf_all) == 0) NA else
  any(grepl("\u00C3|\u00C2", utf_all, useBytes = FALSE))

# Exemplos de nomes acentuados na amostra latin1 (ate 5).
lat_accent_examples <- head(lat_all[grepl("[\u00C0-\u00FF]", lat_all,
                                          useBytes = FALSE)], 5)
if (length(lat_accent_examples) > 0) {
  md("")
  md("Exemplos de acentos em `NM_MUNICIPIO` lidos com Latin-1:")
  md("`", paste(lat_accent_examples, collapse = "`, `"), "`")
}

md("")
md("- latin1 produz acentos validos: **", lat_has_accent, "**")
md("- utf-8  produz mojibake (C3/C2): **",
   ifelse(is.na(utf_has_mojibake), "n/d", utf_has_mojibake), "**")

# Comparar latin1 x utf-8 sobre o mesmo conjunto de linhas (amostra completa
# das 50k linhas, nao apenas os targets). Se as strings diferem, latin1 venceu.
if (length(utf_all) > 0) {
  n_diff <- sum(lat_all != utf_all[match(norm_name(lat_all),
                                         norm_name(utf_all))],
                na.rm = TRUE)
  md("")
  md("- linhas em que latin1 e utf-8 produzem strings diferentes ",
     "(na amostra de 50k): ", n_diff)
}

if (!lat_has_accent) {
  md("")
  md("> WARN: amostra latin1 nao contem caracteres acentuados. Improvavel ",
     "com 50k linhas -- investigar.")
}
if (lat_has_accent && isTRUE(utf_has_mojibake == FALSE)) {
  md("")
  md("> Observacao: latin1 produz acentos validos e a leitura 'UTF-8' ",
     "nao retorna mojibake detectavel porque `fread(encoding='UTF-8')` ",
     "nao tenta re-decodificar os bytes -- apenas marca o encoding. ",
     "A diferenca relevante e que latin1 produz strings com Encoding() ",
     "`latin1`, enquanto 'UTF-8' produz strings com bytes invalidos ",
     "marcados como UTF-8. Latin-1 e a leitura correta.")
}

# Conclusao: seguimos com Latin-1 (e isto foi confirmado pelo plano).
encoding_tse <- "Latin-1"
md("")
md("**Decisao**: prosseguir com `encoding = '", encoding_tse, "'`.")

rm(sample_latin1, sample_utf8, lat_pick, utf_pick)
invisible(gc(verbose = FALSE))

# =============================================================================
# PASSO 2 -- leitura completa dos CSVs (apenas colunas necessarias)
# =============================================================================

md_header("Leitura")

cols_votacao <- c(
  "ANO_ELEICAO", "NR_TURNO", "SG_UF", "CD_MUNICIPIO", "NM_MUNICIPIO",
  "NR_ZONA", "NR_SECAO", "CD_CARGO", "DS_CARGO",
  "NR_VOTAVEL", "NM_VOTAVEL", "QT_VOTOS"
)
cols_detalhe <- c(
  "ANO_ELEICAO", "NR_TURNO", "SG_UF", "CD_MUNICIPIO", "NM_MUNICIPIO",
  "NR_ZONA", "NR_SECAO", "CD_CARGO", "DS_CARGO",
  "QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES",
  "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
  "QT_VOTOS_LEGENDA", "QT_VOTOS_ANULADOS_APU_SEP"
)

log_step("Lendo votacao_secao (1.5 GB, select = {length(cols_votacao)} cols)...")
t1 <- Sys.time()
votacao <- data.table::fread(
  path_votacao,
  sep = ";", dec = ",",
  encoding = encoding_tse,
  select = cols_votacao,
  showProgress = FALSE
)
dt_votacao <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
md("- `votacao_secao`: lido em ", sprintf("%.1f", dt_votacao), "s -- ",
   format(nrow(votacao), big.mark = ","), " linhas x ",
   ncol(votacao), " colunas.")

log_step("Lendo detalhe_votacao (263 MB, select = {length(cols_detalhe)} cols)...")
t1 <- Sys.time()
detalhe <- data.table::fread(
  path_detalhe,
  sep = ";", dec = ",",
  encoding = encoding_tse,
  select = cols_detalhe,
  showProgress = FALSE
)
dt_detalhe <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
md("- `detalhe_votacao`: lido em ", sprintf("%.1f", dt_detalhe), "s -- ",
   format(nrow(detalhe), big.mark = ","), " linhas x ",
   ncol(detalhe), " colunas.")

# =============================================================================
# PASSO 3 -- filtro: presidente, turnos 1 e 2
# =============================================================================

md_header("Filtro")

n_vot_pre  <- nrow(votacao)
n_det_pre  <- nrow(detalhe)

votacao <- votacao[DS_CARGO == "PRESIDENTE" & NR_TURNO %in% c(1L, 2L)]
detalhe <- detalhe[DS_CARGO == "PRESIDENTE" & NR_TURNO %in% c(1L, 2L)]

n_vot_post <- nrow(votacao)
n_det_post <- nrow(detalhe)

md("Filtro aplicado: `DS_CARGO == \"PRESIDENTE\"` AND `NR_TURNO in {1,2}`.")
md("")
md("| base | linhas antes | linhas depois | reducao |")
md("|---|---:|---:|---:|")
md("| votacao_secao  | ", format(n_vot_pre, big.mark = ","), " | ",
   format(n_vot_post, big.mark = ","), " | ",
   sprintf("%.1f%%", 100 * (1 - n_vot_post / n_vot_pre)), " |")
md("| detalhe_votacao| ", format(n_det_pre, big.mark = ","), " | ",
   format(n_det_post, big.mark = ","), " | ",
   sprintf("%.1f%%", 100 * (1 - n_det_post / n_det_pre)), " |")

md("")
md("Distribuicao por turno (apos filtro):")
md("")
md("| base | turno 1 | turno 2 |")
md("|---|---:|---:|")
md("| votacao_secao   | ",
   format(nrow(votacao[NR_TURNO == 1L]), big.mark = ","), " | ",
   format(nrow(votacao[NR_TURNO == 2L]), big.mark = ","), " |")
md("| detalhe_votacao | ",
   format(nrow(detalhe[NR_TURNO == 1L]), big.mark = ","), " | ",
   format(nrow(detalhe[NR_TURNO == 2L]), big.mark = ","), " |")

# =============================================================================
# PASSO 4 -- diagnostico pre-merge
# =============================================================================

md_header("Diagnosticos pre-merge")

# Chave de secao (unica no detalhe, unica por candidato no votacao).
key_secao <- c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO", "NR_TURNO")

## Duplicatas no detalhe (deve ser unico por chave)
dup_det <- detalhe[, .N, by = key_secao][N > 1]
md("Duplicatas em `detalhe_votacao` pela chave ",
   "`(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO)`: **",
   nrow(dup_det), "** grupos.")
if (nrow(dup_det) > 0) {
  md("- Top 5 contagens: ",
     paste(head(dup_det$N, 5), collapse = ", "))
}

## Duplicatas no votacao (unico por chave + candidato)
dup_vot <- votacao[, .N, by = c(key_secao, "NR_VOTAVEL")][N > 1]
md("Duplicatas em `votacao_secao` pela chave ",
   "`(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO, NR_VOTAVEL)`: **",
   nrow(dup_vot), "** grupos.")
if (nrow(dup_vot) > 0) {
  md("- Top 5 contagens: ",
     paste(head(dup_vot$N, 5), collapse = ", "))
}

## Valores-limite no detalhe
n_aptos0    <- nrow(detalhe[QT_APTOS == 0])
n_comp0     <- nrow(detalhe[QT_COMPARECIMENTO == 0])
n_nom0      <- nrow(detalhe[QT_VOTOS_NOMINAIS == 0])
n_comp_gt_a <- nrow(detalhe[QT_COMPARECIMENTO > QT_APTOS])
n_zz        <- nrow(detalhe[SG_UF == "ZZ"])

md("")
md("Valores-limite em `detalhe_votacao` (secao-turno, apos filtro):")
md("")
md("| condicao | N |")
md("|---|---:|")
md("| `QT_APTOS == 0`              | ", format(n_aptos0,    big.mark=","), " |")
md("| `QT_COMPARECIMENTO == 0`     | ", format(n_comp0,     big.mark=","), " |")
md("| `QT_VOTOS_NOMINAIS == 0`     | ", format(n_nom0,      big.mark=","), " |")
md("| `QT_COMPARECIMENTO > QT_APTOS` (edge case) | ",
   format(n_comp_gt_a, big.mark=","), " |")
md("| `SG_UF == \"ZZ\"` (exterior) | ", format(n_zz,        big.mark=","), " |")

## Distribuicao de tamanho de secao
qa <- qvec(detalhe$QT_APTOS)
md("")
md("Distribuicao de `QT_APTOS` (tamanho de secao):")
md("")
md("| estatistica | valor |")
md("|---|---:|")
md("| min  | ", qa[["0%"]],   " |")
md("| p1   | ", qa[["1%"]],   " |")
md("| p10  | ", qa[["10%"]],  " |")
md("| p25  | ", qa[["25%"]],  " |")
md("| p50  | ", qa[["50%"]],  " |")
md("| p75  | ", qa[["75%"]],  " |")
md("| p90  | ", qa[["90%"]],  " |")
md("| p99  | ", qa[["99%"]],  " |")
md("| max  | ", qa[["100%"]], " |")

# =============================================================================
# PASSO 4.5 -- densificar votacao (adicionar linhas QT_VOTOS = 0)
# =============================================================================
#
# BUG TSE: o CSV votacao_secao_XXXX_BR.csv NAO reporta linhas para
# (secao, turno, candidato) em que QT_VOTOS = 0. Candidatos que receberam
# zero votos numa secao sao simplesmente omitidos da tabela. Isso gera um
# missing silencioso no cross-section e, em particular, quebra a identidade
# formal do 2o turno (onde vote_share_Lula + vote_share_Bolsonaro = 1 por
# construcao). Sem fix, secoes onde um dos candidatos teve 100%% do nominais
# desaparecem do registro do outro candidato.
#
# Correcao: construir o produto cartesiano secao x turno x candidato-do-turno
# e preencher QT_VOTOS = 0 onde nao houver registro. O universo de secoes vem
# de detalhe_votacao (que e' denso por construcao do TSE). O universo de
# candidatos por turno vem de votacao_secao (quem apareceu em ao menos uma
# secao daquele turno).

md_header("Densificacao de votacao_secao")
md("")
md("Passo critico: o CSV bruto do TSE (`votacao_secao_XXXX_BR.csv`) NAO reporta")
md("linhas (secao, turno, candidato) em que QT_VOTOS = 0. Sem correcao, candidatos")
md("com 0 votos numa secao desaparecem desse registro, quebrando a identidade")
md("formal no 2o turno (Lula 100%% implica Bolsonaro 0%% mas a linha desse Bolsonaro")
md("nao existe no arquivo). Corrigido aqui via cross-join com preenchimento = 0.")
md("")

log_step("Densificacao: construindo universo completo (secao x turno x candidato)...")

# Universo de secoes-turno (ja denso em detalhe)
secao_universe <- detalhe[, .(ANO_ELEICAO, NR_TURNO, SG_UF, CD_MUNICIPIO,
                              NM_MUNICIPIO, NR_ZONA, NR_SECAO,
                              CD_CARGO, DS_CARGO)]

# Universo de candidatos por turno (dos candidatos que apareceram em alguma secao)
cand_universe <- unique(votacao[, .(NR_TURNO, NR_VOTAVEL, NM_VOTAVEL)])

# Cross-join sobre NR_TURNO
votacao_dense <- merge(secao_universe, cand_universe,
                       by = "NR_TURNO", allow.cartesian = TRUE)

# Left-join com os votos reais
votacao_actual <- votacao[, .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO,
                              NR_TURNO, NR_VOTAVEL, QT_VOTOS)]
votacao_dense <- merge(votacao_dense, votacao_actual,
                       by = c("SG_UF", "CD_MUNICIPIO", "NR_ZONA",
                              "NR_SECAO", "NR_TURNO", "NR_VOTAVEL"),
                       all.x = TRUE)

n_before <- nrow(votacao)
n_dense  <- nrow(votacao_dense)
n_zero   <- votacao_dense[is.na(QT_VOTOS), .N]

votacao_dense[is.na(QT_VOTOS), QT_VOTOS := 0L]

# Sanity: expected size
n_secoes_det  <- nrow(secao_universe)
n_cand_t1     <- cand_universe[NR_TURNO == 1L, .N]
n_cand_t2     <- cand_universe[NR_TURNO == 2L, .N]
n_secoes_t1   <- secao_universe[NR_TURNO == 1L, .N]
n_secoes_t2   <- secao_universe[NR_TURNO == 2L, .N]
n_expected    <- n_secoes_t1 * n_cand_t1 + n_secoes_t2 * n_cand_t2

md("| metrica                                            | valor |")
md("|---|---:|")
md("| linhas em `votacao` original (pre-densificacao)    | ",
   format(n_before, big.mark = ","), " |")
md("| secoes-turno em `detalhe` (universo)               | ",
   format(n_secoes_det, big.mark = ","), " |")
md("| candidatos unicos no T1 (inclui brancos/nulos)     | ",
   n_cand_t1, " |")
md("| candidatos unicos no T2 (inclui brancos/nulos)     | ",
   n_cand_t2, " |")
md("| linhas esperadas pos-densificacao (cartesiano)     | ",
   format(n_expected, big.mark = ","), " |")
md("| linhas apos densificacao                           | ",
   format(n_dense, big.mark = ","), " |")
md("| linhas adicionadas com `QT_VOTOS = 0`              | ",
   format(n_zero, big.mark = ","), " |")
md("| fracao do total densificado que foi preenchida com 0 | ",
   sprintf("%.2f%%", 100 * n_zero / n_dense), " |")

stopifnot(n_dense == n_expected)
log_step("Densificacao OK: {format(n_dense, big.mark=',')} linhas ({format(n_zero, big.mark=',')} zeros adicionados)")

# Substitui votacao pelo denso e libera memoria
votacao <- votacao_dense
rm(votacao_dense, secao_universe, cand_universe, votacao_actual)
invisible(gc())

# =============================================================================
# PASSO 5 -- merge votacao x detalhe
# =============================================================================

md_header("Merge")

data.table::setkeyv(votacao, key_secao)
data.table::setkeyv(detalhe, key_secao)

log_step("Merging votacao x detalhe por {paste(key_secao, collapse=', ')}...")
merged <- detalhe[votacao,
                  on = key_secao,
                  nomatch = NA]

n_merged <- nrow(merged)
n_miss_detalhe <- sum(is.na(merged$QT_APTOS))
n_cand_unicos  <- data.table::uniqueN(merged$NR_VOTAVEL)
n_secao_unicas <- data.table::uniqueN(merged[, ..key_secao])
n_t1 <- nrow(merged[NR_TURNO == 1L])
n_t2 <- nrow(merged[NR_TURNO == 2L])

md("Merge LEFT JOIN: `votacao_secao` enriquecido com totais de `detalhe_votacao`.")
md("")
md("| metrica | valor |")
md("|---|---:|")
md("| linhas no resultado              | ",
   format(n_merged, big.mark = ","), " |")
md("| linhas sem match no detalhe      | ",
   format(n_miss_detalhe, big.mark = ","), " |")
md("| candidatos unicos (NR_VOTAVEL)   | ", n_cand_unicos, " |")
md("| secoes-turno unicas              | ",
   format(n_secao_unicas, big.mark = ","), " |")
md("| linhas turno 1                   | ",
   format(n_t1, big.mark = ","), " |")
md("| linhas turno 2                   | ",
   format(n_t2, big.mark = ","), " |")

if (n_miss_detalhe > 0) {
  md("")
  md("> WARN: ", n_miss_detalhe, " linhas de `votacao_secao` nao encontraram ",
     "match em `detalhe_votacao`. Investigar se necessario.")
}

# Dedupe silencioso? Nao. Checamos duplicatas no resultado.
dup_merged <- merged[, .N,
                     by = c(key_secao, "NR_VOTAVEL")][N > 1]
md("")
md("Duplicatas no merged pela chave `(..., NR_VOTAVEL)`: **",
   nrow(dup_merged), "** grupos.")

if (nrow(dup_merged) > 0) {
  md("- max count: ", max(dup_merged$N))
  md("- Tentando dedupe por `unique` (mantem primeira ocorrencia)...")
  before <- nrow(merged)
  merged <- unique(merged, by = c(key_secao, "NR_VOTAVEL"))
  after <- nrow(merged)
  md("- removidas: ", before - after, " linhas (",
     sprintf("%.4f%%", 100 * (before - after) / before), ").")
}

# =============================================================================
# PASSO 6 -- Nexojornal: leitura e limpeza
# =============================================================================

md_header("Nexojornal")

log_step("Lendo Nexojornal, aba absoluto-1t-2022...")
nexo_1t <- readxl::read_excel(path_nexo, sheet = "absoluto-1t-2022")
log_step("Lendo Nexojornal, aba absoluto-2t-2022...")
nexo_2t <- readxl::read_excel(path_nexo, sheet = "absoluto-2t-2022")

nexo_1t <- data.table::as.data.table(nexo_1t)
nexo_2t <- data.table::as.data.table(nexo_2t)

md("Colunas observadas em `absoluto-1t-2022`:")
md("`", paste(colnames(nexo_1t), collapse = ", "), "`")
md("")
md("Colunas observadas em `absoluto-2t-2022`:")
md("`", paste(colnames(nexo_2t), collapse = ", "), "`")

# Algumas colunas no 2T vieram como character. Coerce para numeric onde preciso.
coerce_num <- function(dt, cols) {
  for (cc in intersect(cols, names(dt))) {
    if (!is.numeric(dt[[cc]])) {
      dt[, (cc) := suppressWarnings(as.numeric(.SD[[1]])), .SDcols = cc]
    }
  }
  dt
}

num_cols_needed <- c("eleitores", "comparecimento", "abstencoes", "abstencao",
                     "validos", "brancos", "nulos",
                     "13", "22", "15", "12", "44",
                     "x13", "x22", "x15", "x12", "x44")
nexo_1t <- coerce_num(nexo_1t, num_cols_needed)
nexo_2t <- coerce_num(nexo_2t, num_cols_needed)

# Renomear explicitamente as colunas de candidato.
# 1T: colunas '13','22','15','12','44'
rename_if_present <- function(dt, old, new) {
  if (old %in% names(dt)) data.table::setnames(dt, old, new)
  dt
}
nexo_1t <- rename_if_present(nexo_1t, "13", "votos_lula")
nexo_1t <- rename_if_present(nexo_1t, "22", "votos_bolsonaro")
nexo_1t <- rename_if_present(nexo_1t, "15", "votos_tebet")
nexo_1t <- rename_if_present(nexo_1t, "12", "votos_ciro")
nexo_1t <- rename_if_present(nexo_1t, "44", "votos_soraya")

# 2T: colunas 'x13','x22'
nexo_2t <- rename_if_present(nexo_2t, "x13", "votos_lula")
nexo_2t <- rename_if_present(nexo_2t, "x22", "votos_bolsonaro")
# (2T so tem Lula e Bolsonaro)

# Padronizar abstencoes/abstencao.
if ("abstencao" %in% names(nexo_2t)) {
  data.table::setnames(nexo_2t, "abstencao", "abstencoes")
}

# Colunas a manter (uniao minima para empilhar).
keep_cols <- c("tse", "ibge7", "municipio", "uf",
               "eleitores", "comparecimento", "abstencoes",
               "validos", "brancos", "nulos",
               "votos_lula", "votos_bolsonaro",
               "votos_tebet", "votos_ciro", "votos_soraya")

ensure_cols <- function(dt, cols) {
  for (cc in cols) {
    if (!(cc %in% names(dt))) dt[, (cc) := NA_real_]
  }
  dt[, ..cols]
}

nexo_1t <- ensure_cols(nexo_1t, keep_cols)
nexo_2t <- ensure_cols(nexo_2t, keep_cols)

nexo_1t[, NR_TURNO := 1L]
nexo_2t[, NR_TURNO := 2L]

nexojornal <- data.table::rbindlist(list(nexo_1t, nexo_2t),
                                    use.names = TRUE, fill = TRUE)

md("")
md("Apos empilhamento 1T+2T:")
md("- linhas: ", format(nrow(nexojornal), big.mark = ","))
md("- linhas 1T: ", format(nrow(nexojornal[NR_TURNO == 1L]), big.mark = ","))
md("- linhas 2T: ", format(nrow(nexojornal[NR_TURNO == 2L]), big.mark = ","))
md("- municipios unicos (ibge7): ",
   data.table::uniqueN(nexojornal$ibge7))
md("- municipios unicos ((uf, municipio)): ",
   data.table::uniqueN(nexojornal[, .(uf, municipio)]))

# Sanidade: ibge7 nao-NA?
n_ibge_na <- sum(is.na(nexojornal$ibge7) | nexojornal$ibge7 == "")
md("- linhas com `ibge7` vazio/NA: ", n_ibge_na)

# Normalizar nomes para merge fallback.
nexojornal[, muni_key := norm_name(municipio)]

# =============================================================================
# PASSO 7 -- persistencia (UTF-8)
# =============================================================================

md_header("Persistencia")

# Converter strings das bases TSE para UTF-8 antes de escrever o parquet.
char_cols_tse <- c("SG_UF", "NM_MUNICIPIO", "DS_CARGO", "NM_VOTAVEL")
for (cc in intersect(char_cols_tse, names(merged))) {
  merged[, (cc) := to_utf8(get(cc))]
}

# Teste rapido de caracteres acentuados sobreviventes.
n_acentos <- sum(grepl("[\u00C0-\u017F]", merged$NM_MUNICIPIO,
                       useBytes = FALSE))
md("Linhas com pelo menos 1 char acentuado em `NM_MUNICIPIO` apos UTF-8: ",
   format(n_acentos, big.mark = ","))
ex_acentos <- unique(merged[grepl("[\u00C0-\u017F]", NM_MUNICIPIO,
                                  useBytes = FALSE), NM_MUNICIPIO])
md("Exemplos: `", paste(head(ex_acentos, 6), collapse = "`, `"), "`")

# Nexojornal ja esta UTF-8 (readxl), so garantir.
char_cols_nexo <- c("tse", "ibge7", "municipio", "uf", "muni_key")
for (cc in intersect(char_cols_nexo, names(nexojornal))) {
  nexojornal[, (cc) := enc2utf8(as.character(get(cc)))]
}

path_out_tse  <- file.path(PATH_DATA_PROCESSED, "brasil_2022_secao.parquet")
path_out_nexo <- file.path(PATH_DATA_PROCESSED, "nexojornal_muni_2022.parquet")

log_step("Escrevendo parquet TSE secao-nivel -> {path_out_tse}")
arrow::write_parquet(merged, path_out_tse)
log_step("Escrevendo parquet Nexojornal municipio -> {path_out_nexo}")
arrow::write_parquet(nexojornal, path_out_nexo)

size_tse  <- file.info(path_out_tse)$size  / 1024^2
size_nexo <- file.info(path_out_nexo)$size / 1024^2
md("")
md("Parquet gerados:")
md("- `", basename(path_out_tse),  "` -- ", sprintf("%.1f MB", size_tse))
md("- `", basename(path_out_nexo), "` -- ", sprintf("%.1f MB", size_nexo))

# Liberamos memoria desnecessaria antes da verificacao de denominadores.
rm(votacao, detalhe)
invisible(gc(verbose = FALSE))

# =============================================================================
# PASSO 8 -- verificacao empirica do denominador
# =============================================================================

md_header("Verificacao de denominador (principal)")
md("Comparacao das tres definicoes de denominador TSE (agregado a municipio) ",
   "contra `validos` do Nexojornal. Veredito abaixo em ",
   "`01_denominator_check.md`.")

# Buffer separado para o relatorio de denominador.
.denom_buf <- character()
md2 <- function(...) {
  line <- paste0(...)
  .denom_buf <<- c(.denom_buf, line)
  message(line)
  invisible(NULL)
}
md2_header <- function(title, level = 2) {
  md2("")
  md2(strrep("#", level), " ", title)
  md2("")
}

md2_header("Verificacao empirica do denominador", level = 1)
md2("Data/hora: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
md2("")
md2("## Procedimento")
md2("")
md2("1. Agregar a base TSE secao-nivel para municipio somando numeradores ",
    "(votos de cada candidato) e denominadores candidatos ",
    "(`QT_COMPARECIMENTO`, `QT_VOTOS_NOMINAIS`, ",
    "`QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS`), por turno.")
md2("2. Calcular tres versoes de `vote_share` por candidato x municipio x turno:")
md2("   - `comparecimento`: `sum(votos) / sum(QT_COMPARECIMENTO)`")
md2("   - `validos`: `sum(votos) / sum(QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS)`")
md2("   - `nominais`: `sum(votos) / sum(QT_VOTOS_NOMINAIS)`")
md2("3. Do lado Nexojornal: `voto_candidato / validos`.")
md2("4. Merge por `CD_MUNICIPIO (TSE)` = `tse` (Nexojornal).")
md2("5. Para cada cenario TSE, reportar mean/median/p95/max da diferenca ",
    "absoluta contra Nexojornal e N de municipios com diferenca > 1 p.p.")

# --- Agregacao TSE -> municipio ------------------------------------------------
secao <- arrow::read_parquet(path_out_tse) |> data.table::as.data.table()

# Deduplicar por (key, NR_VOTAVEL) se necessario (ja feito acima), e manter
# apenas Lula e Bolsonaro para a verificacao.
secao_lb <- secao[NR_VOTAVEL %in% c(13L, 22L)]

# Totais por secao (validos por secao = QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS).
# Obs: esta definicao segue a regra TSE: "votos validos" = nominais + legenda.
# Aqui usamos "nominais + brancos" conforme instrucao do plano (para bater
# com Nexojornal, que inclui brancos no denominador `validos`?).
# Vamos testar as tres.
secao_lb[, secao_uid := paste(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO,
                              NR_TURNO, sep = "|")]

# Totais unicos por secao (QT_APTOS, QT_COMPARECIMENTO, QT_VOTOS_NOMINAIS,
# QT_VOTOS_BRANCOS). Sao os mesmos para Lula e Bolsonaro na mesma secao, por
# isso pegamos via first().
secao_totais <- unique(
  secao_lb[, .(secao_uid, CD_MUNICIPIO, NR_TURNO,
               QT_COMPARECIMENTO, QT_VOTOS_NOMINAIS, QT_VOTOS_BRANCOS)]
)

# Agregar a municipio x turno.
totais_muni <- secao_totais[,
  .(
    sum_comp     = sum(QT_COMPARECIMENTO, na.rm = TRUE),
    sum_nominais = sum(QT_VOTOS_NOMINAIS, na.rm = TRUE),
    sum_brancos  = sum(QT_VOTOS_BRANCOS,  na.rm = TRUE)
  ),
  by = .(CD_MUNICIPIO, NR_TURNO)
]
totais_muni[, sum_validos := sum_nominais + sum_brancos]

# Votos por candidato x municipio x turno.
votos_muni <- secao_lb[,
  .(votos = sum(QT_VOTOS, na.rm = TRUE)),
  by = .(CD_MUNICIPIO, NR_TURNO, NR_VOTAVEL)
]
votos_muni[, candidato := data.table::fifelse(NR_VOTAVEL == 13L, "lula", "bolsonaro")]
votos_muni_wide <- data.table::dcast(
  votos_muni,
  CD_MUNICIPIO + NR_TURNO ~ candidato,
  value.var = "votos",
  fill = 0
)
data.table::setnames(votos_muni_wide,
                     c("lula", "bolsonaro"),
                     c("votos_lula_tse", "votos_bolsonaro_tse"))

tse_muni <- merge(totais_muni, votos_muni_wide,
                  by = c("CD_MUNICIPIO", "NR_TURNO"), all = FALSE)

# Shares TSE, tres versoes.
tse_muni[, `:=`(
  lula_comp      = votos_lula_tse      / sum_comp,
  lula_validos   = votos_lula_tse      / sum_validos,
  lula_nominais  = votos_lula_tse      / sum_nominais,
  bols_comp      = votos_bolsonaro_tse / sum_comp,
  bols_validos   = votos_bolsonaro_tse / sum_validos,
  bols_nominais  = votos_bolsonaro_tse / sum_nominais
)]

md2("")
md2("### TSE agregado")
md2("- municipios-turno no TSE agregado: ",
    format(nrow(tse_muni), big.mark = ","))
md2("- amostra de totais:")
md2("")
md2("```")
.samp <- utils::capture.output(print(tse_muni[1:5,
  .(CD_MUNICIPIO, NR_TURNO, sum_comp, sum_nominais, sum_validos,
    votos_lula_tse, votos_bolsonaro_tse)]))
for (ln in .samp) md2(ln)
md2("```")

# --- Shares Nexojornal --------------------------------------------------------

nexo_shares <- nexojornal[,
  .(tse, ibge7, municipio, uf, NR_TURNO,
    nexo_validos  = validos,
    nexo_lula     = votos_lula,
    nexo_bols     = votos_bolsonaro)
]
nexo_shares[, `:=`(
  nexo_share_lula = nexo_lula / nexo_validos,
  nexo_share_bols = nexo_bols / nexo_validos
)]

md2("")
md2("### Nexojornal")
md2("- municipios-turno: ",
    format(nrow(nexo_shares), big.mark = ","))
md2("- nao-NA no share Lula: ",
    sum(!is.na(nexo_shares$nexo_share_lula)))

# --- Merge --------------------------------------------------------------------

# Nexojornal tem coluna `tse` que e o codigo de municipio TSE. Padronizar tipo.
# CD_MUNICIPIO no TSE original eh integer; em Nexojornal eh character com
# zeros a esquerda. Converter ambos para character removendo leading zeros
# para bater.
tse_muni[, cd_key := as.character(CD_MUNICIPIO)]
nexo_shares[, cd_key := as.character(as.integer(tse))]

# Remover NA/strings invalidas
nexo_shares_valid <- nexo_shares[!is.na(cd_key) & cd_key != "NA"]

cmp <- merge(
  tse_muni[, .(cd_key, NR_TURNO,
               lula_comp, lula_validos, lula_nominais,
               bols_comp, bols_validos, bols_nominais)],
  nexo_shares_valid[, .(cd_key, NR_TURNO, nexo_share_lula, nexo_share_bols)],
  by = c("cd_key", "NR_TURNO"),
  all = FALSE
)

md2("")
md2("### Merge TSE-agregado x Nexojornal")
md2("- chave: `CD_MUNICIPIO` (int) <-> `tse` (Nexojornal, leading zeros removidos)")
md2("- municipios-turno em TSE agregado: ", nrow(tse_muni))
md2("- municipios-turno em Nexojornal: ", nrow(nexo_shares_valid))
md2("- municipios-turno no merge (inner): ", nrow(cmp))
md2("- municipios-turno sem match TSE->Nexo: ",
    nrow(tse_muni) - nrow(cmp))

# --- Tabelas de diferenca -----------------------------------------------------

make_stats <- function(dif) {
  dif <- dif[!is.na(dif)]
  if (length(dif) == 0) {
    return(list(mean = NA, median = NA, p95 = NA, max = NA,
                n_gt_1pp = NA, n_gt_0_1pp = NA))
  }
  list(
    mean      = mean(dif),
    median    = stats::median(dif),
    p95       = stats::quantile(dif, 0.95, names = FALSE),
    max       = max(dif),
    n_gt_1pp  = sum(dif > 0.01),
    n_gt_0_1pp = sum(dif > 0.001)
  )
}

compute_row <- function(dt, col_tse, col_nexo, label) {
  dif <- abs(dt[[col_tse]] - dt[[col_nexo]])
  s <- make_stats(dif)
  data.table::data.table(
    denominador = label,
    mean_abs_diff    = s$mean,
    median_abs_diff  = s$median,
    p95_abs_diff     = s$p95,
    max_abs_diff     = s$max,
    n_munis_gt_0_1pp = s$n_gt_0_1pp,
    n_munis_gt_1pp   = s$n_gt_1pp
  )
}

scenarios <- list(
  list(turno = 1L, cand = "lula",
       tse_cols = c(comparecimento = "lula_comp",
                    validos        = "lula_validos",
                    nominais       = "lula_nominais"),
       nexo_col = "nexo_share_lula"),
  list(turno = 2L, cand = "lula",
       tse_cols = c(comparecimento = "lula_comp",
                    validos        = "lula_validos",
                    nominais       = "lula_nominais"),
       nexo_col = "nexo_share_lula"),
  list(turno = 1L, cand = "bolsonaro",
       tse_cols = c(comparecimento = "bols_comp",
                    validos        = "bols_validos",
                    nominais       = "bols_nominais"),
       nexo_col = "nexo_share_bols"),
  list(turno = 2L, cand = "bolsonaro",
       tse_cols = c(comparecimento = "bols_comp",
                    validos        = "bols_validos",
                    nominais       = "bols_nominais"),
       nexo_col = "nexo_share_bols")
)

all_tables <- list()
for (sc in scenarios) {
  sub <- cmp[NR_TURNO == sc$turno]
  rows <- lapply(names(sc$tse_cols), function(nm) {
    compute_row(sub, sc$tse_cols[[nm]], sc$nexo_col, nm)
  })
  tab <- data.table::rbindlist(rows)
  tab[, cenario := paste0(sc$cand, "_", sc$turno, "T")]
  all_tables[[length(all_tables) + 1]] <- tab
}
denom_tab <- data.table::rbindlist(all_tables)
data.table::setcolorder(denom_tab, "cenario")

md2("")
md2("### Tabela de diferencas")
md2("")

fmt <- function(x) {
  if (is.na(x)) return("NA")
  if (abs(x) < 1e-6) return("0")
  if (abs(x) < 0.01) return(sprintf("%.6f", x))
  sprintf("%.4f", x)
}

for (sc_name in unique(denom_tab$cenario)) {
  md2("#### ", sc_name)
  md2("")
  md2("| denominador | mean abs diff | median abs diff | p95 abs diff | max abs diff | N munis >0.1pp | N munis >1pp |")
  md2("|---|---:|---:|---:|---:|---:|---:|")
  sub <- denom_tab[cenario == sc_name]
  for (i in seq_len(nrow(sub))) {
    md2("| ", sub$denominador[i],
        " | ", fmt(sub$mean_abs_diff[i]),
        " | ", fmt(sub$median_abs_diff[i]),
        " | ", fmt(sub$p95_abs_diff[i]),
        " | ", fmt(sub$max_abs_diff[i]),
        " | ", sub$n_munis_gt_0_1pp[i],
        " | ", sub$n_munis_gt_1pp[i], " |")
  }
  md2("")
}

# --- Veredito ------------------------------------------------------------------

# Criterio: denominador "bate" se max_abs_diff <= 0.001 em TODOS os cenarios.
by_denom <- denom_tab[, .(
  max_max = max(max_abs_diff, na.rm = TRUE),
  max_mean = max(mean_abs_diff, na.rm = TRUE),
  total_gt_1pp = sum(n_munis_gt_1pp, na.rm = TRUE)
), by = denominador]

md2("")
md2("## VEREDITO")
md2("")
md2("Criterio: um denominador 'bate' se `max_abs_diff <= 0.001` em todos os ",
    "4 cenarios (Lula 1T, Lula 2T, Bolsonaro 1T, Bolsonaro 2T).")
md2("")
md2("| denominador | pior max_abs_diff | pior mean_abs_diff | N total munis diff>1pp | bate? |")
md2("|---|---:|---:|---:|:-:|")

bate <- character(0)
for (i in seq_len(nrow(by_denom))) {
  bateu <- !is.na(by_denom$max_max[i]) && by_denom$max_max[i] <= 0.001
  md2("| ", by_denom$denominador[i],
      " | ", fmt(by_denom$max_max[i]),
      " | ", fmt(by_denom$max_mean[i]),
      " | ", by_denom$total_gt_1pp[i],
      " | ", ifelse(bateu, "SIM", "nao"), " |")
  if (bateu) bate <- c(bate, by_denom$denominador[i])
}

md2("")
if (length(bate) == 0) {
  md2("**Veredito: nenhum denominador bate. Investigar.**")
  md2("")
  md2("Possiveis causas:")
  md2("- Chave de merge errada (TSE CD_MUNICIPIO != Nexojornal `tse`).")
  md2("- Nexojornal usa denominador proprio (ex: subconjunto de secoes apuradas).")
  md2("- Bases referem-se a universos diferentes (ex: exterior incluido/nao).")
  md2("- Erros de arredondamento/tipagem.")
} else if (length(bate) == 1) {
  md2("**Veredito: `", bate,
      "` bate. Claim do autor ",
      ifelse(bate == "nominais", "parece CORRETO",
             "NAO bate com 'QT_VOTOS_NOMINAIS' -- claim do autor esta ERRADO"),
      ".**")
} else {
  md2("**Veredito: multiplos denominadores batem (inesperado): `",
      paste(bate, collapse = "`, `"), "`.**")
}

# =============================================================================
# PERSISTENCIA DOS LOGS EM MARKDOWN
# =============================================================================

log_path  <- file.path(PATH_RESULTS_LOGS, "01_data_build_log.md")
denom_path <- file.path(PATH_RESULTS_LOGS, "01_denominator_check.md")

writeLines(.md_buf, con = log_path, useBytes = FALSE)
writeLines(.denom_buf, con = denom_path, useBytes = FALSE)

log_step("Log de build -> {log_path}")
log_step("Log de denominator -> {denom_path}")

# =============================================================================
# RESUMO NO CONSOLE (para o subagente colher)
# =============================================================================

log_section("Resumo final")
tt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
log_step("Tempo total de execucao: {sprintf('%.1f', tt)}s")
log_step("N secoes unicas (merged): {format(n_secao_unicas, big.mark=',')}")
log_step("N linhas merged: {format(n_merged, big.mark=',')}")
log_step("Candidatos unicos: {n_cand_unicos}")
log_step("Parquet TSE:  {sprintf('%.1f', size_tse)} MB")
log_step("Parquet Nexo: {sprintf('%.1f', size_nexo)} MB")
log_step("Veredito denominador: {ifelse(length(bate)==0, 'NENHUM BATE', paste(bate, collapse=','))}")
