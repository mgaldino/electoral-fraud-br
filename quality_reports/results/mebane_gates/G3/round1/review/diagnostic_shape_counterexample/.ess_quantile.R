function (x, prob) 
{
    if (should_return_NA(x)) {
        return(NA_real_)
    }
    x <- as.matrix(x)
    if (prob == 1) {
        len <- length(x)
        prob <- (len - 0.5)/len
    }
    I <- x <= quantile(x, prob)
    .ess(.split_chains(I))
}
