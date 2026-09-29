# R/02_build_vars.R -- Bloco 1 Fase B: build variaveis de analise
#
# Le o parquet de secao produzido em Fase A, limpa colunas duplicadas i.*,
# aplica exclusoes hard (aptos=0, comparecimento=0, nominais=0), constroi
# turnout + dois vote shares (nominais e comparecimento) como especificacoes
# de primeira classe, agrega para municipio, faz verificacao-espelho contra
# Nexojornal e persiste.
#
# Produtos:
#   - data/processed/brasil_2022_secao_clean.parquet
#   - data/processed/brasil_2022_muni_clean.parquet
#   - quality_reports/results/02_build_vars_log.md
#
# Referencia: quality_reports/plans/2026-04-10_reconstrucao-metodologica.md
# Autor: Manoel Galdino
# Data: 2026-04-10

source(here::here("R", "00_setup.R"))
log_section("Bloco 1 Fase B -- build vars")

t_start <- Sys.time()

# ---- buffer de log markdown --------------------------------------------------
.md_buf <- character(0)
md <- function(line = "") {
  .md_buf[length(.md_buf) + 1L] <<- line
  message(line)
}

md("# Bloco 1 Fase B -- Log de build de variaveis")
md("")
md(sprintf("Data de execucao: %s", format(t_start, "%Y-%m-%d %H:%M:%S")))
md("")

# =============================================================================
# PASSO 1 -- leitura do parquet de secao
# =============================================================================
md("## Leitura")
md("")

path_in <- file.path(PATH_DATA_PROCESSED, "brasil_2022_secao.parquet")
log_step("Lendo parquet secao: {path_in}")
secao_raw <- arrow::read_parquet(path_in)
data.table::setDT(secao_raw)
log_step("Parquet secao carregado: {nrow(secao_raw)} linhas, {ncol(secao_raw)} colunas")

md(sprintf("- Arquivo: `%s`", path_in))
md(sprintf("- Linhas: %s", format(nrow(secao_raw), big.mark = ",")))
md(sprintf("- Colunas: %d", ncol(secao_raw)))
md("")

# =============================================================================
# PASSO 2 -- limpeza de colunas duplicadas i.*
# =============================================================================
md("## Limpeza de colunas i.*")
md("")

all_cols <- names(secao_raw)
i_cols <- grep("^i\\.", all_cols, value = TRUE)
md(sprintf("- Colunas `i.*` detectadas: %d (%s)",
           length(i_cols),
           paste(i_cols, collapse = ", ")))

cols_removed <- character(0)
cols_conflict <- character(0)
for (ic in i_cols) {
  base_col <- sub("^i\\.", "", ic)
  if (!base_col %in% all_cols) {
    md(sprintf("- `%s` nao tem contraparte base -- mantido", ic))
    next
  }
  v_base <- secao_raw[[base_col]]
  v_i    <- secao_raw[[ic]]
  # comparacao estrita; NA em ambos lados conta como igual
  same <- identical(v_base, v_i) ||
    (length(v_base) == length(v_i) &&
       all((is.na(v_base) & is.na(v_i)) |
             (!is.na(v_base) & !is.na(v_i) & v_base == v_i)))
  if (isTRUE(same)) {
    secao_raw[, (ic) := NULL]
    cols_removed <- c(cols_removed, ic)
  } else {
    cols_conflict <- c(cols_conflict, ic)
  }
}

if (length(cols_conflict) > 0) {
  md(sprintf("- ERRO: colunas `i.*` com valores DIFERENTES da base: %s",
             paste(cols_conflict, collapse = ", ")))
  stop("Colunas i.* com valores divergentes da base. Merge da Fase A suspeito. ",
       "Investigar antes de prosseguir.")
}

md(sprintf("- Colunas `i.*` removidas (identicas a base): %d", length(cols_removed)))
md(sprintf("- Colunas apos limpeza: %d", ncol(secao_raw)))
md("")

