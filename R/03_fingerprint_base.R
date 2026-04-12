# R/03_fingerprint_base.R -- Bloco 2: fingerprints baseline (replicacao)
#
# Gera os 8 fingerprints (joint histogram turnout x vote share) da eleicao
# presidencial 2022:
#   - 2 turnos x 2 niveis (secao, muni) x 2 specs de denominador (nominais,
#     comparecimento) = 8 compositos.
#
# Cada composto tem um candidato por facet:
#   - 1T: Lula (13), Bolsonaro (22), Ciro (12), Tebet (15), Soraya (44).
#   - 2T: Lula (13), Bolsonaro (22).
#
# Brasil only (flag_exterior == FALSE). Exterior e' escopo separado.
#
# Produtos:
#   - output/figures/fig1_fingerprint_T{1,2}_{secao,muni}_{nominais,comparecimento}.pdf
#   - quality_reports/results/03_fingerprint_base_log.md
#
# Referencia: quality_reports/plans/2026-04-10_reconstrucao-metodologica.md (Bloco 2)
# Autor: Manoel Galdino
# Data: 2026-04-10

source(here::here("R", "00_setup.R"))
log_section("Bloco 2 -- fingerprint baseline")

t_start <- Sys.time()

# =============================================================================
# Parametros (ajustaveis)
# =============================================================================
BINS_X         <- 100    # bins no eixo turnout
BINS_Y         <- 100    # bins no eixo vote_share
DENSITY_TRANS  <- "log"  # escala da densidade (massa muito concentrada)
FIG_WIDTH      <- 10     # polegadas (default; sobrescrito por turno)
FIG_HEIGHT     <- 6

# dimensoes especificas por turno (1T = 5 candidatos, 2T = 2)
DIM_T1 <- list(width = 15, height = 4)
DIM_T2 <- list(width = 8,  height = 4)

# =============================================================================
# Buffer de log markdown
# =============================================================================
.md_buf <- character(0)
md <- function(line = "") {
  .md_buf[length(.md_buf) + 1L] <<- line
  message(line)
}

md("# Bloco 2 -- Log de fingerprints baseline")
md("")
md(sprintf("Data de execucao: %s", format(t_start, "%Y-%m-%d %H:%M:%S")))
md("")

md("## Parametros")
md("")
md(sprintf("- `BINS_X` (turnout): %d", BINS_X))
md(sprintf("- `BINS_Y` (vote share): %d", BINS_Y))
md(sprintf("- `DENSITY_TRANS`: %s", DENSITY_TRANS))
md(sprintf("- Dimensoes 1T: %d x %d polegadas", DIM_T1$width, DIM_T1$height))
md(sprintf("- Dimensoes 2T: %d x %d polegadas", DIM_T2$width, DIM_T2$height))
md(sprintf("- Escopo: Brasil only (flag_exterior == FALSE)"))
md("")

# =============================================================================
# Funcao de plot (reutilizavel)
# =============================================================================
plot_fingerprint <- function(data, x_col, y_col, candidato_nome, nivel,
                             spec_label, n_obs,
                             bins_x = BINS_X, bins_y = BINS_Y) {
  ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_bin_2d(bins = c(bins_x, bins_y)) +
    scale_fill_viridis_c(
      trans  = DENSITY_TRANS,
      option = "inferno",
      name   = "N"
    ) +
    scale_x_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2),
      labels = scales::percent_format(accuracy = 1)
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2),
      labels = scales::percent_format(accuracy = 1)
    ) +
    coord_fixed() +
    labs(
      title    = candidato_nome,
      subtitle = glue::glue("{nivel} | vote share: {spec_label} | N = {scales::comma(n_obs)}"),
      x        = "Turnout",
      y        = "Vote share"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      plot.title        = element_text(face = "bold"),
      plot.subtitle     = element_text(size = 8, color = "grey30"),
      panel.grid        = element_line(color = "grey90", linewidth = 0.25),
      legend.key.height = unit(0.6, "cm")
    )
}

# =============================================================================
# Carregar parquets (secao + muni)
# =============================================================================
log_step("Carregando parquets de secao e municipio")

secao <- arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet")
)
setDT(secao)

muni <- arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_muni_clean.parquet")
)
setDT(muni)

log_step("Parquet secao: {nrow(secao)} linhas, {ncol(secao)} colunas")
log_step("Parquet muni:  {nrow(muni)} linhas, {ncol(muni)} colunas")

# =============================================================================
# Filtrar Brasil only
# =============================================================================
n_secao_total <- nrow(secao)
n_muni_total  <- nrow(muni)

secao_br <- secao[flag_exterior == FALSE]
muni_br  <- muni[flag_exterior == FALSE]

n_secao_ext <- n_secao_total - nrow(secao_br)
n_muni_ext  <- n_muni_total  - nrow(muni_br)

log_step("Secao Brasil: {nrow(secao_br)} ({n_secao_ext} exterior removidas)")
log_step("Muni Brasil:  {nrow(muni_br)} ({n_muni_ext} exterior removidas)")

