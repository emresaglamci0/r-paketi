# Random-predictor information line (slice 9c). Expected values come from the published
# G*Power example, DMAR measurements reproduced in R, and a random-normal-X simulation.
# plansize:::has_dmar() wraps requireNamespace("DMAR"); plansize:::dmar_required_n() wraps
# DMAR::ss_power_R2() and returns necessary_N; plansize:::random_predictor_n(plan) -> integer or NULL.
q_reg <- function(r2, k, ...) quiet_plan(test = "reg_overall", effect = r2, effect_type = "r2", predictors = k, ...)
# Lines of print() output in one language, optionally with DMAR taken away.
print_lines <- function(plan, lang = "en") {
  withr::local_options(plansize.lang = lang)
  capture.output(print(plan))
}
random_line <- function(out, lang = "en") grep(if (lang == "en") "random" else "rastgele", out, ignore.case = TRUE, value = TRUE)

test_that("DMAR random-predictor power matches the published G*Power example", {
  skip_if_not_installed("DMAR")
  r <- DMAR::ss_power_R2(population_R2 = 0.10, p = 5, specified_N = 95, alpha_level = 0.05,
                         random_predictors = TRUE)
  expect_equal(r$value[r$term == "actual_power"], 0.662627, tolerance = 1e-4)  # Faul et al. 2009, ex. 1
})
test_that("random-predictor n for the measured cases", {
  skip_if_not_installed("DMAR")
  # Pinned DMAR output (regression guard); independent checks are the G*Power value above
  # and the random-X simulation below.
  expect_identical(plansize:::random_predictor_n(q_reg(0.13, 3)), 80L)
  expect_identical(plansize:::random_predictor_n(q_reg(0.02, 1)), 390L)
  expect_identical(plansize:::random_predictor_n(q_reg(0.26, 5)), 45L)
  expect_identical(plansize:::random_predictor_n(q_reg(0.50, 3)), 18L)
  # the plan n (pwrss, fixed predictors) is unchanged
  expect_identical(c(q_reg(0.13, 3)$n_total, q_reg(0.02, 1)$n_total, q_reg(0.26, 5)$n_total, q_reg(0.50, 3)$n_total),
                   c(77L, 387L, 43L, 16L))
})
test_that("random-predictor power at the DMAR n matches simulation", {
  skip_on_cran(); skip_if_not_installed("DMAR")
  # Random normal predictors, equal slopes; F test via .lm.fit sums of squares.
  sim <- function(r2, k, n, reps = 4000) {
    set.seed(1); b <- sqrt(r2 / k)
    mean(replicate(reps, {
      X <- matrix(rnorm(n * k), n, k); y <- drop(X %*% rep(b, k)) + rnorm(n, sd = sqrt(1 - r2))
      rss <- sum(.lm.fit(cbind(1, X), y)$residuals^2); tss <- sum((y - mean(y))^2)
      pf(((tss - rss) / k) / (rss / (n - k - 1)), k, n - k - 1, lower.tail = FALSE) < 0.05
    }))
  }
  expect_lte(abs(sim(0.26, 5, 45) - 0.80), 0.03)   # DMAR actual_power .802
  expect_lt(sim(0.26, 5, 43), sim(0.26, 5, 45))     # the fixed-model n falls short
})

test_that("print shows the random-predictors line for reg_overall in both languages", {
  skip_if_not_installed("DMAR")
  p <- q_reg(0.13, 3)
  en <- random_line(print_lines(p, "en"), "en")
  tr <- random_line(print_lines(p, "tr"), "tr")
  expect_length(en, 1L); expect_length(tr, 1L)
  expect_match(en, "80", fixed = TRUE); expect_match(tr, "80", fixed = TRUE)
  # information only: the rest of the output is the plan as before
  expect_match(print_lines(p, "en")[1:2], "77", fixed = TRUE, all = FALSE)
  # also for f2 and with more predictors
  expect_length(random_line(print_lines(quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3))), 1L)
})
test_that("dropout and design effect apply to the line, not to the plan n", {
  skip_if_not_installed("DMAR")
  p <- q_reg(0.13, 3, dropout = 0.1, deff = 1.5)
  expect_identical(plansize:::random_predictor_n(p), as.integer(ceiling(80 * 1.5 / 0.9)))  # 134
  expect_match(random_line(print_lines(p)), "134", fixed = TRUE)
  expect_identical(q_reg(0.13, 3, dropout = 0.1)$n_total, 86L)   # plan n as in slice 9
  expect_identical(plansize:::random_predictor_n(q_reg(0.13, 3, dropout = 0.1)), 89L)
})
test_that("the methods text and other tests never carry the line", {
  skip_if_not_installed("DMAR")
  p <- q_reg(0.13, 3)
  for (lang in c("en", "tr")) {  # print of other tests (the methods text already says "random" once, so it is compared below)
    expect_length(random_line(print_lines(quiet_plan(effect = 0.5), lang), lang), 0L)
    expect_length(random_line(print_lines(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3), lang), lang), 0L)
    expect_length(random_line(print_lines(quiet_plan(test = "reg_partial", effect = 0.13, effect_type = "r2_change",
                                                      predictors = 3, tested = 1, r2_covariates = 0), lang), lang), 0L)
  }
  # the methods text is identical with and without DMAR
  with_dmar <- unclass(write_methods(p, lang = "en"))
  testthat::local_mocked_bindings(has_dmar = function() FALSE, .package = "plansize")
  expect_identical(unclass(write_methods(p, lang = "en")), with_dmar)
})

test_that("without DMAR print has no line and the plan is unchanged", {
  p <- q_reg(0.13, 3)
  testthat::local_mocked_bindings(has_dmar = function() FALSE, .package = "plansize")
  expect_null(plansize:::random_predictor_n(p))
  for (lang in c("en", "tr")) expect_length(random_line(print_lines(p, lang), lang), 0L)
  expect_identical(p$n_total, 77L)
})
test_that("DMAR trouble and huge n skip the line silently", {
  p <- q_reg(0.13, 3)
  testthat::local_mocked_bindings(has_dmar = function() TRUE, .package = "plansize")
  for (f in list(function(...) stop("boom"), function(...) warning("NaNs"), function(...) NA_real_, function(...) 0)) {
    testthat::local_mocked_bindings(dmar_required_n = f, .package = "plansize")
    expect_silent(v <- plansize:::random_predictor_n(p))
    expect_null(v)
    expect_silent(out <- print_lines(p))
    expect_length(random_line(out), 0L)
  }
  # n_analytic > 1e5 (R2 1e-4, k 3 gives about 109,000): DMAR is not called (21 s at R2 1e-5)
  testthat::local_mocked_bindings(dmar_required_n = function(...) stop("must not be called"), .package = "plansize")
  small <- q_reg(1e-4, 3)
  expect_gt(small$n_total, 1e5)
  expect_silent(v <- plansize:::random_predictor_n(small))
  expect_null(v)
  expect_length(random_line(print_lines(small)), 0L)
})
