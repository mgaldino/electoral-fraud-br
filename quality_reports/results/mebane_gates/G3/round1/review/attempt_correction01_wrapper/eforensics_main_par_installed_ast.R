# Installed AST: eforensics_main_par
{
    check_mcmc(mcmc)
    options(warn = -1)
    on.exit(options(warn = 0))
    ef_check_jags()
    data$mu.iota.m = 1
    data$mu.iota.s = 1
    data$mu.chi.m = 1
    data$mu.chi.s = 1
    func.call <- match.call(expand.dots = FALSE)
    mat = getRegMatrix(func.call, data, weights, formula_number = 1)
    w = mat$y
    Xw = mat$X
    weightw = mat$w
    mat = getRegMatrix(func.call, data, weights, formula_number = 2)
    a = mat$y
    Xa = mat$X
    weighta = mat$w
    mat = getRegMatrix(func.call, data, weights, formula_number = 3)
    X.iota.m = mat$X
    weighta = mat$w
    mat = getRegMatrix(func.call, data, weights, formula_number = 4)
    X.iota.s = mat$X
    weighta = mat$w
    mat = getRegMatrix(func.call, data, weights, formula_number = 5)
    X.chi.m = mat$X
    weighta = mat$w
    mat = getRegMatrix(func.call, data, weights, formula_number = 6)
    X.chi.s = mat$X
    weighta = mat$w
    dat = list(w = w, a = a, Xa = as.matrix(Xa), dxa = ncol(Xa), 
        Xw = as.matrix(Xw), dxw = ncol(Xw), X.iota.m = as.matrix(X.iota.m), 
        dx.iota.m = ncol(X.iota.m), X.iota.s = as.matrix(X.iota.s), 
        dx.iota.s = ncol(X.iota.s), X.chi.m = as.matrix(X.chi.m), 
        dx.chi.m = ncol(X.chi.m), X.chi.s = as.matrix(X.chi.s), 
        dx.chi.s = ncol(X.chi.s), n = length(w))
    if (!is.null(eligible.voters)) {
        data = data %>% dplyr::rename(eligible.voters = !!eligible.voters)
        dat$N = data$eligible.voters
    }
    else {
        if (stringr::str_detect(model, pattern = "bl")) {
            stop("\nThe parameter 'eligible.voters' must be provided for models based on binomial distributions\n\n")
        }
    }
    data = dat
    if (is.null(parameters)) 
        parameters = ef_get_parameters_to_monitor(model)
    if (parameters[1] == "all") 
        parameters = ef_get_parameters_to_monitor(model, all = TRUE)
    model.name = model
    model = get_model(model.name)
    msg <- paste0("\n", "Burn-in: ", mcmc$burn.in, "\n")
    cat(msg)
    msg <- paste0("\n", "Number of MCMC samples per chain: ", 
        mcmc$n.iter, "\n")
    cat(msg)
    msg <- paste0("\n", "MCMC in progress ....", "\n\n")
    cat(msg)
    if (parComp == TRUE) {
        rjMethod <- "parallel"
    }
    else {
        rjMethod <- "interruptible"
    }
    time.init = Sys.time()
    runjags::runjags.options(inits.warning = FALSE, rng.warning = FALSE)
    max.auto = max(0, ceiling(max.auto))
    if (autoConv == TRUE) {
        trial = 0
        presim = runjags::run.jags(model = model, monitor = mcmc.conv.parameters, 
            data = data, n.chains = mcmc$n.chains, burnin = mcmc$burn.in, 
            sample = mcmc$n.iter, adapt = mcmc$n.adapt, jags.refresh = 0.5, 
            method = rjMethod)
        diagnostic = ef_get_diagnostic(presim, mcmc.conv.diagnostic, 
            mcmc.conv.parameters, mcmcse.conv.precision, mcmcse.combine = mcmcse.combine)
        while (trial < max.auto & !diagnostic$converged) {
            ef_print_diagnostic(diagnostic)
            trial = trial + 1
            cat(paste("\nConvergence diagnostic requirement not met. Extending the chains (attempt ", 
                trial, " of ", max.auto, ") ... \n\n", sep = ""))
            presim = runjags::extend.jags(presim, burnin = mcmc$burn.in, 
                sample = mcmc$n.iter, adapt = mcmc$n.adapt, jags.refresh = 10, 
                method = rjMethod)
            diagnostic = ef_get_diagnostic(presim, mcmc.conv.diagnostic, 
                mcmc.conv.parameters, mcmcse.conv.precision, 
                mcmcse.combine = mcmcse.combine)
        }
        cat("\nBurnin Finished.\nCapturing the samples ...\n\n")
        if (model.name %in% c("qbl", "bl")) {
            amp <- c(parameters, "iota.m", "iota.s", "chi.m", 
                "chi.s")
        }
        else {
            amp <- parameters
        }
        samples = runjags::extend.jags(presim, add.monitor = c(amp), 
            burnin = 0, sample = mcmc$n.iter, adapt = mcmc$n.adapt, 
            thin = 1, method = rjMethod, jags.refresh = 10)
        ef_print_diagnostic(diagnostic)
        if (!diagnostic$converged) {
            cat("\n\n")
            cat(paste("NOTE:\nConvergence diagnostics indicate that the chain(s) didn't converge.\n", 
                sep = ""))
            cat(paste0("Use these estimated results with caution and think about re-running eforensics with more chains, samples, or a longer burnin.", 
                sep = ""))
            cat("\n")
        }
    }
    else {
        if (model.name %in% c("qbl", "bl")) {
            amp <- c(parameters, "iota.m", "iota.s", "chi.m", 
                "chi.s")
        }
        else {
            amp <- parameters
        }
        samples = runjags::run.jags(model = model, monitor = amp, 
            data = data, n.chains = mcmc$n.chains, burnin = mcmc$burn.in, 
            sample = mcmc$n.iter, adapt = mcmc$n.adapt, jags.refresh = 0.5, 
            method = rjMethod)
        cat("\n\n")
        cat(paste("NOTE: Convergence diagnostics were not computed'. Use results with caution.\n", 
            sep = ""))
        cat(paste0("Set 'autoConv=T' to compute diagnostic automatically. See help(eforensics).", 
            sep = ""))
        cat("\n")
    }
    dic.samples = NULL
    T.mcmc = Sys.time() - time.init
    if (!is.null(parameters) & "Z" %in% parameters & model.name != 
        "qbl" & model.name != "bl") {
        samples = get_Z(samples[[1]])
    }
    else {
        if (!is.null(parameters) & "Z" %in% parameters & model.name %in% 
            c("qbl", "bl")) {
            osamples <- samples
            samples = get_Z_qbl(samplez = samples[[1]])
            frauds = samples$frauds
            samples = samples$samples
        }
        else {
            samples = create_list(samples[[1]])
        }
    }
    class(samples) = "eforensics"
    attr(samples, "samples") = osamples
    attr(samples, "formula.w") = formula1
    attr(samples, "formula.a") = formula2
    attr(samples, "model") = model.name
    if (model.name %in% c("rn")) {
        attr(samples, "terms") = c("alpha", colnames(X.chi.m), 
            colnames(X.iota.m), colnames(Xw), colnames(Xa), "No Fraud", 
            "Incremental Fraud", "Extreme Fraud")
    }
    else {
        attr(samples, "terms") = c("No Fraud", "Incremental Fraud", 
            "Extreme Fraud", colnames(Xw), colnames(Xa), colnames(X.iota.m), 
            colnames(X.iota.s), colnames(X.chi.m), colnames(X.chi.s))
    }
    if (model.name %in% c("qbl", "bl")) {
        attr(samples, "frauds") = frauds
    }
    else {
        flist <- list()
        flist$Manufactured <- NULL
        flist$Stolen <- NULL
        attr(samples, "frauds") = flist
    }
    cat("\n\nEstimation Completed\n\n")
    return(samples)
}
