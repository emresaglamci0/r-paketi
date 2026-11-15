# Slice 11b probe: DMAR random-X power vs simulation; fixed-X sim; chi-square table pattern.
suppressWarnings(suppressMessages(library(DMAR)))
dm <- function(r2, k, n) { r <- DMAR::ss_power_R2(population_R2 = r2, p = k, specified_N = n, random_predictors = TRUE)
  r$value[grepl("power", r$term, ignore.case = TRUE)] }
pw <- function(r2, k, n) pwrss::power.f.reg(r.squared.change = r2, k.total = k, n = n, verbose = 0)$power
simr <- function(r2, k, n, reps = 10000) {          # random normal X, equal betas
  b <- rep(sqrt(r2 / (1 - r2) / k), k)
  mean(replicate(reps, { X <- matrix(rnorm(n * k), n); y <- X %*% b + rnorm(n)
    f <- summary(lm(y ~ X))$fstatistic; pf(f[1], f[2], f[3], lower.tail = FALSE) < .05 }))
}
simf <- function(r2, k, n, reps = 10000) {          # fixed orthogonal X, sum(x^2) = n
  X <- qr.Q(qr(scale(matrix(rnorm(n * k), n), scale = FALSE))) * sqrt(n)
  b <- rep(sqrt(r2 / (1 - r2) / k), k); mu <- X %*% b
  mean(replicate(reps, { y <- mu + rnorm(n)
    f <- summary(lm(y ~ X))$fstatistic; pf(f[1], f[2], f[3], lower.tail = FALSE) < .05 }))
}
set.seed(1)
for (cs in list(c(.13, 3, 77), c(.30, 3, 30), c(.05, 10, 318))) {
  cat(sprintf("R2 %.2f k %d n %d: pwrss %.4f  DMAR %s  simR %.4f  simF %.4f\n", cs[1], cs[2], cs[3],
    pw(cs[1], cs[2], cs[3]), paste(format(dm(cs[1], cs[2], cs[3]), digits = 4), collapse = "/"),
    simr(cs[1], cs[2], cs[3]), simf(cs[1], cs[2], cs[3])))
}
make_table <- function(rows, cols, w) {
  a <- seq_len(rows) - (rows + 1) / 2; b <- seq_len(cols) - (cols + 1) / 2
  M <- outer(a, b); M <- M / sqrt(sum(M^2)); 1 / (rows * cols) + w / sqrt(rows * cols) * M
}
wmax <- function(r, c) { a <- seq_len(r) - (r + 1) / 2; b <- seq_len(c) - (c + 1) / 2; M <- outer(a, b); M <- M / sqrt(sum(M^2)); 1 / (sqrt(r * c) * max(abs(M))) }
cat("wmax:", sapply(list(c(2,2), c(2,3), c(3,3), c(3,4), c(5,5)), function(d) round(wmax(d[1], d[2]), 4)), "\n")
P <- make_table(3, 3, .3); E <- outer(rowSums(P), colSums(P)); cat("w check:", sqrt(sum((P - E)^2 / E)), "\n")
simc <- function(r, c, w, n, reps = 10000) { P <- make_table(r, c, w)
  mean(replicate(reps, { x <- matrix(rmultinom(1, n, P), r)
    p <- suppressWarnings(chisq.test(x, correct = FALSE)$p.value); isTRUE(p < .05) })) }
for (cs in list(c(3,3,.3,133), c(2,2,.3,88), c(2,5,.1,1194))) cat(sprintf("chisq %dx%d w %.2f n %d: sim %.4f pwrss %.4f\n",
  cs[1], cs[2], cs[3], cs[4], simc(cs[1], cs[2], cs[3], cs[4]),
  pwrss::power.chisq.gof(w = cs[3], df = (cs[1]-1)*(cs[2]-1), n = cs[4], verbose = 0)$power))