log_step("Removidas {length(cols_removed)} colunas i.* (todas identicas a base)")

# =============================================================================
# PASSO 3 -- flags de edge cases (pre-exclusao)
# =============================================================================
md("## Flags e edge cases")
md("")

# Como uma "secao-turno" se repete por candidato, para contar por secao-turno
# extraimos uma tabela unica por chave de secao-turno e avaliamos os flags la.
key_secao <- c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO", "NR_TURNO")

# Tabela unica de secoes-turno com as quantidades (QT_APTOS etc sao identicas
# entre linhas da mesma secao-turno independentemente de candidato).
secao_unicas <- unique(
  secao_raw[, c(key_secao,
                "QT_APTOS", "QT_COMPARECIMENTO", "QT_VOTOS_NOMINAIS"),
            with = FALSE],
  by = key_secao
)

secao_unicas[, `:=`(
  flag_aptos_zero            = QT_APTOS == 0,
  flag_comparecimento_zero   = QT_COMPARECIMENTO == 0,
  flag_nominais_zero         = QT_VOTOS_NOMINAIS == 0,
  flag_comparecimento_excede = QT_COMPARECIMENTO > QT_APTOS,
  flag_exterior              = SG_UF == "ZZ"
)]

n_secoes_total <- nrow(secao_unicas)
md(sprintf("- Total de secoes-turno unicas: %s",
           format(n_secoes_total, big.mark = ",")))
md("")
md("Contagens por secao-turno (nao por linha-candidato):")
md("")
md("| Flag | N secoes-turno | % |")
md("|---|---:|---:|")
for (fl in c("flag_aptos_zero", "flag_comparecimento_zero",
             "flag_nominais_zero", "flag_comparecimento_excede",
             "flag_exterior")) {
  n_fl <- sum(secao_unicas[[fl]], na.rm = TRUE)
  md(sprintf("| `%s` | %s | %.3f%% |",
             fl,
             format(n_fl, big.mark = ","),
             100 * n_fl / n_secoes_total))
}
md("")

# Exterior: separar contagem para Brasil vs Exterior
n_br  <- sum(!secao_unicas$flag_exterior)
n_zz  <- sum(secao_unicas$flag_exterior)
md(sprintf("- Secoes-turno Brasil (SG_UF != ZZ): %s",
           format(n_br, big.mark = ",")))
md(sprintf("- Secoes-turno Exterior (SG_UF == ZZ): %s",
           format(n_zz, big.mark = ",")))
md("")

# =============================================================================
# PASSO 4 -- exclusoes hard
# =============================================================================
md("## Exclusoes hard")
md("")

# Identifica as chaves de secao-turno a excluir.
excl_aptos   <- secao_unicas[flag_aptos_zero == TRUE,          ..key_secao]
excl_compar  <- secao_unicas[flag_comparecimento_zero == TRUE, ..key_secao]
excl_nom     <- secao_unicas[flag_nominais_zero == TRUE,       ..key_secao]

n_excl_aptos  <- nrow(excl_aptos)
n_excl_compar <- nrow(excl_compar)
n_excl_nom    <- nrow(excl_nom)

# Uniao (secoes excluidas por qualquer motivo).
excl_union <- unique(rbindlist(list(excl_aptos, excl_compar, excl_nom)),
                     by = key_secao)
n_excl_union <- nrow(excl_union)

# Intersecao (secoes excluidas por TODOS os tres motivos simultaneamente).
# Para isso, merge sucessivo.
if (n_excl_aptos > 0 && n_excl_compar > 0 && n_excl_nom > 0) {
  inter <- merge(excl_aptos, excl_compar, by = key_secao)
  inter <- merge(inter, excl_nom, by = key_secao)
  n_inter <- nrow(inter)
} else {
  n_inter <- 0L
}

md("Motivos de exclusao (podem se sobrepor):")
md("")
md("| Motivo | N secoes-turno |")
md("|---|---:|")
md(sprintf("| QT_APTOS == 0 (turnout indefinido)            | %s |",
           format(n_excl_aptos,  big.mark = ",")))
