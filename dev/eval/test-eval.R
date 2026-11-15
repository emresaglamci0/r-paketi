library(testthat)

test_that("education data shape", {
  d <- make_education_data()
  expect_equal(dim(d), c(500L, 15L))
  expect_identical(d, make_education_data())
  expect_setequal(levels(d$okul_turu), c("devlet", "ozel", "meslek"))
  expect_true(all(d$motivasyon >= 1 & d$motivasyon <= 5))
  expect_true(all(d$devamsizlik >= 0 & d$devamsizlik == round(d$devamsizlik)))
  expect_gt(mean(d$calisma_saati) - median(d$calisma_saati), 0)
  expect_false(anyNA(d))
})

test_that("effect estimators match base R identities", {
  d <- make_education_data(); e <- estimate_effects(d)
  tab <- table(d$okul_turu, d$ders_disi)
  expect_equal(e$w_chisq, sqrt(unname(chisq.test(tab, correct = FALSE)$statistic) / 500))
  expect_equal(e$r_cor, cor(d$calisma_saati, d$mat_son))
  expect_equal(e$r2_change, e$r2_reg - e$r2_cov)
})
test_that("boot_power is near alpha under the null and handles strata", {
  d <- make_education_data()
  d$mat_son <- d$mat_son - ave(d$mat_son, d$ozel_ders)      # exact zero group effect
  expect_lt(abs(estimate_effects(d)$d_ind), 1e-12)
  set.seed(1)
  p <- boot_power(d, "t_independent", n = 50, reps = 1000, strata = "ozel_ders")
  expect_lt(abs(p$power - .05), .025); expect_equal(p$n_na, 0)
})