md("## Exclusoes (exterior)")
md("")
md("| Nivel | Total | Brasil only | Exterior removidas |")
md("|---|---:|---:|---:|")
md(sprintf("| secao | %s | %s | %s |",
           scales::comma(n_secao_total),
           scales::comma(nrow(secao_br)),
           scales::comma(n_secao_ext)))
md(sprintf("| muni  | %s | %s | %s |",
           scales::comma(n_muni_total),
           scales::comma(nrow(muni_br)),
           scales::comma(n_muni_ext)))
md("")

# =============================================================================
# Catalogo de candidatos por turno (chave canonica = NR_VOTAVEL)
# =============================================================================
CANDIDATOS <- list(
  `1` = data.table(
    NR_VOTAVEL = c(13L, 22L, 12L, 15L, 44L),
    label      = c("Lula (13)", "Bolsonaro (22)", "Ciro Gomes (12)",
                   "Simone Tebet (15)", "Soraya Thronicke (44)")
  ),
  `2` = data.table(
    NR_VOTAVEL = c(13L, 22L),
    label      = c("Lula (13)", "Bolsonaro (22)")
  )
)

# Sanity: verificar que os NR_VOTAVEL existem nos dados
md("## Candidatos plotados")
md("")
md("| Turno | NR_VOTAVEL | Label | NM_VOTAVEL (dados) |")
md("|---:|---:|---|---|")
for (turno in c("1", "2")) {
  cat_t <- CANDIDATOS[[turno]]
  for (i in seq_len(nrow(cat_t))) {
    nr <- cat_t$NR_VOTAVEL[i]
    lbl <- cat_t$label[i]
    nm_found <- unique(secao_br[NR_TURNO == as.integer(turno) & NR_VOTAVEL == nr, NM_VOTAVEL])
    nm_found <- if (length(nm_found) == 0) "(ausente!)" else paste(nm_found, collapse = "; ")
    md(sprintf("| %s | %d | %s | %s |", turno, nr, lbl, nm_found))
  }
}
md("")

# =============================================================================
# Pipeline: 8 compositos
# =============================================================================
log_step("Gerando 8 compositos")

# specs de denominador: coluna do y + label legivel
SPECS <- list(
  nominais        = list(y_col = "vote_share_nominais",        label = "nominais"),
  comparecimento  = list(y_col = "vote_share_comparecimento",  label = "comparecimento")
)

# tabelas para logging
n_tab   <- data.table(turno = integer(), nivel = character(),
                      spec = character(), n = integer())
files_tab <- data.table(arquivo = character(), size_kb = numeric(),
                        exists = logical(), ok = logical())

for (turno_int in c(1L, 2L)) {
  turno_chr <- as.character(turno_int)
  cat_t     <- CANDIDATOS[[turno_chr]]
  dim_t     <- if (turno_int == 1L) DIM_T1 else DIM_T2
  ncol_wrap <- nrow(cat_t)

  for (nivel in c("secao", "muni")) {
    dat_all <- if (nivel == "secao") secao_br else muni_br
    dat_t   <- dat_all[NR_TURNO == turno_int]
    n_level_turno <- nrow(dat_t)
    n_unique_units <- if (nivel == "secao") {
      uniqueN(dat_t, by = c("CD_MUNICIPIO", "NR_ZONA", "NR_SECAO"))
    } else {
      uniqueN(dat_t, by = "CD_MUNICIPIO")
    }

    for (spec_name in names(SPECS)) {
      spec <- SPECS[[spec_name]]
      y_col <- spec$y_col
      spec_label <- spec$label

      # filtrar validos (nao NA no x e y dentro do painel)
      plots_list <- vector("list", nrow(cat_t))
      n_plotted_total <- 0L

      for (i in seq_len(nrow(cat_t))) {
        nr   <- cat_t$NR_VOTAVEL[i]
        lbl  <- cat_t$label[i]
        dat_c <- dat_t[NR_VOTAVEL == nr &
                         !is.na(turnout) &
                         !is.na(get(y_col))]
        n_c <- nrow(dat_c)
        n_plotted_total <- n_plotted_total + n_c

        plots_list[[i]] <- plot_fingerprint(
          data           = dat_c,
          x_col          = "turnout",
          y_col          = y_col,
          candidato_nome = lbl,
          nivel          = nivel,
          spec_label     = spec_label,
          n_obs          = n_c
        )
      }

      composite <- patchwork::wrap_plots(plots_list, ncol = ncol_wrap) +
        patchwork::plot_annotation(
          title    = glue::glue("Fingerprint 2022 -- {turno_int}o turno -- nivel: {nivel}"),
          subtitle = glue::glue(
            "Vote share denom: {spec_label} | bins: {BINS_X}x{BINS_Y} | ",
            "densidade: {DENSITY_TRANS} | Brasil only | ",
            "unidades unicas: {scales::comma(n_unique_units)}"
          ),
          theme    = theme(
            plot.title    = element_text(face = "bold", size = 12),
            plot.subtitle = element_text(size = 9, color = "grey30")
          )
        )

      fname <- glue::glue("fig1_fingerprint_T{turno_int}_{nivel}_{spec_name}.pdf")
      fpath <- file.path(PATH_OUTPUT_FIGURES, fname)

      ggsave(
        filename = fpath,
        plot     = composite,
        width    = dim_t$width,
        height   = dim_t$height,
        units    = "in"
      )

      fi <- file.info(fpath)
      size_kb <- if (is.na(fi$size)) NA_real_ else fi$size / 1024
      exists_flag <- file.exists(fpath)
      ok_flag <- exists_flag && !is.na(size_kb) && size_kb > 10

      files_tab <- rbind(files_tab, data.table(
        arquivo = as.character(fname),
        size_kb = round(size_kb, 1),
        exists  = exists_flag,
        ok      = ok_flag
      ))

      n_tab <- rbind(n_tab, data.table(
        turno = turno_int,
        nivel = nivel,
        spec  = spec_name,
        n     = n_plotted_total
      ))

      log_step("Gerado: {fname} ({round(size_kb,1)} KB, {n_plotted_total} obs)")
    }
  }
}

