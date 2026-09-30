function (x, tol = .Machine$double.eps) 
{
    if (anyNA(x) || checkmate::anyInfinite(x)) {
        return(TRUE)
    }
    is_constant(x, tol = tol)
}
