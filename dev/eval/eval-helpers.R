# Effect estimates and bootstrap power for the plansize evaluation.

estimate_effects <- function(d) {
  g <- d$ozel_ders == "evet"
  n1 <- sum(g); n0 <- sum(!g)
  sp <- sqrt(((n1 - 1) * var(d$mat_son[g]) + (n0 - 1) * var(d$mat_son[!g])) / (n1 + n0 - 2))
  d_ind <- (mean(d$mat_son[g]) - mean(d$mat_son[!g])) / sp
  dif <- d$mat_son - d$mat_on
  d_paired <- mean(dif) / sqrt((var(d$mat_on) + var(d$mat_son)) / 2)
  ss <- summary(aov(mat_son ~ okul_turu, data = d))[[1]][["Sum Sq"]]
  eta2 <- ss[1] / sum(ss)
  x2 <- unname(chisq.test(table(d$okul_turu, d$ders_disi), correct = FALSE)$statistic)
  f <- mat_son ~ calisma_saati + devamsizlik + motivasyon + oz_yeterlik + sinav_kaygisi
  r2_reg <- summary(lm(f, data = d))$r.squared
  r2_cov <- summary(lm(mat_son ~ calisma_saati + devamsizlik + sinav_kaygisi, data = d))$r.squared
  list(d_ind = d_ind, d_paired = d_paired, r_paired = cor(d$mat_on, d$mat_son),
       f_anova = sqrt(eta2 / (1 - eta2)),
       p1 = mean(d$gecti[g]), p2 = mean(d$gecti[!g]),
       r_cor = cor(d$calisma_saati, d$mat_son), w_chisq = sqrt(x2 / nrow(d)),
       r2_reg = r2_reg, r2_cov = r2_cov, r2_change = r2_reg - r2_cov,
       p_gecti = mean(d$gecti))
}

# One p-value per test. Group mapping fixed by the evaluation design.
.eval_p <- function(b, test) {
  switch(test,
    t_independent = t.test(mat_son ~ ozel_ders, data = b, var.equal = TRUE)$p.value,
    t_paired = t.test(b$mat_on, b$mat_son, paired = TRUE)$p.value,
    anova_oneway = oneway.test(mat_son ~ okul_turu, data = b, var.equal = TRUE)$p.value,
    prop_two = {
      tab <- table(factor(b$ozel_ders, c("evet", "hayir")), factor(b$gecti, c(1, 0)))
      prop.test(tab, correct = FALSE)$p.value
    },
    cor_pearson = cor.test(b$calisma_saati, b$mat_son)$p.value,
    chisq_indep = chisq.test(table(b$okul_turu, b$ders_disi), correct = FALSE)$p.value,
    reg_overall = {
      fs <- summary(lm(mat_son ~ calisma_saati + devamsizlik + motivasyon +
                         oz_yeterlik + sinav_kaygisi, data = b))$fstatistic
      unname(pf(fs[1], fs[2], fs[3], lower.tail = FALSE))
    },
    reg_partial = {
      big <- lm(mat_son ~ calisma_saati + devamsizlik + motivasyon +
                  oz_yeterlik + sinav_kaygisi, data = b)
      small <- lm(mat_son ~ calisma_saati + devamsizlik + sinav_kaygisi, data = b)
      anova(small, big)[2, "Pr(>F)"]
    },
    stop("unknown test: ", test))
}

# Caller sets the seed. n = rows per stratum level, or total rows if strata is NULL.
boot_power <- function(d, test, n, reps = 2000, strata = NULL) {
  idx <- if (is.null(strata)) NULL else split(seq_len(nrow(d)), d[[strata]])
  n_warn <- 0L
  p <- vapply(seq_len(reps), function(i) {
    rows <- if (is.null(idx)) sample.int(nrow(d), n, replace = TRUE)
            else unlist(lapply(idx, function(ix) ix[sample.int(length(ix), n, replace = TRUE)]),
                        use.names = FALSE)
    b <- d[rows, , drop = FALSE]
    tryCatch(withCallingHandlers(.eval_p(b, test),
                                 warning = function(w) {
                                   n_warn <<- n_warn + 1L
                                   invokeRestart("muffleWarning")
                                 }),
             error = function(e) NA_real_)
  }, numeric(1))
  ok <- !is.na(p)
  pw <- mean(p[ok] < .05)
  list(power = pw, mc_se = sqrt(pw * (1 - pw) / sum(ok)), n_na = sum(!ok), n_warn = n_warn)
}