# =============================================================================
# Log: N por (turno x nivel x spec)
# =============================================================================
md("## N por (turno x nivel x spec)")
md("")
md("N = soma de observacoes plotadas (uma linha por candidato x unidade) no composto.")
md("")
md("| Turno | Nivel | Spec | N |")
md("|---:|---|---|---:|")
for (i in seq_len(nrow(n_tab))) {
  md(sprintf("| %d | %s | %s | %s |",
             n_tab$turno[i], n_tab$nivel[i], n_tab$spec[i],
             scales::comma(n_tab$n[i])))
}
md("")

# =============================================================================
# Log: arquivos gerados + sanity checks
# =============================================================================
md("## Arquivos gerados")
md("")
md("| Arquivo | Tamanho (KB) | Existe | Sanity OK (>10 KB) |")
md("|---|---:|:---:|:---:|")
for (i in seq_len(nrow(files_tab))) {
  md(sprintf("| `%s` | %.1f | %s | %s |",
             files_tab$arquivo[i],
             files_tab$size_kb[i],
             ifelse(files_tab$exists[i], "sim", "NAO"),
             ifelse(files_tab$ok[i], "sim", "NAO")))
}
md("")

n_ok <- sum(files_tab$ok)
n_expected <- nrow(files_tab)
md(sprintf("Sanity: %d/%d arquivos passam (existem e > 10 KB).",
           n_ok, n_expected))
md("")

if (n_ok < n_expected) {
  cli::cli_warn("Sanity check falhou: {n_expected - n_ok} arquivo(s) fora do esperado")
}

# =============================================================================
# Observacoes visuais -- PENDENTE
# =============================================================================
# Leitura qualitativa das 8 figuras fica para o autor validar abrindo os PDFs
# em output/figures/. O log nao contem expectativas a priori para evitar
# confundir hipoteses com observacoes.
md("## Observacoes visuais")
md("")
md("Pendente: validacao visual pelo autor. Abrir os PDFs em `output/figures/`.")
md("As figuras geram (turnout x vote_share) bin2d para cada candidato nos 8 cortes")
md("(turno x nivel x spec de denominador). Ler qualitativamente para identificar:")
md("")
md("- Presenca/ausencia de clusters descolados do corpo principal da distribuicao")
md("- Forma do modo (unimodal, bimodal regional) por candidato e turno")
md("- Diferenca qualitativa entre specs `nominais` vs `comparecimento`")
md("- Comportamento na borda (turnout -> 1, vote share -> 1) -- assinatura classica")
md("  de ballot stuffing se houver cluster no canto superior direito")
md("")
md("Essa leitura alimenta o desenho do Bloco 3 (testes formais) mas nao substitui teste.")
md("")

# =============================================================================
# Tempo total e escrita do log
# =============================================================================
t_end <- Sys.time()
dt_secs <- as.numeric(difftime(t_end, t_start, units = "secs"))

md("## Tempo de execucao")
md("")
md(sprintf("- Inicio: %s", format(t_start, "%Y-%m-%d %H:%M:%S")))
md(sprintf("- Fim:    %s", format(t_end,   "%Y-%m-%d %H:%M:%S")))
md(sprintf("- Total:  %.1f segundos", dt_secs))
md("")

log_path <- file.path(PATH_RESULTS_LOGS, "03_fingerprint_base_log.md")
writeLines(.md_buf, con = log_path, useBytes = FALSE)
log_step("Log -> {log_path}")

log_section("Resumo Bloco 2")
log_step("Tempo total: {sprintf('%.1f', dt_secs)}s")
log_step("Arquivos gerados: {n_ok}/{n_expected}")
log_step("Log markdown: {log_path}")
