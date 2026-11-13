test_that("two proportions match stats", {
  pairs <- list(c(0.45, 0.30), c(0.30, 0.45), c(0.10, 0.05), c(0.50, 0.60),
                c(0.01, 0.02), c(0.98, 0.99), c(0.2, 0.9))
  for (p in pairs) for (alt in c("two.sided", "one.sided")) {
    n <- engine_n_props(p[1], p[2], 0.05, 0.8, alt)
    ref <- stats::power.prop.test(p1 = p[1], p2 = p[2], power = 0.8, alternative = alt)$n
    expect_equal(n, ceiling(ref))
  }
})
test_that("prop_two plan", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(163L, 326L, 2L))
  expect_equal(p$effect_test, 0.15)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45)$n_per_group, 163L)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, alternative = "one.sided")$n_per_group, 128L)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, dropout = 0.1)$n_per_group, 182L)
})
test_that("prop_two arguments are validated", {
  expect_error(plan_study(test = "prop_two", p2 = 0.3), "'p1' is required", fixed = TRUE)
  expect_error(plan_study(test = "prop_two", p1 = 0.3), "'p2' is required", fixed = TRUE)
  for (bad in list(0, 1, 1.2, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "prop_two", p1 = bad, p2 = 0.3), "'p1'", fixed = TRUE)
  }
  expect_error(plan_study(test = "prop_two", p1 = 0.3, p2 = 0.3), "differ", fixed = TRUE)
  expect_error(plan_study(test = "prop_two", effect = 0.5, p1 = 0.45, p2 = 0.3), "'effect'", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, p1 = 0.45, p2 = 0.3), "prop_two", fixed = TRUE)
  expect_error(plan_study(test = "prop_two", p1 = 0.45, p2 = 0.3, k = 3), "'k'", fixed = TRUE)
})
test_that("prop_two sensitivity has the right direction and power", {
  up <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  m <- sensitivity(up, n = 163, power = 0.8)$mde
  expect_gt(m, 0.30)
  expect_equal(stats::power.prop.test(n = 163, p1 = m, p2 = 0.30)$power, 0.8, tolerance = 0.01)
  down <- quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45)
  d <- sensitivity(down, n = 163, power = 0.8)$mde
  expect_lt(d, 0.45)
  expect_equal(stats::power.prop.test(n = 163, p1 = d, p2 = 0.45)$power, 0.8, tolerance = 0.01)
  expect_identical(tryCatch(sensitivity(up, n = 3), error = conditionMessage), msg("err_infeasible"))
})
test_that("prop_two methods and print", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "were .45 in group 1 and .30 in group 2 (Yilmaz, 2021), a difference (group 1 minus group 2) of .15.", fixed = TRUE)
  expect_match(x, "For a two-sided z test for two independent proportions with a pooled standard error and no continuity correction, with alpha = .05", fixed = TRUE)
  expect_match(x, "163 participants per group (326 in total)", fixed = TRUE)
  expect_false(grepl(") (", x, fixed = TRUE))
  expect_false(grepl("))", x, fixed = TRUE))
  expect_match(x, "for the planned analysis, a comparison of two independent proportions (z test).", fixed = TRUE)
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "S\u00fcreklilik d\u00fczeltmesi uygulanmayan, havuzlanm\u0131\u015f standart hatal\u0131 ba\u011f\u0131ms\u0131z iki oran z testi (iki y\u00f6nl\u00fc)", fixed = TRUE)
  expect_false(grepl(") (", t, fixed = TRUE))
  d <- unclass(write_methods(quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45), lang = "en"))
  expect_match(d, "a difference (group 1 minus group 2) of -.15.", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("(p1): 0.45", out, fixed = TRUE)))
  expect_true(any(grepl("Difference (p1 - p2): 0.15", out, fixed = TRUE)))
  expect_false(any(grepl("Cohen", out, fixed = TRUE)))
})
test_that("tampered prop_two plans are refused", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  for (bad in list(list(p1 = NULL), list(p1 = 0.30), list(p2 = 2))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
test_that("p1 and p2 are refused by the other tests", {
  expect_error(plan_study(effect = 0.5, p1 = 0.4), "prop_two", fixed = TRUE)
  expect_error(plan_study(test = "t_paired", effect = 0.5, r = 0.5, p2 = 0.4), "prop_two", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, p1 = 0.4), "prop_two", fixed = TRUE)
})
test_that("prop_two detectable p1 solves for the target power", {
  for (a in list(c(0.10, 0.05), c(0.34, 0.30), c(0.05, 0.10))) {
    s <- sensitivity(quiet_plan(test = "prop_two", p1 = a[1], p2 = a[2]))
    for (i in seq_len(nrow(s))) {
      expect_equal(stats::power.prop.test(n = s$n_effective[i], p1 = s$mde[i], p2 = a[2])$power,
                   s$power[i], tolerance = 0.01)
    }
    expect_equal(sign(s$mde - a[2]), rep(sign(a[1] - a[2]), nrow(s)))
  }
  expect_equal(sensitivity(quiet_plan(test = "prop_two", p1 = 0.10, p2 = 0.05), n = 435, power = 0.8)$mde, 0.10, tolerance = 0.005)
  expect_equal(sensitivity(quiet_plan(test = "prop_two", p1 = 0.34, p2 = 0.30), n = 2000, power = 0.8)$mde, 0.341, tolerance = 0.005)
  high <- quiet_plan(test = "prop_two", p1 = 0.01, p2 = 0.002)
  m <- sensitivity(high, n = 10000, power = 0.8)$mde
  expect_equal(stats::power.prop.test(n = 10000, p1 = m, p2 = 0.002)$power, 0.8, tolerance = 0.01)
})
test_that("prop_two engine errors are readable", {
  en <- msg("err_infeasible_plan_prop_two", lang = "en")
  expect_identical(tryCatch(withr::with_options(list(plansize.lang = "en"), plan_study(test = "prop_two", p1 = 0.9, p2 = 0.002)), error = conditionMessage), en)
  expect_identical(tryCatch(withr::with_options(list(plansize.lang = "en"), plan_study(test = "prop_two", p1 = 0.5, p2 = 0.5000001)), error = conditionMessage), en)
})
