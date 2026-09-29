# Arithmetic only for observations documented in tse2022_control_sources.md.
options(scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[[1L]] else
  "quality_reports/results/mebane_gates/coordination/tse2022_control_arithmetic.csv"
reported <- data.frame(
  source = c("TSE_news_T2", "TRE_RN_national_T2", "TSE_news_T1"),
  turn = c(2L, 2L, 1L),
  electorate = c(156454011, 156454011, 156454011),
  turnout = c(124252796, 124252796, 123682372),
  abstention = c(32200558, 32201215, 32770982),
  valid = c(118552353, 118552353, 118229719),
  blank = c(1769678, 1769678, 1964779),
  null = c(3930765, 3930765, 3487874),
  leader = c(60345999, 60345999, 57259504),
  runner_up = c(58206354, 58206354, 51072345)
)
reported$electorate_identity_gap <- with(reported, electorate - turnout - abstention)
reported$turnout_identity_gap <- with(reported, turnout - valid - blank - null)
reported$other_nominal_residual <- with(reported, valid - leader - runner_up)
stopifnot(
  identical(reported$electorate_identity_gap, c(657, 0, 657)),
  all(reported$turnout_identity_gap == 0),
  all(reported$other_nominal_residual[reported$turn == 2L] == 0),
  all(reported$other_nominal_residual[reported$turn == 1L] > 0)
)
utils::write.csv(reported, output, row.names = FALSE, fileEncoding = "UTF-8")
print(reported[c("source", "electorate_identity_gap", "turnout_identity_gap", "other_nominal_residual")])