md(sprintf("| QT_COMPARECIMENTO == 0 (share_compar indef.)  | %s |",
           format(n_excl_compar, big.mark = ",")))
md(sprintf("| QT_VOTOS_NOMINAIS == 0 (share_nominais indef.) | %s |",
           format(n_excl_nom,    big.mark = ",")))
md(sprintf("| **Uniao (excluidas do dataset)**              | **%s** |",
           format(n_excl_union,  big.mark = ",")))
md(sprintf("| Intersecao (todos os tres motivos)            | %s |",
           format(n_inter,       big.mark = ",")))
md("")

# Aplicar a exclusao: drop das linhas cujas chaves estao em excl_union.
# anti-join via merge com flag.
excl_union[, drop := TRUE]
secao <- merge(secao_raw, excl_union, by = key_secao, all.x = TRUE)
n_pre <- nrow(secao)
secao <- secao[is.na(drop)]
secao[, drop := NULL]
n_pos <- nrow(secao)

n_secoes_clean <- nrow(unique(secao[, ..key_secao]))

md(sprintf("- Linhas antes da exclusao: %s",
           format(n_pre, big.mark = ",")))
md(sprintf("- Linhas depois da exclusao: %s",
           format(n_pos, big.mark = ",")))
md(sprintf("- Secoes-turno unicas remanescentes: %s (de %s)",
           format(n_secoes_clean, big.mark = ","),
           format(n_secoes_total, big.mark = ",")))
md("")

log_step("Exclusoes: {n_excl_union} secoes-turno removidas, ",
         "{n_secoes_clean} remanescentes")

# ---- filtragem de pseudo-candidatos (branco/nulo) ---------------------------
# A Fase A manteve NR_VOTAVEL 95 (BRANCO) e 96 (NULO) como linhas no
# desdobramento por candidato. Para calcular vote_share_nominais a nivel
# de candidato, precisamos excluir essas linhas: QT_VOTOS de branco/nulo
# nao e numerador valido para vote_share_nominais (que tem QT_VOTOS_NOMINAIS
# como denominador e exclui branco/nulo por definicao). Mantemos apenas
# os 11 candidatos reais (NR_VOTAVEL < 95).
n_pre_cand <- nrow(secao)
n_pseudo   <- nrow(secao[NR_VOTAVEL %in% c(95L, 96L)])
secao <- secao[!(NR_VOTAVEL %in% c(95L, 96L))]
n_pos_cand <- nrow(secao)
md(sprintf("- Linhas de pseudo-candidato (NR_VOTAVEL 95/96) removidas: %s",
           format(n_pseudo, big.mark = ",")))
md(sprintf("- Linhas restantes (candidatos reais): %s",
           format(n_pos_cand, big.mark = ",")))
md("  Justificativa: branco/nulo nao sao numerador valido para")
md("  `vote_share_nominais` (ja excluidos do denominador por construcao).")
md("  Manter geraria vote_share > 1 em secoes com muitos nulos.")
md("")

log_step("Pseudo-candidatos removidos: {n_pseudo} linhas (branco/nulo)")

# =============================================================================
# PASSO 5 -- construcao de variaveis
# =============================================================================
md("## Construcao de variaveis")
md("")

secao[, `:=`(
  turnout                   = QT_COMPARECIMENTO / QT_APTOS,
  vote_share_nominais       = QT_VOTOS / QT_VOTOS_NOMINAIS,
  vote_share_comparecimento = QT_VOTOS / QT_COMPARECIMENTO,
  n_eleitores_secao         = QT_APTOS
)]

