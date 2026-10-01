#!/usr/bin/env Rscript
# Display reduction is confined to this plot; diagnostic metrics use all draws.
options(scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
base <- "quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/diagnostics"
out <- if (length(args)) args[1] else file.path(base, "analysis01")
stopifnot(startsWith(out, paste0(base, "/")))
pdf_path <- file.path(out, "focused_traces.pdf")
stopifnot(!file.exists(pdf_path))
focus <- readRDS(file.path(out, "focused_draws.rds"))
metrics <- read.csv(file.path(out, "all_target_rankings.csv"), stringsAsFactors = FALSE)
pal <- c("#145DA0", "#D07D00", "#347C4B", "#A6363A")
pages <- list(
  c("pi[1]", "pi[2]", "pi[3]", "tau.alpha", "nu.alpha", "iota.m.alpha",
    "iota.s.alpha", "M_total", "S_total"),
  c("chi.m.alpha", "chi.s.alpha", "tb", "nb", "imb", "isb", "cmb", "csb", "class_count[3]")
)
pdf(pdf_path, width = 12, height = 8, family = "Times", onefile = TRUE,
    title = "D.C. 2010: focused existing-chain traces")
for (run in names(focus)) {
  a <- focus[[run]]
  n <- dim(a)[1]
  visible <- unique(round(seq(1, n, length.out = min(1000L, n))))
  for (p in seq_along(pages)) {
    par(mfrow = c(3, 3), mar = c(2.6, 3.1, 2.9, 0.6), oma = c(2, 0.4, 3.1, 0.4),
        cex.axis = 0.75, cex.lab = 0.8, mgp = c(1.8, 0.5, 0), tcl = -0.2)
    for (name in pages[[p]]) {
      y <- a[, , name]
      ylim <- range(y)
      if (diff(ylim) == 0) ylim <- ylim + c(-0.05, 0.05)
      plot(c(1, n), ylim, type = "n", xlab = "Retained iteration", ylab = "",
           bty = "l", xaxs = "i", yaxs = "r")
      abline(v = (1:3) * n / 4, col = "grey85", lty = 3)
      for (k in 1:4) lines(visible, y[visible, k], col = adjustcolor(pal[k], 0.7), lwd = 0.55)
      m <- metrics[metrics$run == run & metrics$target == name, ]
      stopifnot(nrow(m) == 1L)
      title(main = name, line = 1.65, cex.main = 0.95)
      mtext(sprintf("Bulk %.1f | Tail %.1f | R-hat %.3f", m$ess_bulk, m$ess_tail, m$rhat),
            side = 3, line = 0.3, cex = 0.7)
    }
    mtext(paste(run, if (p == 1) "weights, alphas and joint transfers" else "extreme component and variances"),
          side = 3, outer = TRUE, line = 1.45, cex = 1.2, font = 2)
    mtext("Chain 1: blue    Chain 2: orange    Chain 3: green    Chain 4: red",
          side = 3, outer = TRUE, line = 0.1, cex = 0.9)
    mtext(sprintf("Display: %d equally spaced points per chain out of %d. Metrics use every retained draw (thin=1).",
                  length(visible), n), side = 1, outer = TRUE, line = 0.4, cex = 0.85)
  }
}
invisible(dev.off())
message("Wrote ", pdf_path)
