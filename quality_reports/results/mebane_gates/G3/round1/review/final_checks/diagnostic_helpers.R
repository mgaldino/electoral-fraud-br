qa_batch_mcse <- function(x, batch_size = 50L) {
  x <- as.matrix(x)
  stopifnot(nrow(x) %% batch_size == 0L, all(is.finite(x)))
  batches <- nrow(x) %/% batch_size
  stopifnot(batches >= 2L)
  means <- vapply(seq_len(ncol(x)), function(j) {
    colMeans(matrix(x[,j], nrow = batch_size, ncol = batches))
  }, numeric(batches))
  list(mcse = sqrt(sum(apply(means, 2, var) / batches)) / ncol(x),
       batch_means = means, batches = batches, chains = ncol(x))
}

qa_targets <- function(draw) {
  draw <- as.matrix(draw)
  colnames(draw) <- sub("\\[1\\]$", "", colnames(draw))
  stopifnot(!anyDuplicated(colnames(draw)))
  names_counts <- c("N.iota.m", "N.iota.s", "N.chi.m", "N.chi.s")
  stopifnot(all(c("Z", names_counts) %in% colnames(draw)))
  stopifnot(all(draw[,"Z"] %in% 1:3), all(draw[,names_counts] %in% 0:1))
  Z <- draw[,"Z"]
  m <- ifelse(Z == 1, 0, ifelse(Z == 2, .999*draw[,"N.iota.m"], .999*draw[,"N.chi.m"]))
  s <- ifelse(Z == 1, 0, ifelse(Z == 2, draw[,"N.iota.s"], draw[,"N.chi.s"]))
  M <- .5*m
  S <- .25*s
  cbind(draw[,c("Z",names_counts),drop=FALSE],
        indicator_Z1=as.numeric(Z==1),indicator_Z2=as.numeric(Z==2),indicator_Z3=as.numeric(Z==3),
        M=M,S=S,margin_lower=1-M-2*S,margin_upper=1-M-S)
}

qa_exact_targets <- function(exact) {
  counts <- as.matrix(exact[,c("Z","rm","rs","cm","cs")])
  colnames(counts) <- c("Z","N.iota.m","N.iota.s","N.chi.m","N.chi.s")
  qa_targets(counts)
}

qa_exact_distribution <- function(value, probability) {
  keep <- probability > 0
  value <- value[keep]; probability <- probability[keep]
  support <- sort(unique(value))
  mass <- vapply(support,function(v)sum(probability[value==v]),numeric(1))
  stopifnot(abs(sum(mass)-1) <= 1e-12)
  quantile_exact <- function(p) support[which(cumsum(mass)>=p)[1]]
  qs <- vapply(c(.05,.95),quantile_exact,numeric(1))
  indicator_mass <- vapply(qs,function(q)sum(mass[support<=q]),numeric(1))
  list(mean=sum(support*mass),variance=sum((support-sum(support*mass))^2*mass),
       support=support,mass=mass,constant=length(support)==1L,
       q05=qs[1],q95=qs[2],
       q05_indicator_constant=indicator_mass[1] %in% c(0,1),
       q95_indicator_constant=indicator_mass[2] %in% c(0,1))
}
