source("R/experimental/mebane_ad/io.R")
ad_setup()
x <- array(seq_len(2000L*4L*2L),c(2000L,4L,2L),
           dimnames=list(NULL,NULL,c("a","b")))
d <- posterior::as_draws_array(x)
stopifnot(identical(dim(as.matrix(d[,,"a"])),c(8000L,1L)))
plain <- unclass(d)
stopifnot(identical(dim(as.matrix(plain[,,"a"])),c(2000L,4L)),
          identical(as.numeric(plain),as.numeric(x)),
          identical(dim(plain),dim(x)),
          identical(dimnames(plain),dimnames(d)),
          all(vapply(1:4,function(k)identical(as.numeric(plain[,k,]),
                                               as.numeric(x[,k,])),logical(1))))
cat("PASS: S3 dispatch failure reproduced; base array preserves values, dimensions, names and chain order.\n")
