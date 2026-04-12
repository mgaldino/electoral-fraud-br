# Verifica se o fit em 05_eforensics_qbl_brasilia_fit.rds esta num modo errado
# como o Stan agent alega.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({
  library(rjags)
  library(eforensics)
  library(coda)
})

# 1. Empirical sanity check from data
log_section("Empirical Brasilia T2")
secao <- setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))))

bsb_long <- secao[CD_MUNICIPIO == 97012L & NR_TURNO == 2L &
                    NR_VOTAVEL %in% c(13L, 22L)]
bsb <- bsb_long[, .(
  N             = first(QT_APTOS),
  comparecimento = first(QT_COMPARECIMENTO),
  w_lula         = sum(QT_VOTOS[NR_VOTAVEL == 13L]),
  w_bolso        = sum(QT_VOTOS[NR_VOTAVEL == 22L])
), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]

bsb[, w := w_lula]   # leader = Lula (mesma escolha do meu script)
bsb[, a := N - comparecimento]

cat(sprintf("N total secoes: %d\n", nrow(bsb)))
cat(sprintf("Sum N (aptos): %s\n", format(sum(bsb$N), big.mark=",")))
cat(sprintf("Sum a (abstencoes): %s\n", format(sum(bsb$a), big.mark=",")))
cat(sprintf("Sum comparecimento: %s\n", format(sum(bsb$comparecimento), big.mark=",")))
cat(sprintf("Sum w (Lula T2): %s\n", format(sum(bsb$w), big.mark=",")))
cat(sprintf("Sum w_bolso (Bolsonaro T2): %s\n", format(sum(bsb$w_bolso), big.mark=",")))

abstencao_rate <- sum(bsb$a) / sum(bsb$N)
turnout_rate <- 1 - abstencao_rate
lula_share_among_voters <- sum(bsb$w) / sum(bsb$comparecimento)
lula_share_nominais <- sum(bsb$w) / (sum(bsb$w) + sum(bsb$w_bolso))

cat(sprintf("\nAbstencao rate: %.4f\n", abstencao_rate))
cat(sprintf("Turnout rate: %.4f\n", turnout_rate))
cat(sprintf("logit(turnout): %.4f\n", log(turnout_rate / abstencao_rate)))
cat(sprintf("\nLula share entre voters (= comparecimento): %.4f\n", lula_share_among_voters))
cat(sprintf("logit(Lula share voters): %.4f\n",
            log(lula_share_among_voters / (1 - lula_share_among_voters))))
cat(sprintf("\nLula share entre nominais (Lula+Bolso): %.4f\n", lula_share_nominais))
cat(sprintf("logit(Lula share nominais): %.4f\n",
            log(lula_share_nominais / (1 - lula_share_nominais))))

# 2. Carregar .rds e inspecionar
log_section("Carregando 05_eforensics_qbl_brasilia_fit.rds")
fit <- readRDS(file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fit.rds"))
cat(sprintf("class(fit): %s\n", paste(class(fit), collapse="/")))
cat(sprintf("names(fit): %s\n", paste(names(fit), collapse=", ")))
cat(sprintf("length(fit): %d\n", length(fit)))

# Olhar a estrutura -- objetos eforensics costumam ter mcmc samples
for (nm in names(fit)) {
  obj <- fit[[nm]]
  cat(sprintf("\n[[%s]]: class %s, ", nm, paste(class(obj), collapse="/")))
  if (is.atomic(obj) || is.numeric(obj)) {
    cat(sprintf("length %d\n", length(obj)))
  } else if (is.list(obj)) {
    cat(sprintf("length %d, names: %s\n", length(obj),
                paste(head(names(obj), 10), collapse=", ")))
  } else {
    cat("\n")
  }
}

# 3. Procurar mcmc.list
log_section("Procurando samples MCMC")
find_mcmc <- function(x, path = "") {
  if (inherits(x, "mcmc.list") || inherits(x, "mcmc")) {
    cat(sprintf("Found mcmc at: %s\n", path))
    return(invisible(x))
  }
  if (is.list(x)) {
    for (nm in names(x)) {
      res <- find_mcmc(x[[nm]], paste0(path, "$", nm))
      if (!is.null(res)) return(res)
    }
  }
  NULL
}
mc <- find_mcmc(fit, "fit")

if (!is.null(mc)) {
  cat(sprintf("\nClass of mcmc: %s\n", paste(class(mc), collapse="/")))
  if (inherits(mc, "mcmc.list")) {
    cat(sprintf("N chains: %d\n", length(mc)))
    cat(sprintf("N iter per chain: %d\n", nrow(mc[[1]])))
    cat(sprintf("Parameter names monitored:\n"))
    print(varnames(mc))

    # tentar pegar tau.alpha, nu.alpha, beta.tau1, beta.nu1
    targets <- c("tau.alpha", "nu.alpha", "iota.m.alpha", "iota.s.alpha",
                 "chi.m.alpha", "chi.s.alpha",
                 "beta.tau1[1]", "beta.nu1[1]",
                 "beta.tau[1]", "beta.nu[1]",
                 "pi[1]", "pi[2]", "pi[3]")
    for (t in targets) {
      if (t %in% varnames(mc)) {
        vals <- sapply(mc, function(ch) mean(ch[, t]))
        cat(sprintf("%-20s per-chain means: %s\n", t,
                    paste(sprintf("%.4f", vals), collapse=", ")))
      }
    }

    # Gelman PSRF para parametros principais
    cat("\n--- Gelman psrf (rhat) ---\n")
    key_params <- intersect(c("tau.alpha", "nu.alpha", "iota.m.alpha",
                              "iota.s.alpha", "chi.m.alpha", "chi.s.alpha",
                              "beta.tau1[1]", "beta.nu1[1]",
                              "beta.tau[1]", "beta.nu[1]",
                              "pi[1]", "pi[2]", "pi[3]"),
                            varnames(mc))
    if (length(key_params) > 0) {
      tryCatch({
        g <- gelman.diag(mc[, key_params], multivariate = FALSE)
        print(g$psrf)
      }, error = function(e) cat("gelman.diag erro:", conditionMessage(e), "\n"))
    }
  }
}
