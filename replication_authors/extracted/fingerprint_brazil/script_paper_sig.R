# ======================================================================
# Electoral Forensics - FINGERPRINTS
# 2022 presidential elections
# municipal and pooling station level data
# ======================================================================

# ----------------------------------------------------------------------
# 1. Packages
# ----------------------------------------------------------------------
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")

pacman::p_load(
  dplyr,     # manipulação de dados (filter, mutate, group_by, summarise)
  ggplot2,   # criação de gráficos
  patchwork, # combinação de múltiplos gráficos
  janitor,   # limpeza de nomes de variáveis (clean_names)
  readxl,    # leitura de arquivos Excel (.xlsx)
  readr,     # leitura de arquivos texto (csv, tsv) de forma eficiente
  scales,    # formatação de eixos (percentual, separadores, etc.)
  viridis,   # paletas de cores perceptualmente equilibradas
  stringr,  # manipulação de strings (texto),
  tidyverse  #
)

options(scipen = 999)

# ----------------------------------------------------------------------
# 2. Funções auxiliares
# ----------------------------------------------------------------------

padronizar_chaves_secao <- function(base) {
  base %>%
    mutate(
      CD_MUNICIPIO = as.character(CD_MUNICIPIO),
      NR_ZONA = as.character(NR_ZONA),
      NR_SECAO = as.character(NR_SECAO)
    )
}

fazer_fingerprint <- function(base,
                              y_var = "vote_share",
                              titulo,
                              label_y,
                              bins = 35,
                              legenda_fill = "Nº of sections") {
  
  ggplot(base, aes(x = turnout, y = .data[[y_var]])) +
    geom_bin_2d(bins = bins) +
    scale_x_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, 1)
    ) +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, 1)
    ) +
    scale_fill_viridis_c(
      option = "plasma",
      name = legenda_fill
    ) +
    labs(
      x = "Turnout",
      y = label_y,
      title = titulo
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      text = element_text(size = 14)
    )
}