# Sanity check -- todas as razoes devem estar em [0, 1].
check_range <- function(x, nm) {
  n_tot <- length(x)
  n_na  <- sum(is.na(x))
  rmin  <- suppressWarnings(min(x, na.rm = TRUE))
  rmax  <- suppressWarnings(max(x, na.rm = TRUE))
  n_below <- sum(x < 0, na.rm = TRUE)
  n_above <- sum(x > 1, na.rm = TRUE)
  list(nm = nm, n = n_tot, n_na = n_na, min = rmin, max = rmax,
       n_below = n_below, n_above = n_above)
}

chk_turnout <- check_range(secao$turnout, "turnout")
chk_nom     <- check_range(secao$vote_share_nominais, "vote_share_nominais")
chk_com     <- check_range(secao$vote_share_comparecimento, "vote_share_comparecimento")

md("Sanity check das razoes (uma linha por candidato x secao-turno):")
md("")
md("| Variavel | min | max | N < 0 | N > 1 | N NA |")
md("|---|---:|---:|---:|---:|---:|")
for (chk in list(chk_turnout, chk_nom, chk_com)) {
  md(sprintf("| `%s` | %.6f | %.6f | %s | %s | %s |",
             chk$nm, chk$min, chk$max,
             format(chk$n_below, big.mark = ","),
             format(chk$n_above, big.mark = ","),
             format(chk$n_na,    big.mark = ",")))
}
md("")

n_out_of_range <- chk_turnout$n_below + chk_turnout$n_above +
  chk_nom$n_below + chk_nom$n_above +
  chk_com$n_below + chk_com$n_above

if (n_out_of_range > 0) {
  # Coleta algumas linhas problematicas para reportar.
  bad <- secao[turnout < 0 | turnout > 1 |
                 vote_share_nominais < 0 | vote_share_nominais > 1 |
                 vote_share_comparecimento < 0 | vote_share_comparecimento > 1]
  md(sprintf("**ERRO: %d linhas fora de [0,1].** Amostra:",
             n_out_of_range))
  md("")
  md("```")
  md(paste(capture.output(print(head(bad, 20))), collapse = "\n"))
  md("```")
  md("")
  # Persistir log mesmo antes de parar.
  log_path <- file.path(PATH_RESULTS_LOGS, "02_build_vars_log.md")
  writeLines(.md_buf, con = log_path, useBytes = FALSE)
  stop("Valores fora de [0,1] detectados. Ver log em ", log_path)
}

md("- Todas as razoes estao em [0, 1]. Sanity check OK.")
md("")

# Crosswalk UF -> regiao (padrao IBGE)
regiao_lookup <- data.table(
  SG_UF = c("AC","AP","AM","PA","RO","RR","TO",
            "AL","BA","CE","MA","PB","PE","PI","RN","SE",
            "DF","GO","MT","MS",
            "ES","MG","RJ","SP",
            "PR","RS","SC",
            "ZZ"),
  regiao = c(rep("Norte", 7),
             rep("Nordeste", 9),
             rep("Centro-Oeste", 4),
             rep("Sudeste", 4),
             rep("Sul", 3),
             "Exterior")
)
# Join preservando secao como destino. regiao_lookup[secao, on=...] gera
# uma nova data.table -- reatribuimos.
secao <- regiao_lookup[secao, on = "SG_UF"]

n_uf_sem_regiao <- sum(is.na(secao$regiao))
md(sprintf("- UFs sem regiao apos crosswalk: %d", n_uf_sem_regiao))
if (n_uf_sem_regiao > 0) {
  ufs_orf <- unique(secao[is.na(regiao), SG_UF])
  md(sprintf("- UFs orfas: %s", paste(ufs_orf, collapse = ", ")))
  stop("UFs sem regiao detectadas: ", paste(ufs_orf, collapse = ", "))
}
md("")

# Re-anexa flags de edge case por secao-turno (util para downstream).
# Como secao_unicas ainda tem flag_exterior e flag_comparecimento_excede,
# anexamos via merge.
flags_tbl <- secao_unicas[, c(key_secao,
                              "flag_exterior",
                              "flag_comparecimento_excede"), with = FALSE]
secao <- flags_tbl[secao, on = key_secao]

