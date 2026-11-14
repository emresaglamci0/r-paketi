test_that("regression n matches pwr", {
  # pwr returns df2 (v); total n = v + u + 1.
  for (R2 in c(0.02, 0.13, 0.26, 0.5)) for (k in c(1, 3, 5, 10))
    for (a in c(0.05, 0.01)) for (pw in c(0.8, 0.9)) {
      f2 <- R2 / (1 - R2)
      ref <- pwr::pwr.f2.test(u = k, f2 = f2, sig.level = a, power = pw)$v + k + 1
      expect_lte(abs(engine_n_reg(R2, k, a, pw) - ref), 1)
    }
  expect_equal(engine_n_reg(0.13, 3, 0.05, 0.8), 76.985, tolerance = 1e-5)
})
test_that("reg_overall plan", {
  q <- function(...) quiet_plan(test = "reg_overall", ...)
  p <- q(effect = 0.13, effect_type = "r2", predictors = 3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(77L, 77L, 1L))
  expect_identical(q(effect = 0.02, effect_type = "r2", predictors = 1)$n_total, 387L)
  expect_identical(q(effect = 0.26, effect_type = "r2", predictors = 5)$n_total, 43L)
  expect_identical(q(effect = 0.02, effect_type = "r2", predictors = 10)$n_total, 806L)
  expect_identical(q(effect = 0.13, effect_type = "r2", predictors = 3, dropout = 0.1)$n_total, 86L)
  # f2 and r2 are the same plan
  expect_identical(q(effect = 0.15, effect_type = "f2", predictors = 3)$n_total,
                   q(effect = 0.15 / 1.15, effect_type = "r2", predictors = 3)$n_total)
  expect_true(is.na(p$alternative))
})
test_that("more predictors need more n, larger R2 needs less", {
  q <- function(...) quiet_plan(test = "reg_overall", effect_type = "r2", ...)$n_total
  expect_lt(q(effect = 0.13, predictors = 3), q(effect = 0.13, predictors = 6))
  expect_gt(q(effect = 0.13, predictors = 3), q(effect = 0.26, predictors = 3))
})
test_that("reg_overall effect and effect_type are validated", {
  for (bad in list(0, 1, 0.995, -0.1, NA_real_, c(0.1, 0.2), "a"))
    expect_error(plan_study(test = "reg_overall", effect = bad, effect_type = "r2", predictors = 3), "'effect'", fixed = TRUE)
  for (bad in list(0, -1, 100, 1e6, NA_real_, "a"))
    expect_error(plan_study(test = "reg_overall", effect = bad, effect_type = "f2", predictors = 3), "'effect'", fixed = TRUE)
  # effect_type is required and matches exactly
  expect_error(plan_study(test = "reg_overall", effect = 0.1, predictors = 3), "'effect_type'", fixed = TRUE)
  for (bad in list("f", "eta2", "r", "f2 ", NA_character_, c("f2", "r2")))
    expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = bad, predictors = 3), "'effect_type'", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.5, k = 3, effect_type = "r2"), "'effect_type'", fixed = TRUE)
  expect_error(plan_study(test = "t_independent", effect = 0.5, effect_type = "r2"), "reg_overall", fixed = TRUE)
})
test_that("anova_oneway without effect_type still uses f", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_identical(p$effect_type, "f")
  expect_identical(p$n_per_group, 53L)
})
test_that("reg_overall other arguments are validated", {
  for (bad in list(NULL, 0, 1.5, 1001, NA_real_, "a"))
    expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = bad), "'predictors'", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, k = 3), "'k'", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, rows = 2), "'rows'", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, predictors = 3), "reg_overall", fixed = TRUE)
})
test_that("near-impossible reg_overall designs give the readable error", {
  for (args in list(list(effect = 0.99, predictors = 1), list(effect = 1e-8, predictors = 1000)))
    expect_identical(tryCatch(do.call(plan_study, c(list(test = "reg_overall", effect_type = "r2"), args)),
      error = conditionMessage), msg("err_infeasible_plan_reg_overall"))
  # neighbour that still works
  expect_identical(quiet_plan(test = "reg_overall", effect = 0.98, effect_type = "r2", predictors = 1)$n_total, 4L)
})
test_that("reg_overall sensitivity", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  s <- sensitivity(p, n = 100, power = 0.8)
  f2 <- pwr::pwr.f2.test(u = 3, v = 100 - 3 - 1, power = 0.8)$f2
  expect_equal(s$mde, f2 / (1 + f2), tolerance = 0.001)
  # power at the returned mde is the target (no flat-region artifact)
  expect_equal(pwrss::power.f.reg(r.squared.change = s$mde, k.total = 3, n = 100, verbose = 0)$power, 0.8, tolerance = 1e-3)
  pf <- quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3)
  expect_equal(sensitivity(pf, n = 100, power = 0.8)$mde, f2, tolerance = 0.001)
  expect_identical(attr(sensitivity(pf), "effect_type"), "f2")
  # below min_n
  expect_identical(tryCatch(sensitivity(p, n = 2), error = conditionMessage), msg("err_n_small", 2, 3))
  # n <= predictors + 1: pwrss "Design is not feasible."
  for (n in 3:4)
    expect_identical(tryCatch(sensitivity(p, n = n), error = conditionMessage), msg("err_infeasible"))
})
test_that("reg_overall methods and print", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "R-squared = 0.13 (Yilmaz, 2021) for a regression model with 3 predictors.", fixed = TRUE)
  expect_match(x, "the required sample size was 77 participants in total.", fixed = TRUE)
  expect_match(x, "Predictors were treated as fixed", fixed = TRUE)
  pf <- quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3)
  expect_match(unclass(write_methods(pf, lang = "en")), "Cohen's f-squared = 0.15", fixed = TRUE)
  expect_match(unclass(write_methods(pf, lang = "en")), "equivalent to R-squared = 0.13, for", fixed = TRUE)
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "3 yorday\u0131c\u0131l\u0131 regresyon modeli", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Number of predictors: 3", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
})
test_that("reg_overall methods have no double parentheses (m_intro regression)", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3, effect_source = "Yilmaz, 2021")
  pf <- quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3, effect_source = "Pilot A")
  for (pl in list(p, pf)) for (lg in c("en", "tr")) {
    x <- unclass(write_methods(pl, lang = lg))
    expect_false(grepl("((", x, fixed = TRUE))
    expect_false(grepl("))", x, fixed = TRUE))
    expect_false(grepl(") (", x, fixed = TRUE))
  }
})
test_that("tampered reg_overall plans are refused", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  for (bad in list(list(predictors = NULL), list(predictors = 0L), list(effect_type = "f"),
                   list(effect_type = NA_character_), list(effect_test = 0.5),
                   list(effect = 1.5, effect_test = 1.5))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
