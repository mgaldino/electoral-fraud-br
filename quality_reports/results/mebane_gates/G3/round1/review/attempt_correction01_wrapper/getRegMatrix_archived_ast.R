# Archived AST: getRegMatrix
{
    args <- names(func.call)
    f = paste0("formula", formula_number, sep = "")
    idx.args <- match(c(f, "data", "weights"), args, 0L)
    func.call <- func.call[c(1L, idx.args)]
    names(func.call)[names(func.call) == f] = "formula"
    func.call$drop.unused.levels <- TRUE
    func.call[[1L]] <- quote(stats::model.frame)
    func.call[[3]] = quote(data)
    reg.matrix <- eval(func.call, parent.frame())
    y <- stats::model.response(reg.matrix, "numeric")
    w <- as.vector(stats::model.weights(reg.matrix))
    if (!is.null(w) && !is.numeric(w)) 
        stop("'weights' must be a numeric vector")
    offset <- as.vector(stats::model.offset(func.call))
    if (!is.null(offset)) {
        if (length(offset) != NROW(y)) 
            stop(gettextf("number of offsets is %d, should equal %d (number of observations)", 
                length(offset), NROW(y)), domain = NA)
    }
    mt1 <- attr(reg.matrix, "terms")
    if (stats::is.empty.model(mt1)) {
        x <- matrix(1, ncol = 1, nrow = nrow(y))
        results <- list(coefficients = if (is.matrix(y)) matrix(, 
            0, 3) else numeric(), residuals = y, fitted.values = 0 * 
            y, weights = w, rank = 0L, df.residual = if (!is.null(w)) sum(w != 
            0) else if (is.matrix(y)) nrow(y) else length(y))
        if (!is.null(offset)) {
            results$fitted.values <- offset
            results$residuals <- y - offset
        }
    }
    else {
        x <- stats::model.matrix(mt1, reg.matrix, contrasts)
    }
    return(list(y = y, X = x, w = w))
}
