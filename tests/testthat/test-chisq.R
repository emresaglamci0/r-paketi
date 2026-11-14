test_that("chi-square n matches pwr", {
  for (w in c(0.1, 0.3, 0.5)) for (df in c(1, 2, 4)) {
    n <- engine_n_chisq(w, df, 0.05, 0.8)
    expect_lte(abs(n - pwr::pwr.chisq.test(w = w, df = df, power = 0.8)$N), 1)
  }
  expect_lte(abs(engine_n_chisq(0.3, 2, 0.01, 0.9) - pwr::pwr.chisq.test(w = 0.3, df = 2, sig.level = 0.01, power = 0.9)$N), 1)
})
test_that("chisq_indep plan", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2)
  expect_identical(c(p$n_per_group, p$n_total, p$groups, p$df), c(88L, 88L, 1L, 1L))
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)$n_total, 108L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 3, cols = 3)$n_total, 133L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, dropout = 0.1)$n_total, 97L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 1, rows = 2, cols = 2)$groups, 1L)
})
test_that("chisq_indep arguments are validated", {
  for (bad in list(0, 1.2, -0.3, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "chisq_indep", effect = bad, rows = 2, cols = 2), "'effect'", fixed = TRUE)
  }
  for (bad in list(NULL, 1, 2.5, 1001, NA_real_, "a")) {
    expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = bad, cols = 2), "'rows'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, rows = 2, cols = 2), "chisq_indep", fixed = TRUE)
  expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, k = 3), "'k'", fixed = TRUE)
  expect_identical(tryCatch(plan_study(test = "chisq_indep", effect = 1e-5, rows = 2, cols = 2), error = conditionMessage),
    msg("err_infeasible_plan_chisq_indep"))
})
test_that("chisq_indep sensitivity", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)
  expect_equal(sensitivity(p, n = 108, power = 0.8)$mde,
    pwr::pwr.chisq.test(N = 108, df = 2, power = 0.8)$w, tolerance = 0.001)
  expect_identical(tryCatch(sensitivity(p, n = 3), error = conditionMessage), msg("err_infeasible"))
})
test_that("chisq_indep methods and print", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "(chi-square test of independence).", fixed = TRUE)
  expect_match(x, "Cohen's w = 0.30 (Yilmaz, 2021) for a 2 x 3 contingency table with 2 degrees of freedom.", fixed = TRUE)
  expect_match(x, "Pearson's chi-square test of independence without continuity correction, with alpha", fixed = TRUE)
  expect_match(x, "the required sample size was 108 participants in total.", fixed = TRUE)
  expect_false(grepl("))", x, fixed = TRUE)); expect_false(grepl(") (", x, fixed = TRUE))
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "serbestlik derecesi 2 olan 2 x 3 \u00e7apraz tablo i\u00e7in", fixed = TRUE)
  expect_match(t, "ki-kare ba\u011f\u0131ms\u0131zl\u0131k testinde alfa", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Table size (rows x columns): 2 x 3; degrees of freedom: 2", out, fixed = TRUE)))
  expect_true(any(grepl("(Cohen's w): 0.3", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
})
test_that("tampered chisq_indep plans are refused", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)
  for (bad in list(list(rows = NULL), list(rows = 1), list(df = 5), list(effect_test = 1.5))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
test_that("cols is validated like rows", {
  for (bad in list(NULL, 1, 2.5, 1001, NA_real_, "a")) {
    expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = 2, cols = bad), "'cols'", fixed = TRUE)
  }
})
test_that("rows and cols are refused for other tests", {
  for (a in list(list(test = "prop_two", p1 = 0.45, p2 = 0.3), list(test = "cor_pearson", effect = 0.3),
                 list(test = "anova_oneway", effect = 0.25, k = 3))) {
    expect_error(do.call(plan_study, c(a, list(rows = 2, cols = 2))), msg("err_table_unused"), fixed = TRUE)
  }
})
test_that("chisq_indep plan with a planted alternative is refused", {
  q <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3); q$alternative <- "one.sided"
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
