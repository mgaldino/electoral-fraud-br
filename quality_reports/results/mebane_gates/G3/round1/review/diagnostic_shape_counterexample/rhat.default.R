function (x, ...) 
{
    rhat_bulk <- .rhat(z_scale(.split_chains(x)))
    rhat_tail <- .rhat(z_scale(.split_chains(fold_draws(x))))
    max(rhat_bulk, rhat_tail)
}