# =============================================================================
# PASSO 6 -- drop de colunas e persistencia nivel secao
# =============================================================================
md("## Persistencia")
md("")

# Colunas a dropar (constantes ou redundantes para esta analise).
cols_drop <- c("ANO_ELEICAO", "CD_CARGO", "DS_CARGO", "QT_VOTOS_LEGENDA",
               "QT_VOTOS_ANULADOS_APU_SEP")
cols_drop <- intersect(cols_drop, names(secao))
if (length(cols_drop) > 0) {
  secao[, (cols_drop) := NULL]
}
md(sprintf("- Colunas dropadas (constantes/redundantes): %s",
           paste(cols_drop, collapse = ", ")))

# Ordem final das colunas.
cols_final <- c(
  # chaves
  "SG_UF", "regiao", "CD_MUNICIPIO", "NM_MUNICIPIO",
  "NR_ZONA", "NR_SECAO", "NR_TURNO",
  # candidato
  "NR_VOTAVEL", "NM_VOTAVEL",
  # contagens
  "QT_VOTOS", "QT_APTOS", "QT_COMPARECIMENTO",
  "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
  "QT_ABSTENCOES",
  # razoes
  "turnout", "vote_share_nominais", "vote_share_comparecimento",
  # metadados
  "n_eleitores_secao", "flag_exterior", "flag_comparecimento_excede"
)
# Se alguma coluna esperada nao existe, reportamos.
missing_cols <- setdiff(cols_final, names(secao))
if (length(missing_cols) > 0) {
  md(sprintf("- AVISO: colunas esperadas ausentes: %s",
             paste(missing_cols, collapse = ", ")))
}
extra_cols <- setdiff(names(secao), cols_final)
if (length(extra_cols) > 0) {
  md(sprintf("- Colunas extras (mantidas no fim): %s",
             paste(extra_cols, collapse = ", ")))
}
setcolorder(secao, c(intersect(cols_final, names(secao)), extra_cols))

path_out_secao <- file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet")
arrow::write_parquet(secao, path_out_secao)
size_secao_mb <- file.info(path_out_secao)$size / (1024^2)
md(sprintf("- Parquet secao-nivel: `%s` (%.1f MB)",
           path_out_secao, size_secao_mb))
md(sprintf("- Linhas: %s, colunas: %d",
           format(nrow(secao), big.mark = ","), ncol(secao)))
md("")

log_step("Parquet secao-clean persistido: {sprintf('%.1f', size_secao_mb)} MB")

# =============================================================================
# PASSO 7 -- agregacao para nivel municipio
# =============================================================================
md("## Agregacao municipio")
md("")

# ATENCAO AO DOUBLE-COUNTING:
# A tabela `secao` tem N linhas por secao-turno (uma por candidato presente
# naquela secao). Somar QT_APTOS naïvemente por municipio inflariam o total
# por um fator igual ao numero de candidatos distintos.
#
# Padrao correto: agregar *uma linha unica por secao-turno* primeiro
# (usando `unique()` sobre a chave + colunas nao-candidato), somar dessa
# tabela limpa para obter totais municipais (QT_APTOS, QT_COMPARECIMENTO,
# QT_VOTOS_NOMINAIS, QT_VOTOS_BRANCOS, QT_VOTOS_NULOS). Depois agregar
# *separadamente* a soma de QT_VOTOS por (municipio, turno, candidato), e
# fazer inner join.
md("Padrao de agregacao: evita double-counting separando (1) totais por")
md("secao-turno unicos e (2) votos por candidato; combina via inner join")
md("no nivel municipio x turno.")
md("")

cols_unico_secao <- c("SG_UF", "regiao", "CD_MUNICIPIO", "NM_MUNICIPIO",
                      "NR_ZONA", "NR_SECAO", "NR_TURNO",
                      "QT_APTOS", "QT_COMPARECIMENTO",
                      "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS",
                      "QT_VOTOS_NULOS")

