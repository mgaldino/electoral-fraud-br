# Tests consume the frozen source tree and synthetic counts only.
ad_stan_test_suite <- function(model, out, sources, executor_id) {
  results <- list()
  calls <- list()
  density_evidence <- list()
  gradient_evidence <- list()
  check <- function(name, expr) {
    error <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
    results[[length(results) + 1L]] <<- list(name = name, pass = is.null(error), error = error)
    cat(if (is.null(error)) "PASS" else "FAIL", name,
        if (!is.null(error)) paste(":", error) else "", "\n")
    invisible(is.null(error))
  }
  near <- function(actual, expected, tol = 1e-10) {
    if (length(actual) != length(expected) || anyNA(actual) || anyNA(expected)) stop("Shape or NA mismatch")
    a <- as.numeric(actual)
    b <- as.numeric(expected)
    inf <- is.infinite(a) | is.infinite(b)
    if (any(inf) && !identical(a[inf], b[inf])) stop("Infinite values differ")
    delta <- abs(a[!inf] - b[!inf]) / (1 + abs(b[!inf]))
    if (length(delta) && max(delta) > tol) stop("Relative error ", format(max(delta), digits = 17), " > ", tol)
    invisible(TRUE)
  }
  rejects <- function(expr) {
    failed <- tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
    if (!failed) stop("Expected rejection did not occur")
  }
  trace <- function(api, arguments) {
    calls[[length(calls) + 1L]] <<- list(api = api, arguments = arguments)
    cat("CALL", api, jsonlite::toJSON(arguments, auto_unbox = TRUE, digits = NA), "\n")
  }
  on.exit({
    ad_stan_json(list(executor_id = executor_id, empirical_sampling = FALSE, calls = calls),
                 file.path(out, "calls.json"))
    ad_stan_json(list(executor_id = executor_id, checks = results,
                      passed = sum(vapply(results, `[[`, logical(1), "pass")),
                      failed = sum(!vapply(results, `[[`, logical(1), "pass"))),
                 file.path(out, "checks.json"))
    if (length(density_evidence)) write.csv(do.call(rbind, density_evidence),
                                           file.path(out, "density_comparisons.csv"), row.names = FALSE)
    if (length(gradient_evidence)) write.csv(do.call(rbind, gradient_evidence),
                                            file.path(out, "gradient_comparisons.csv"), row.names = FALSE)
  }, add = TRUE)

  original <- new.env(parent = globalenv())
  sys.source(file.path(sources, "R/experimental/mebane_ad/model_d.R"), envir = original)
  contract <- file.path(sources, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/contract.json")
  stan_path <- file.path(sources, "models/experimental/mebane_ad_stan/d_multinomial.stan")
  stan_text <- paste(readLines(stan_path, warn = FALSE), collapse = "\n")
  check("frozen_design_4_serial_2000_2000", {
    cfg <- ad_stan_settings(contract)
    stopifnot(cfg$parallel_chains == 1L, cfg$chains == 4L, cfg$thin == 1L)
  })
  check("static_prior_variance_and_separate_intercepts", {
    required <- c("alpha ~ std_normal();", "b0 ~ normal(0, 0.01);", "v ~ exponential(5);",
                  "to_vector(z) ~ std_normal();", "vector<lower=0, upper=1>[2] r;",
                  "sqrt(v) .* to_vector(z[i])", "target += log_sum_exp(terms);")
    stopifnot(all(vapply(required, grepl, logical(1), x = stan_text, fixed = TRUE)))
    stopifnot(!grepl("ordered\\[|dirichlet|binomial|0\\.999|fmin\\(|fmax\\(", stan_text))
  })
  check("prior_auxiliary_change_of_variables", {
    for (u1 in c(0.0001, 0.1, 0.8, 0.9999)) {
      for (r in list(c(0.02, 0.8), c(0.7, 0.2), c(0.5, 0.5))) {
        jac <- matrix(c(1, r[1], r[2], 0, u1, 0, 0, 0, u1), 3L)
        near((1 / u1^2) * abs(det(jac)), 1)
        near(c(u1, u1 * r) / sum(c(u1, u1 * r)), c(1, r) / (1 + sum(r)))
      }
    }
  })
  check("prior_simplex_jacobian_and_partial_not_total_order", {
    for (r in list(c(0.2, 0.8), c(0.8, 0.2), c(0.9, 0.9))) {
      den <- 1 + sum(r)
      jac <- matrix(c(1 + r[2], -r[2], -r[1], 1 + r[1]), 2) / den^2
      pi <- c(1, r) / den
      near(abs(det(jac)), pi[1]^3)
      stopifnot(pi[1] >= max(pi[-1]))
    }
    # Integrating u1 leaves density one over the unit square, not a Dirichlet.
    near(integrate(function(x) rep(1, length(x)), 0, 1)$value^3, 1)
  })

  trace("model$expose_functions", list(source_sha256 = ad_stan_sha(stan_path)))
  model$expose_functions()
  lp_fun <- model$functions$ad_log_probabilities
  mass_fun <- model$functions$ad_count_log_lpmf
  stopifnot(is.function(lp_fun), is.function(mass_fun))

  counts <- function(N) {
    grid <- expand.grid(A = 0:N, W = 0:N)
    grid <- grid[grid$A + grid$W <= N, , drop = FALSE]
    unname(cbind(grid, O = N - grid$A - grid$W))
  }
  eta_grid <- rbind(c(-1.2, 0.8, -0.4, 1.1, 0.3, -0.7), rep(0, 6),
                    c(8, -8, -6, 6, 4, -4), rep(100, 6), rep(-100, 6),
                    c(-800, 800, -800, 800, -800, 800),
                    c(800, -800, 800, -800, 800, -800))
  trace("compiled_functions_grid", list(eta = unname(eta_grid), classes = 1:3, N = 0:4,
                                        order = c("A", "W", "O")))
  for (k in seq_len(nrow(eta_grid))) {
    eta <- eta_grid[k, ]
    for (cls in 1:3) {
      check(sprintf("compiled_log_probabilities_eta%d_class%d", k, cls), {
        lp <- as.numeric(lp_fun(eta, cls))
        near(lp, ad_stan_reference_log_probs(eta, cls), 5e-13)
        near(sum(exp(lp)), 1, 5e-14)
        if (k <= 3L) {
          mag <- original$ad_d_magnitudes(eta[3], eta[4], eta[5], eta[6])
          near(exp(lp), original$ad_d_probabilities(plogis(eta[1]), plogis(eta[2]),
                                                    mag$m[cls], mag$s[cls]), 5e-13)
        }
      })
      for (N in 0:4) {
        check(sprintf("smallN_logmass_eta%d_class%d_N%d", k, cls, N), {
          grid <- counts(N)
          lp <- as.numeric(lp_fun(eta, cls))
          actual <- apply(grid, 1, function(y) mass_fun(as.integer(y), lp))
          expected <- apply(grid, 1, ad_stan_reference_mass, logp = lp)
          near(actual, expected, 2e-12)
          near(sum(exp(actual)), 1, 2e-12)
        })
      }
    }
  }
  for (lp in list(c(0, -Inf, -Inf), c(-Inf, 0, -Inf), c(-Inf, -Inf, 0),
                 log(c(0.2, 0, 0.8)))) {
    check(paste0("exact_probability_boundary_", paste(exp(lp), collapse = "_")), {
      for (N in 0:4) {
        grid <- counts(N)
        masses <- apply(grid, 1, function(y) mass_fun(as.integer(y), lp))
        near(masses, apply(grid, 1, ad_stan_reference_mass, logp = lp), 2e-12)
        near(sum(exp(masses)), 1, 2e-12)
      }
    })
  }
  check("invalid_class_rejected", rejects(lp_fun(rep(0, 6), 4L)))

  data <- list(n = 3L, N = c(3L, 4L, 2L), observed = rbind(c(1L, 2L, 0L),
                                                         c(0L, 1L, 3L), c(1L, 0L, 1L)))
  pars <- list(alpha = c(-0.3, 0.7, -0.8, 0.6, -1.1, 0.9),
               b0 = c(-0.006, 0.004, 0.001, -0.009, 0.003, 0.002),
               v = c(0.05, 0.2, 0.4, 0.1, 0.8, 0.3),
               z = matrix(seq(-0.9, 0.8, length.out = 18), 3, 6), r = c(0.17, 0.63))
  cmdstanr::write_stan_json(data, file.path(out, "synthetic_data.json"))
  cmdstanr::write_stan_json(pars, file.path(out, "fixed_parameters.json"))
  fixed_dir <- ad_stan_new_dir(file.path(out, "fixed_parameter"))
  trace("model$sample", list(data = data, init = pars, fixed_param = TRUE, seed = 1001267L,
                             chains = 1L, parallel_chains = 1L, iter_warmup = 0L,
                             iter_sampling = 256L, output_dir = fixed_dir, sig_figs = 17L))
  fit <- model$sample(data = file.path(out, "synthetic_data.json"),
                      init = file.path(out, "fixed_parameters.json"), fixed_param = TRUE, seed = 1001267,
                      chains = 1, parallel_chains = 1, iter_warmup = 0, iter_sampling = 256,
                      output_dir = fixed_dir, output_basename = "conditioned_synthetic",
                      sig_figs = 17, refresh = 0, diagnostics = NULL, save_cmdstan_config = TRUE)
  writeLines(unlist(fit$output(), use.names = FALSE), file.path(out, "fixed_parameter.log"))
  stopifnot(all(fit$return_codes() == 0))
  saveRDS(fit, file.path(out, "synthetic_fit_handle.rds"))
  trace("fit$init_model_methods", list(data = "synthetic_data.json"))
  fit$init_model_methods()
  trace("fit$unconstrain_variables", pars)
  u <- fit$unconstrain_variables(pars)
  check("unconstrained_parameter_order", near(u, ad_stan_pack(pars), 1e-13))
  check("compiled_constrain_roundtrip", {
    restored <- fit$constrain_variables(u, transformed_parameters = FALSE, generated_quantities = FALSE)
    for (p in names(pars)) near(restored[[p]], pars[[p]], 1e-12)
  })

  variants <- list(asymmetric = pars, reverse_r = within(pars, r <- rev(r)),
                   small_variance = within(pars, v <- rep(1e-8, 6)),
                   rare_classes = within(pars, r <- c(1e-10, 1 - 1e-10)),
                   large_predictors = within(pars, alpha <- c(-80, 80, -80, 80, -80, 80)))
  for (name in names(variants)) {
    p <- variants[[name]]
    unconstrained <- ad_stan_pack(p)
    trace("fit$log_prob", list(case = name, unconstrained_variables = unconstrained,
                                jacobian = c(FALSE, TRUE)))
    check(paste0("compiled_lp_no_jacobian_", name), {
      actual <- fit$log_prob(unconstrained, jacobian = FALSE)
      expected <- ad_stan_reference_lp(p, data, jacobian = FALSE)
      density_evidence[[length(density_evidence) + 1L]] <- data.frame(
        case = name, jacobian = FALSE, actual = actual, expected = expected, error = actual - expected)
      near(actual, expected, 2e-10)
    })
    check(paste0("compiled_lp_with_constraint_jacobian_", name), {
      actual <- fit$log_prob(unconstrained, jacobian = TRUE)
      expected <- ad_stan_reference_u_lp(unconstrained, data, jacobian = TRUE)
      density_evidence[[length(density_evidence) + 1L]] <- data.frame(
        case = name, jacobian = TRUE, actual = actual, expected = expected, error = actual - expected)
      near(actual, expected, 2e-10)
    })
    check(paste0("NCP_centered_density_change_of_variables_", name), {
      near(ad_stan_centered_lp(p, data) + data$n / 2 * sum(log(p$v)),
           ad_stan_reference_lp(p, data, normalized = TRUE), 2e-10)
    })
    for (jac in c(FALSE, TRUE)) {
      trace("fit$grad_log_prob", list(case = name, jacobian = jac,
                                     finite_difference_step = "1e-5 * max(1,abs(u[j]))"))
      check(sprintf("finite_gradients_R_finite_difference_%s_jac%s", name, jac), {
        grad <- fit$grad_log_prob(unconstrained, jacobian = jac)
        stopifnot(all(is.finite(grad)), length(grad) == length(unconstrained))
        numeric_grad <- vapply(seq_along(unconstrained), function(j) {
          delta <- 1e-5 * max(1, abs(unconstrained[j]))
          high <- low <- unconstrained
          high[j] <- high[j] + delta
          low[j] <- low[j] - delta
          (ad_stan_reference_u_lp(high, data, jacobian = jac) -
             ad_stan_reference_u_lp(low, data, jacobian = jac)) / (2 * delta)
        }, numeric(1))
        gradient_evidence[[length(gradient_evidence) + 1L]] <- data.frame(
          case = name, jacobian = jac, coordinate = seq_along(grad),
          compiled = as.numeric(grad), finite_difference_R = numeric_grad,
          scaled_error = abs(as.numeric(grad) - numeric_grad) / (1 + abs(numeric_grad)))
        near(as.numeric(grad), numeric_grad, 3e-5)
      })
    }
  }

  check("class_mixture_is_not_multinomial_at_mean_probability", {
    i <- 1L
    eta <- pars$alpha + pars$b0 + sqrt(pars$v) * pars$z[i, ]
    class_p <- t(vapply(1:3, function(k) exp(ad_stan_reference_log_probs(eta, k)), numeric(3)))
    pi <- c(1, pars$r) / (1 + sum(pars$r))
    correct <- log(sum(pi * apply(class_p, 1, function(p) dmultinom(data$observed[i, ], prob = p))))
    wrong <- dmultinom(data$observed[i, ], prob = as.numeric(pi %*% class_p), log = TRUE)
    stopifnot(abs(correct - wrong) > 1e-3)
    near(correct, ad_stan_reference_likelihood(pars,
         list(n = 1L, N = data$N[i], observed = data$observed[i, , drop = FALSE])), 1e-12)
  })

  draws <- fit$draws(format = "draws_matrix")
  trace("fit$draws", list(format = "draws_matrix", retained = nrow(draws), warmup = 0))
  get <- function(name, i = NULL, j = NULL) {
    suffix <- if (is.null(i)) "" else if (is.null(j)) paste0("[", i, "]") else paste0("[", i, ",", j, "]")
    as.numeric(draws[, paste0(name, suffix)])
  }
  check("fixed_parameters_not_updated", {
    for (j in 1:6) {
      near(get("alpha", j), rep(pars$alpha[j], nrow(draws)))
      near(get("b0", j), rep(pars$b0[j], nrow(draws)))
      near(get("v", j), rep(pars$v[j], nrow(draws)))
    }
  })
  for (i in 1:data$n) {
    eta <- pars$alpha + pars$b0 + sqrt(pars$v) * pars$z[i, ]
    cp <- t(vapply(1:3, function(k) exp(ad_stan_reference_log_probs(eta, k)), numeric(3)))
    pi <- c(1, pars$r) / (1 + sum(pars$r))
    terms <- log(pi) + apply(cp, 1, function(p) dmultinom(data$observed[i, ], prob = p, log = TRUE))
    responsibility <- exp(terms - ad_stan_lse(terms))
    mag <- original$ad_d_magnitudes(eta[3], eta[4], eta[5], eta[6])
    M <- data$N[i] * plogis(-eta[1]) * mag$m
    S <- data$N[i] * plogis(eta[1]) * plogis(-eta[2]) * mag$s
    check(paste0("GQ_responsibilities_and_log_lik_row", i), {
      for (cls in 1:3) near(get("responsibility", i, cls), rep(responsibility[cls], nrow(draws)))
      near(get("log_lik", i), rep(ad_stan_lse(terms), nrow(draws)))
    })
    check(paste0("GQ_mu_mapping_row", i), {
      mu <- c(plogis(eta[1:2]), mag$m[2], mag$s[2], mag$m[3], mag$s[3])
      for (j in 1:6) near(get("mu", i, j), rep(mu[j], nrow(draws)))
    })
    check(paste0("GQ_same_Z_active_and_RB_row", i), {
      Z <- get("Z", i)
      near(Z, get("Z_rng", i))
      stopifnot(all(Z %in% 1:3))
      for (j in 1:3) {
        near(get(c("pA", "pW", "pO")[j], i), cp[Z, j])
        near(get("p_RB", i, j), rep(sum(responsibility * cp[, j]), nrow(draws)))
        near(get("M_by_class", i, j), rep(M[j], nrow(draws)))
        near(get("S_by_class", i, j), rep(S[j], nrow(draws)))
      }
      near(get("M_active", i), M[Z])
      near(get("S_active", i), S[Z])
      near(get("M_RB", i), rep(sum(responsibility * M), nrow(draws)))
      near(get("S_RB", i), rep(sum(responsibility * S), nrow(draws)))
    })
  }
  check("GQ_joint_draw_totals", {
    for (name in c("M", "S")) {
      near(get(paste0(name, "_total")), rowSums(sapply(1:data$n, function(i) get(paste0(name, "_active"), i))))
      near(get(paste0(name, "_RB_total")), rowSums(sapply(1:data$n, function(i) get(paste0(name, "_RB"), i))))
    }
  })
  check("generated_Z_has_nonconstant_synthetic_reconstruction", {
    stopifnot(any(vapply(1:data$n, function(i) length(unique(get("Z", i))) > 1L, logical(1))))
  })
  check("lazy_fit_RDS_CSV_roundtrip", {
    reloaded <- readRDS(file.path(out, "synthetic_fit_handle.rds"))
    near(reloaded$draws(format = "draws_matrix"), draws, 1e-13)
  })
  check("name_map_has_required_complete_unambiguous_names", {
    map <- ad_stan_name_map(data$n)
    stopifnot(!anyDuplicated(map$stan), !anyDuplicated(map$jags), all(map$stan %in% colnames(draws)),
              nrow(map) == 21 + 10 * data$n)
  })
  check("serial_initialization_matches_LONG", {
    initial <- ad_stan_inits(data)
    for (i in 1:4) {
      stopifnot(all(initial[[i]]$z == 0), all(initial[[i]]$b0 == 0))
      near(initial[[i]]$v, rep(c(0.1, 0.2, 0.3, 0.4)[i], 6))
      near(initial[[i]]$r, c(0.25, 0.125))
    }
  })
  qa_dir <- ad_stan_new_dir(file.path(out, "qa_rejection_fixtures"))
  fixture_manifest <- file.path(qa_dir, "synthetic_manifest.json")
  ad_stan_json(list(fixture = TRUE, not_a_preparation = TRUE), fixture_manifest)
  for (kind in c("pending", "self_review", "wrong_hash")) {
    qa_path <- file.path(qa_dir, paste0(kind, ".json"))
    ad_stan_json(list(status = if (kind == "pending") "PENDING" else "PASS",
                      reviewer_id = if (kind == "self_review") executor_id else "synthetic-test-only",
                      preparation_manifest_sha256 = if (kind == "wrong_hash") "wrong" else ad_stan_sha(fixture_manifest)), qa_path)
    check(paste0("QA_rejects_", kind), rejects(ad_stan_require_qa(qa_path, fixture_manifest, executor_id)))
  }
  check("existing_output_refused", rejects(ad_stan_new_dir(qa_dir)))
  check("all_frozen_sources_unchanged", {
    frozen_manifest <- jsonlite::read_json(file.path(sources, "sources_manifest.json"))
    for (record in frozen_manifest$files) stopifnot(ad_stan_sha(file.path(sources, record$path)) == record$sha256)
  })
  invisible(list(passed = sum(vapply(results, `[[`, logical(1), "pass")),
                 failed = sum(!vapply(results, `[[`, logical(1), "pass"))))
}
