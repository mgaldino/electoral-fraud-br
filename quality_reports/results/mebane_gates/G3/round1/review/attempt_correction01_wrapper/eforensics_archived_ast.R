# Archived AST: eforensics
{
    check_mcmc(mcmc)
    check_nchains_for_psrf(mcmc, mcmc.conv.diagnostic)
    ef_parameters_to_check_convergence(mcmc.conv.parameters)
    options(warn = -1)
    on.exit(options(warn = 0))
    ef_check_jags()
    formulas = order.formulas(formula3, formula4, formula5, formula6)
    formula3 = formulas[[1]] %>% stats::as.formula(.)
    formula4 = formulas[[2]] %>% stats::as.formula(.)
    formula5 = formulas[[3]] %>% stats::as.formula(.)
    formula6 = formulas[[4]] %>% stats::as.formula(.)
    if (is.null(weights)) {
        data = data %>% dplyr::mutate(weights = 1)
    }
    eforensics_main_par(formula1, formula2, formula3, formula4, 
        formula5, formula6, data, eligible.voters, weights, mcmc, 
        model, parameters, na.action, get.dic, autoConv, max.auto, 
        mcmc.conv.diagnostic = mcmc.conv.diagnostic, mcmc.conv.parameters = mcmc.conv.parameters, 
        mcmcse.conv.precision = mcmcse.conv.precision, mcmcse.combine = mcmcse.combine, 
        parComp = parComp)
}
