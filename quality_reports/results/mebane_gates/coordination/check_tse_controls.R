# Arithmetic only for observations documented in tse2022_control_sources.md.
options(scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[[1L]] else
  "quality_reports/results/mebane_gates/coordination/tse2022_control_arithmetic.csv"
reported <- data.frame(
  source = c("TSE_news_T2", "TRE_RN_national_T2"),
  electorate = c(156454011, 156454011),
  turnout = c(124252796, 124252796),
  abstention = c(32200558, 32201215),
  valid = c(118552353, 118552353),
  blank = c(1769678, 1769678),
  null = c(3930765, 3930765),
  leader = c(60345999, 60345999),
  runner_up = c(58206354, 58206354)
)
reported$electorate_identity_gap <- with(reported, electorate - turnout - abstention)
reported$turnout_identity_gap <- with(reported, turnout - valid - blank - null)
reported$valid_identity_gap <- with(reported, valid - leader - runner_up)
stopifnot(
  identical(reported$electorate_identity_gap, c(657, 0)),
  all(reported$turnout_identity_gap == 0),
  all(reported$valid_identity_gap == 0)
)
utils::write.csv(reported, output, row.names = FALSE, fileEncoding = "UTF-8")
print(reported[c("source", "electorate_identity_gap", "turnout_identity_gap", "valid_identity_gap")])