resumir_votos_turno <- function(base, turno) {
  base %>%
    filter(NR_TURNO == turno) %>%
    group_by(NM_VOTAVEL, NR_VOTAVEL) %>%
    summarise(
      total_votos = sum(QT_VOTOS, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      votos_validos = sum(
        total_votos[!NM_VOTAVEL %in% c("VOTO NULO", "VOTO BRANCO")],
        na.rm = TRUE
      ),
      percentual = round(100 * total_votos / votos_validos, 2)
    ) %>%
    select(-votos_validos) %>%
    arrange(desc(total_votos))
}

preparar_base_fingerprint_secao <- function(base, turno) {
  base %>%
    filter(
      NR_TURNO == turno,
      !is.na(turnout),
      !is.na(vote_share),
      between(turnout, 0, 1),
      between(vote_share, 0, 1)
    ) %>%
    distinct(
      ANO_ELEICAO,
      NR_TURNO,
      SG_UF,
      CD_MUNICIPIO,
      NR_ZONA,
      NR_SECAO,
      NM_VOTAVEL,
      turnout,
      vote_share
    )
}

filtrar_candidato <- function(base, candidato) {
  base %>%
    filter(NM_VOTAVEL == candidato)
}

# ----------------------------------------------------------------------
# 3. Municipal level data - first round
# ----------------------------------------------------------------------

dados_municipio_t1 <- read_excel(
  "raw-data/votos_presidente_muni_nexojornal_2022.xlsx",
  sheet = "absoluto-1t-2022"
) %>%
  clean_names() %>%
  mutate(
    turnout = comparecimento / eleitores,
    votacao_lula = x13 / validos,
    votacao_bolsonaro = x22 / validos,
    votacao_tebet = x15 / validos,
    votacao_ciro = x12 / validos,
    votacao_soraia = x44 / validos
  )

dados_municipio_t2 <- read_excel(
  "raw-data/votos_presidente_muni_nexojornal_2022.xlsx",
  sheet = "absoluto-2t-2022"
) %>%
  clean_names() %>%
  mutate(
    comparecimento = as.numeric(comparecimento),
    eleitores = as.numeric(eleitores),
    validos = as.numeric(validos),
    x13 = as.numeric(x13),
    x22 = as.numeric(x22),
    turnout = comparecimento / eleitores,
    votacao_lula = x13 / validos,
    votacao_bolsonaro = x22 / validos
  )

fp_pt_municipio_t1 <- fazer_fingerprint(
  base = dados_municipio_t1,
  y_var = "votacao_lula",
  titulo = "PT (first round)",
  label_y = "Vote share",
  legenda_fill = "Nº of municipalities"
)
fp_pt_municipio_t1

fp_pl_municipio_t1 <- fazer_fingerprint(
  base = dados_municipio_t1,
  y_var = "votacao_bolsonaro",
  titulo = "PL (first round)",
  label_y = "Vote share",
  legenda_fill = "Nº of municipalities"
)
fp_pl_municipio_t1

fig_fingerprint_municipio_t1 <- fp_pt_municipio_t1 + fp_pl_municipio_t1 +
  plot_annotation(
    title = "Fingerprint analysis of turnout and vote share",
    subtitle = "Brazilian presidential election — 1st round (2022)"
  )
fig_fingerprint_municipio_t1

fp_pt_municipio_t2 <- fazer_fingerprint(
  base = dados_municipio_t2,
  y_var = "votacao_lula",
  titulo = "PT (second round)",
  label_y = "Vote share",
  legenda_fill = "Nº of municipalities"
)
fp_pt_municipio_t2

fp_pl_municipio_t2 <- fazer_fingerprint(
  base = dados_municipio_t2,
  y_var = "votacao_bolsonaro",
  titulo = "PL (second round)",
  label_y = "Vote share",
  legenda_fill = "Nº of municipalities"
)
fp_pl_municipio_t2

fig_fingerprint_municipio_t2 <- fp_pt_municipio_t2 + fp_pl_municipio_t2 +
  plot_annotation(
    title = "Fingerprint analysis of turnout and vote share",
    subtitle = "Brazilian presidential election — 2nd round (2022)"
  )
fig_fingerprint_municipio_t2


fig_final <- fig_fingerprint_municipio_t1 / fig_fingerprint_municipio_t2 +
  plot_annotation(
    title = "Fingerprint analysis of turnout and vote share",
    subtitle = "Brazilian presidential election — 2022")

fig_final


# ----------------------------------------------------------------------
# 4. Pooling station data
# ----------------------------------------------------------------------

sections_votes_2022 <- read_csv2(
  "raw-data/votacao_secao_2022_BR.csv",
  locale = locale(encoding = "latin1")
)

sections_seats_2022 <- read_csv2(
  "raw-data/detalhe_votacao_secao_2022_BR.csv",
  locale = locale(encoding = "latin1")
)

sections_seats_pres <- sections_seats_2022 %>%
  filter(
    DS_CARGO == "PRESIDENTE",
    NR_TURNO %in% c(1, 2)
  ) %>%
  select(
    ANO_ELEICAO, NR_TURNO, SG_UF, CD_MUNICIPIO, NM_MUNICIPIO,
    NR_ZONA, NR_SECAO,
    QT_APTOS, QT_COMPARECIMENTO, QT_ABSTENCOES,
    QT_VOTOS_NOMINAIS, QT_VOTOS_BRANCOS, QT_VOTOS_NULOS
  ) %>%
  padronizar_chaves_secao() %>%
  distinct(
    ANO_ELEICAO, NR_TURNO, SG_UF, CD_MUNICIPIO,
    NM_MUNICIPIO, NR_ZONA, NR_SECAO,
    .keep_all = TRUE
  )

sections_votes_pres <- sections_votes_2022 %>%
  filter(
    DS_CARGO == "PRESIDENTE",
    NR_TURNO %in% c(1, 2)
  ) %>%
  select(
    ANO_ELEICAO, NR_TURNO, SG_UF, CD_MUNICIPIO, NM_MUNICIPIO,
    NR_ZONA, NR_SECAO,
    NR_VOTAVEL, NM_VOTAVEL, QT_VOTOS
  ) %>%
  padronizar_chaves_secao()

df_secao_candidato_2022 <- sections_votes_pres %>%
  left_join(
    sections_seats_pres,
    by = c(
      "ANO_ELEICAO",
      "NR_TURNO",
      "SG_UF",
      "CD_MUNICIPIO",
      "NM_MUNICIPIO",
      "NR_ZONA",
      "NR_SECAO"
    )
  ) %>%
  mutate(
    turnout = QT_COMPARECIMENTO / QT_APTOS,
    vote_share = QT_VOTOS / QT_VOTOS_NOMINAIS
  )

# ----------------------------------------------------------------------
# 5. Checagens agregadas por turno
# ----------------------------------------------------------------------

resumo_votos_t1 <- resumir_votos_turno(df_secao_candidato_2022, turno = 1)
resumo_votos_t2 <- resumir_votos_turno(df_secao_candidato_2022, turno = 2)

resumo_votos_t1
resumo_votos_t2

# ----------------------------------------------------------------------
# 6. Bases para fingerprint por seção
# ----------------------------------------------------------------------

base_fp_t1 <- preparar_base_fingerprint_secao(df_secao_candidato_2022, turno = 1)
base_fp_t2 <- preparar_base_fingerprint_secao(df_secao_candidato_2022, turno = 2)

# ----------------------------------------------------------------------
# 7. Seleção de candidatos
# ----------------------------------------------------------------------

candidatos <- list(
  lula = "LUIZ INÁCIO LULA DA SILVA",
  bolsonaro = "JAIR MESSIAS BOLSONARO")

lula_t1  <- filtrar_candidato(base_fp_t1, candidatos$lula)
bolso_t1 <- filtrar_candidato(base_fp_t1, candidatos$bolsonaro)


lula_t2  <- filtrar_candidato(base_fp_t2, candidatos$lula)
bolso_t2 <- filtrar_candidato(base_fp_t2, candidatos$bolsonaro)

# ----------------------------------------------------------------------
# 8. Gráficos por seção
# ----------------------------------------------------------------------

fp_lula_t1 <- fazer_fingerprint(
  base = lula_t1,
  titulo = "PT (first round)",
  label_y = "Vote share"
)

fp_lula_t1

fp_bolso_t1 <- fazer_fingerprint(
  base = bolso_t1,
  titulo = "PL (first round)",
  label_y = "Vote share"
)
fp_bolso_t1

fp_lula_t2 <- fazer_fingerprint(
  base = lula_t2,
  titulo = "PT (second round)",
  label_y = "Vote share"
)

fp_lula_t2

fp_bolso_t2 <- fazer_fingerprint(
  base = bolso_t2,
  titulo = "PL (second round)",
  label_y = "Vote share"
)

fp_bolso_t2

fig_fingerprint_secoes <- (fp_lula_t1 | fp_bolso_t1) /
  (fp_lula_t2 | fp_bolso_t2)

fig_fingerprint_secoes

### Correlations

extrair_cor <- function(x, y, nome, turno, candidato) {
  teste <- cor.test(x, y)
  
  tibble(
    base = nome,
    turno = turno,
    candidato = candidato,
    cor = unname(teste$estimate),
    p_value = teste$p.value,
    n = teste$parameter + 2
  )
}

resultados_cor <- bind_rows(
  
    extrair_cor(
    bolso_t1$turnout,
    bolso_t1$vote_share,
    "secao", "1º turno", "Bolsonaro"
  ),
  
  extrair_cor(
    bolso_t2$turnout,
    bolso_t2$vote_share,
    "secao", "2º turno", "Bolsonaro"
  ),
  
  extrair_cor(
    lula_t1$turnout,
    lula_t1$vote_share,
    "secao", "1º turno", "Lula"
  ),
  
  extrair_cor(
    lula_t2$turnout,
    lula_t2$vote_share,
    "secao", "2º turno", "Lula"
  )
)

resultados_cor

resultados_cor <- resultados_cor %>%
  mutate(
    label_en = case_when(
      candidato == "Lula" & turno == "1º turno" ~ "Lula (first round)",
      candidato == "Bolsonaro" & turno == "1º turno" ~ "Bolsonaro (first round)",
      candidato == "Lula" & turno == "2º turno" ~ "Lula (second round)",
      candidato == "Bolsonaro" & turno == "2º turno" ~ "Bolsonaro (second round)"
    ),
    label_en = factor(
      label_en,
      levels = c(
        "Bolsonaro (second round)",
        "Lula (second round)",
        "Bolsonaro (first round)",
        "Lula (first round)"
      )
    ),
    candidato = factor(candidato, levels = c("Lula", "Bolsonaro"))
  )

resultados_cor

ggplot(resultados_cor, aes(x = label_en, y = cor, color = candidato)) +
  
  annotate(
    "rect",
    xmin = -Inf, xmax = Inf,
    ymin = -0.2, ymax = 0.2,
    fill = "grey70",
    alpha = 0.3
  ) +
  
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
  
  geom_segment(
    aes(x = label_en, xend = label_en, y = 0, yend = cor),
    linewidth = 1
  ) +
  
  geom_point(size = 4) +
  
  scale_color_manual(
    values = c("Lula" = "red", "Bolsonaro" = "darkgreen"),
    breaks = c("Lula", "Bolsonaro")
  ) +
  
  coord_flip() +
  
  scale_y_continuous(limits = c(-1, 1)) +
  
  labs(
    title = "Correlation between Turnout and Vote Share",
    subtitle = "Shaded area indicates weak association (-0.2 to 0.2)",
    x = "",
    y = "Correlation coefficient (r)",
    color = "Candidate"
  ) +
  
  theme_minimal(base_size = 14)