secao_unico <- unique(secao[, ..cols_unico_secao],
                      by = c("SG_UF", "CD_MUNICIPIO",
                             "NR_ZONA", "NR_SECAO", "NR_TURNO"))

md(sprintf("- Tabela de secoes-turno unicas: %s linhas",
           format(nrow(secao_unico), big.mark = ",")))

# Totais municipio x turno (sem double-counting).
muni_tot <- secao_unico[, .(
  QT_APTOS          = sum(QT_APTOS),
  QT_COMPARECIMENTO = sum(QT_COMPARECIMENTO),
  QT_VOTOS_NOMINAIS = sum(QT_VOTOS_NOMINAIS),
  QT_VOTOS_BRANCOS  = sum(QT_VOTOS_BRANCOS),
  QT_VOTOS_NULOS    = sum(QT_VOTOS_NULOS),
  n_secoes          = .N
), by = .(SG_UF, regiao, CD_MUNICIPIO, NM_MUNICIPIO, NR_TURNO)]

md(sprintf("- Totais municipio x turno: %s linhas",
           format(nrow(muni_tot), big.mark = ",")))

# Votos por municipio x turno x candidato.
muni_cand <- secao[, .(
  QT_VOTOS = sum(QT_VOTOS)
), by = .(SG_UF, regiao, CD_MUNICIPIO, NM_MUNICIPIO,
          NR_TURNO, NR_VOTAVEL, NM_VOTAVEL)]

md(sprintf("- Votos por municipio x turno x candidato: %s linhas",
           format(nrow(muni_cand), big.mark = ",")))

# Combina.
muni <- merge(muni_cand, muni_tot,
              by = c("SG_UF", "regiao", "CD_MUNICIPIO", "NM_MUNICIPIO",
                     "NR_TURNO"),
              all.x = TRUE)

muni[, `:=`(
  turnout                   = QT_COMPARECIMENTO / QT_APTOS,
  vote_share_nominais       = QT_VOTOS / QT_VOTOS_NOMINAIS,
  vote_share_comparecimento = QT_VOTOS / QT_COMPARECIMENTO,
  n_eleitores_muni          = QT_APTOS,
  flag_exterior             = SG_UF == "ZZ"
)]

# Sanity: N de municipios unicos.
n_muni_unicos <- uniqueN(muni[, .(SG_UF, CD_MUNICIPIO)])
n_muni_br     <- uniqueN(muni[SG_UF != "ZZ", .(SG_UF, CD_MUNICIPIO)])
n_muni_zz     <- uniqueN(muni[SG_UF == "ZZ", .(SG_UF, CD_MUNICIPIO)])

md(sprintf("- N municipios unicos: %s (Brasil: %s; Exterior: %s)",
           format(n_muni_unicos, big.mark = ","),
           format(n_muni_br,     big.mark = ","),
           format(n_muni_zz,     big.mark = ",")))

# Linhas por candidato-turno.
cand_turno <- muni[, .N, by = .(NR_TURNO, NR_VOTAVEL, NM_VOTAVEL)][
  order(NR_TURNO, -N)]
md("")
md("Linhas por turno x candidato (quantos municipios tem cada):")
md("")
md("| NR_TURNO | NR_VOTAVEL | NM_VOTAVEL | N municipios |")
md("|---:|---:|---|---:|")
for (i in seq_len(nrow(cand_turno))) {
  md(sprintf("| %d | %d | %s | %s |",
             cand_turno$NR_TURNO[i],
             cand_turno$NR_VOTAVEL[i],
             cand_turno$NM_VOTAVEL[i],
             format(cand_turno$N[i], big.mark = ",")))
}
md("")

# Sanity check das razoes em nivel muni.
chk_t  <- check_range(muni$turnout, "turnout")
chk_n  <- check_range(muni$vote_share_nominais, "vote_share_nominais")
chk_c  <- check_range(muni$vote_share_comparecimento, "vote_share_comparecimento")

