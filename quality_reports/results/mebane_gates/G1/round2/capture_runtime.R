versions <- vapply(c("data.table", "arrow", "jsonlite", "digest"),
                   function(p) as.character(utils::packageVersion(p)), character(1))
jsonlite::write_json(list(R = R.version.string, platform = R.version$platform,
                         packages = as.list(versions)),
  "quality_reports/results/mebane_gates/G1/round2/checks/runtime.json",
  auto_unbox = TRUE, pretty = TRUE)
print(versions)
