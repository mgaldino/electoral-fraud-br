function (x, ...) 
{
    q05_ess <- ess_quantile(x, 0.05)
    q95_ess <- ess_quantile(x, 0.95)
    min(q05_ess, q95_ess)
}