md("Sanity check das razoes no nivel municipio:")
md("")
md("| Variavel | min | max | N < 0 | N > 1 | N NA |")
md("|---|---:|---:|---:|---:|---:|")
for (chk in list(chk_t, chk_n, chk_c)) {
  md(sprintf("| `%s` | %.6f | %.6f | %s | %s | %s |",
             chk$nm, chk$min, chk$max,
             format(chk$n_below, big.mark = ","),
             format(chk$n_above, big.mark = ","),
             format(chk$n_na,    big.mark = ",")))
}
md("")

n_bad_muni <- chk_t$n_below + chk_t$n_above +
  chk_n$n_below + chk_n$n_above +
  chk_c$n_below + chk_c$n_above
if (n_bad_muni > 0) {
  md(sprintf("**ERRO: %d linhas muni fora de [0,1].**", n_bad_muni))
  log_path <- file.path(PATH_RESULTS_LOGS, "02_build_vars_log.md")
  writeLines(.md_buf, con = log_path, useBytes = FALSE)
  stop("muni: razoes fora de [0,1]. Ver log em ", log_path)
}

# =============================================================================
# PASSO 8 -- verificacao-espelho contra Nexojornal
# =============================================================================
md("## Verificacao-espelho denominador")
md("")

path_nexo <- file.path(PATH_DATA_PROCESSED, "nexojornal_muni_2022.parquet")
nexo <- arrow::read_parquet(path_nexo)
setDT(nexo)

md(sprintf("- Nexojornal carregado: %s linhas",
           format(nrow(nexo), big.mark = ",")))

# Chave de join: CD_MUNICIPIO (TSE) <-> nexo$tse (character com leading zeros)
# -- convertemos ambos para integer para comparar.
nexo[, cd_key := as.integer(tse)]
muni[, cd_key := as.integer(CD_MUNICIPIO)]

# Filtra para Lula (13) e Bolsonaro (22), ambos os turnos.
muni_lb <- muni[NR_VOTAVEL %in% c(13L, 22L)]

# Vote share Nexojornal (Lula e Bolsonaro), ambos turnos.
# nexo tem colunas: votos_lula, votos_bolsonaro, validos (por linha =
# municipio x turno).
nexo_shares <- nexo[, .(
  cd_key,
  NR_TURNO,
  share_lula_nexo     = votos_lula     / validos,
  share_bolsonaro_nexo = votos_bolsonaro / validos
)]

# Junta Lula.
muni_lula <- muni_lb[NR_VOTAVEL == 13L,
                     .(cd_key, NR_TURNO,
                       share_lula_tse = vote_share_nominais)]
j_lula <- merge(muni_lula, nexo_shares[, .(cd_key, NR_TURNO, share_lula_nexo)],
                by = c("cd_key", "NR_TURNO"))
j_lula[, diff := abs(share_lula_tse - share_lula_nexo)]

muni_bol <- muni_lb[NR_VOTAVEL == 22L,
                    .(cd_key, NR_TURNO,
                      share_bolsonaro_tse = vote_share_nominais)]
j_bol <- merge(muni_bol, nexo_shares[, .(cd_key, NR_TURNO, share_bolsonaro_nexo)],
               by = c("cd_key", "NR_TURNO"))
j_bol[, diff := abs(share_bolsonaro_tse - share_bolsonaro_nexo)]

md("Comparacao municipio-a-municipio contra Nexojornal (vote_share_nominais):")
md("")
md("| Candidato | Turno | N pareado | max abs diff | mean abs diff |")
md("|---|---:|---:|---:|---:|")
for (t in c(1L, 2L)) {
  subl <- j_lula[NR_TURNO == t]
  subb <- j_bol[NR_TURNO == t]
  md(sprintf("| Lula       | %d | %s | %.6f | %.6f |",
             t, format(nrow(subl), big.mark = ","),
             max(subl$diff, na.rm = TRUE),
             mean(subl$diff, na.rm = TRUE)))
  md(sprintf("| Bolsonaro  | %d | %s | %.6f | %.6f |",
             t, format(nrow(subb), big.mark = ","),
             max(subb$diff, na.rm = TRUE),
             mean(subb$diff, na.rm = TRUE)))
}
md("")

