# R/00_setup.R -- carregamento de pacotes, paths, seeds, helpers
# Sourced por todos os scripts do pipeline electoralFraud.
# Autor: Manoel Galdino
# Data: 2026-04-10
# Referencia: quality_reports/plans/2026-04-10_reconstrucao-metodologica.md (Bloco 0)

suppressPackageStartupMessages({
  library(here)
  library(fs)
  library(glue)
  library(cli)
  library(data.table)
  library(arrow)
  library(readr)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(viridis)
  library(fixest)
  library(future.apply)
  library(progressr)
})

# ---- pacotes usados fora do setup.R (listados para renv rastrear) ----
# Nao carregar em runtime -- sao usados em contextos especificos:
#   rmarkdown, knitr: Bloco 8 (methods_section.Rmd via rmarkdown::render)
#   remotes:          Bloco 3 (remotes::install_github para eforensics)
#   tidyverse:        meta-pacote (componentes ja carregados individualmente)
if (FALSE) {
  library(rmarkdown)
  library(knitr)
  library(remotes)
  library(tidyverse)
}

# ---- opcoes globais ----
options(
  scipen = 999,
  readr.show_col_types = FALSE,
  dplyr.summarise.inform = FALSE,
  warn = 1
)
data.table::setDTthreads(0)  # usa todos os cores disponiveis

# ---- seed ----
set.seed(20260410)

# ---- paths ----
PATH_RAW_AUTHORS    <- here::here("replication_authors", "extracted",
                                  "fingerprint_brazil", "raw-data")
PATH_DATA_PROCESSED <- here::here("data", "processed")
PATH_OUTPUT_FIGURES <- here::here("output", "figures")
PATH_OUTPUT_TABLES  <- here::here("output", "tables")
PATH_RESULTS_LOGS   <- here::here("quality_reports", "results")

# ---- fail fast: todos os paths devem existir ----
.required_paths <- c(PATH_RAW_AUTHORS, PATH_DATA_PROCESSED,
                     PATH_OUTPUT_FIGURES, PATH_OUTPUT_TABLES,
                     PATH_RESULTS_LOGS)
for (.p in .required_paths) {
  if (!dir.exists(.p)) {
    cli::cli_abort("Path obrigatorio nao existe: {.p}")
  }
}
rm(.p, .required_paths)

# ---- helpers de logging ----
log_step <- function(msg, ...) {
  cli::cli_inform("{format(Sys.time(), '%H:%M:%S')}  {glue::glue(msg, ...)}")
}

log_section <- function(title) {
  cli::cli_h1(title)
}

# ---- mensagem de setup ----
log_step(
  "Setup carregado. R {R.version$major}.{R.version$minor}, ",
  "data.table threads: {data.table::getDTthreads()}, ",
  "seed: 20260410"
)
