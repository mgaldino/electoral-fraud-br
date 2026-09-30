function (x) 
{
    x <- as.matrix(x)
    niter <- NROW(x)
    if (niter == 1L) {
        return(x)
    }
    half <- niter/2
    cbind(x[1:floor(half), ], x[ceiling(half + 1):niter, ])
}