max_diff_overall <- max(c(j_lula$diff, j_bol$diff), na.rm = TRUE)
md(sprintf("- Max abs diff overall (Lula+Bolsonaro, 1T+2T): %.8f",
           max_diff_overall))

if (max_diff_overall > 1e-6) {
  md("")
  md("**ERRO: verificacao-espelho falhou. Agregacao muni diverge de Nexojornal.**")
  md("Amostras com maior diferenca:")
  md("")
  md("```")
  md(paste(capture.output(print(head(
    j_lula[order(-diff)], 10))), collapse = "\n"))
  md("```")
  md("")
  md("```")
  md(paste(capture.output(print(head(
    j_bol[order(-diff)], 10))), collapse = "\n"))
  md("```")
  log_path <- file.path(PATH_RESULTS_LOGS, "02_build_vars_log.md")
  writeLines(.md_buf, con = log_path, useBytes = FALSE)
  stop("Verificacao-espelho falhou (max diff = ", max_diff_overall, ")")
} else {
  md("")
  md("- Verificacao-espelho OK: agregacao secao->municipio reproduz")
  md("  `validos` do Nexojornal dentro de 1e-6 (numericamente exato).")
}
md("")

# Drop cd_key helper antes de persistir muni.
muni[, cd_key := NULL]

# Ordem final de colunas muni.
cols_muni_final <- c(
  "SG_UF", "regiao", "CD_MUNICIPIO", "NM_MUNICIPIO", "NR_TURNO",
  "NR_VOTAVEL", "NM_VOTAVEL",
  "QT_VOTOS", "QT_APTOS", "QT_COMPARECIMENTO",
  "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
  "turnout", "vote_share_nominais", "vote_share_comparecimento",
  "n_secoes", "n_eleitores_muni", "flag_exterior"
)
cols_muni_final <- intersect(cols_muni_final, names(muni))
setcolorder(muni, cols_muni_final)

path_out_muni <- file.path(PATH_DATA_PROCESSED, "brasil_2022_muni_clean.parquet")
arrow::write_parquet(muni, path_out_muni)
size_muni_mb <- file.info(path_out_muni)$size / (1024^2)

md(sprintf("- Parquet municipio-nivel: `%s` (%.1f MB)",
           path_out_muni, size_muni_mb))
md(sprintf("- Linhas: %s, colunas: %d",
           format(nrow(muni), big.mark = ","), ncol(muni)))
md("")

log_step("Parquet muni-clean persistido: {sprintf('%.1f', size_muni_mb)} MB")

# =============================================================================
# Persistencia do log em markdown
# =============================================================================
t_end <- Sys.time()
tt <- as.numeric(difftime(t_end, t_start, units = "secs"))

md("---")
md("")
md(sprintf("**Tempo total de execucao: %.1f segundos**", tt))
md("")

log_path <- file.path(PATH_RESULTS_LOGS, "02_build_vars_log.md")
writeLines(.md_buf, con = log_path, useBytes = FALSE)
log_step("Log de build_vars -> {log_path}")

# =============================================================================
# Resumo final
# =============================================================================
log_section("Resumo Fase B")
log_step("Tempo total: {sprintf('%.1f', tt)}s")
log_step("i.* removidas: {length(cols_removed)}")
log_step("Exclusoes: {n_excl_union} secoes-turno")
log_step("Secoes-turno finais: {n_secoes_clean}")
log_step("Municipios finais: {n_muni_unicos}")
log_step("Max abs diff verificacao-espelho: {sprintf('%.2e', max_diff_overall)}")
log_step("Parquet secao: {sprintf('%.1f', size_secao_mb)} MB")
log_step("Parquet muni:  {sprintf('%.1f', size_muni_mb)} MB")
