source("R/experimental/mebane_ad/io.R")
ad_setup()
dir.create("tests/mebane/ad_long",recursive=TRUE,showWarnings=FALSE)
for (name in c("test_runner.R","test_timing.R")) {
  src <- file.path("tests/mebane/ad_study",name)
  dst <- file.path("tests/mebane/ad_long",name)
  stopifnot(!file.exists(dst))
  code <- readLines(src,warn=FALSE)
  for (r in list(c("R/experimental/mebane_ad/run_jags.R","R/experimental/mebane_ad_long/run_jags.R"),
                 c("R/experimental/mebane_ad/diagnostics.R","R/experimental/mebane_ad_long/diagnostics.R"),
                 c(src,dst),c("2000","20000"),c("8000","80000")))
    code <- gsub(r[1],r[2],code,fixed=TRUE)
  writeLines(code,dst,useBytes=TRUE)
  invisible(parse(dst))
}
