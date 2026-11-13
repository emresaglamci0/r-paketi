fz <- function(r, alpha = 0.05, power = 0.8, alt = "two.sided") {
  za <- if (alt == "two.sided") stats::qnorm(1 - alpha / 2) else stats::qnorm(1 - alpha)
  ((za + stats::qnorm(power)) / atanh(abs(r)))^2 + 3
}
test_that("correlation n matches the Fisher z formula and pwr", {
  for (r in c(0.1, 0.3, 0.5, 0.8, -0.3)) for (alt in c("two.sided", "one.sided")) {
    n <- engine_n_cor(r, 0.05, 0.8, alt)
    expect_lte(abs(n - fz(r, alt = alt)), 1)
    pa <- if (alt == "two.sided") "two.sided" else "greater"
    # pwr::pwr.r.test adds a bias correction r / (2 * (n - 1)), a different method, so it runs slightly lower.
    n_pwr <- pwr::pwr.r.test(r = abs(r), power = 0.8, alternative = pa)$n
    expect_lt(n_pwr, n)
    expect_lte(n - n_pwr, 2)
  }
})
test_that("cor_pearson plan", {
  p <- quiet_plan(test = "cor_pearson", effect = 0.3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(85L, 85L, 1L))
  expect_identical(quiet_plan(test = "cor_pearson", effect = -0.3)$n_per_group, 85L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = 0.3, dropout = 0.1)$n_per_group, 95L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = 0.3, alternative = "one.sided")$n_per_group, 68L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = -0.3, alternative = "one.sided")$n_per_group, 68L)
})
test_that("cor_pearson arguments are validated", {
  for (bad in list(0, 1, -1, 1.5, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "cor_pearson", effect = bad), "'effect'", fixed = TRUE)
  }
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, r = 0.3), "'effect'", fixed = TRUE)
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, k = 3), "'k'", fixed = TRUE)
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, p1 = 0.3), "'p1'", fixed = TRUE)
  expect_error(plan_study(test = "t_paired", effect = 0.5), "'r'", fixed = TRUE)
})
test_that("cor_pearson sensitivity keeps the sign", {
  skip_if_not_installed("pwr")
  ref <- pwr::pwr.r.test(n = 85, power = 0.8)$r
  expect_lte(abs(sensitivity(quiet_plan(test = "cor_pearson", effect = 0.3), n = 85, power = 0.8)$mde - ref), 0.005)
  expect_lt(sensitivity(quiet_plan(test = "cor_pearson", effect = -0.3), n = 85, power = 0.8)$mde, 0)
  expect_error(sensitivity(quiet_plan(test = "cor_pearson", effect = 0.3), n = 3), "n = 3", fixed = TRUE)
})
test_that("cor_pearson methods and print", {
  p <- quiet_plan(test = "cor_pearson", effect = -0.3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "for the planned analysis, a test of a Pearson correlation coefficient (Fisher z).", fixed = TRUE)
  expect_match(x, "The correlation used for planning was r = -.30 (Yilmaz, 2021).", fixed = TRUE)
  expect_match(x, "the required sample size was 85 participants.", fixed = TRUE)
  expect_false(grepl("))", x, fixed = TRUE)); expect_false(grepl(") (", x, fixed = TRUE))
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "Fisher z d\u00f6n\u00fc\u015f\u00fcm\u00fcne dayal\u0131 H0", fixed = TRUE)
  expect_match(t, "korelasyon r = -.30 olarak al\u0131nm\u0131\u015ft\u0131r (Yilmaz, 2021).", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Expected correlation (r): -0.3", out, fixed = TRUE)))
  expect_false(any(grepl("Total", out, fixed = TRUE)))
})
test_that("tampered cor_pearson plans are refused", {
  p <- quiet_plan(test = "cor_pearson", effect = 0.3)
  for (bad in list(list(effect_test = 1), list(effect_test = NULL), list(groups = 2L))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
test_that("r without effect is refused as unused", {
  expect_error(plan_study(test = "cor_pearson", r = 0.3), "not used", fixed = TRUE)
  expect_error(plan_study(test = "cor_pearson", r = 0.3), "'effect'", fixed = TRUE)
})
test_that("one-sided cor_pearson text states the direction", {
  rho <- "\u03c1"
  m <- function(eff, alt, lg) {
    unclass(write_methods(quiet_plan(test = "cor_pearson", effect = eff, alternative = alt), lang = lg))
  }
  expect_match(m(-0.3, "one.sided", "en"), paste0("against H1: ", rho, " < 0"), fixed = TRUE)
  expect_match(m(-0.3, "one.sided", "tr"), paste0("H1: ", rho, " < 0 y\u00f6n\u00fcndeki"), fixed = TRUE)
  expect_match(m(0.3, "one.sided", "en"), paste0(rho, " > 0"), fixed = TRUE)
  expect_match(m(0.3, "one.sided", "tr"), paste0("H1: ", rho, " > 0"), fixed = TRUE)
  for (lg in c("en", "tr")) {
    x <- m(0.3, "two.sided", lg)
    expect_false(grepl("H1:", x, fixed = TRUE)); expect_false(grepl("against", x, fixed = TRUE))
  }
  out <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(quiet_plan(test = "cor_pearson", effect = -0.3, alternative = "one.sided"))))
  expect_true(any(grepl(paste0("Alternative hypothesis: one-sided (", rho, " < 0)"), out, fixed = TRUE)))
  out2 <- withr::with_options(list(plansize.lang = "en"), capture.output(print(quiet_plan(test = "cor_pearson", effect = 0.3))))
  expect_true(any(grepl("Alternative hypothesis: two-sided$", trimws(out2))))
})
test_that("cor_pearson plan with planted k, r or effect_type is refused", {
  p <- quiet_plan(test = "cor_pearson", effect = 0.3)
  for (bad in list(list(k = 3L), list(r = 0.5), list(effect_type = "f"))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
  }
})
