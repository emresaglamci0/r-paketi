test_that("anova n matches pwr and stats", {
  for (k in c(2, 3, 4, 6)) {
    n <- engine_n(0.25, 0.05, 0.8, NULL, "anova", k)$n
    expect_lte(abs(n - pwr::pwr.anova.test(k = k, f = 0.25, power = 0.8)$n), 1)
    expect_lte(abs(n - stats::power.anova.test(groups = k, between.var = 0.25^2 * k / (k - 1),
      within.var = 1, power = 0.8)$n), 1)
  }
  expect_equal(engine_mde(53, 0.05, 0.8, NULL, "anova", 3),
    pwr::pwr.anova.test(k = 3, n = 53, power = 0.8)$f, tolerance = 0.001)
})
test_that("anova plan counts groups", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(53L, 159L, 3L))
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3, dropout = 0.1)$n_per_group, 59L)
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 4)$n_total, 180L)
  expect_true(is.na(p$alternative))
})
test_that("k = 2 matches the independent t test", {
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 2)$n_per_group, 64L)
  expect_identical(quiet_plan(effect = 0.5)$n_per_group, 64L)
})
test_that("eta squared converts to f", {
  e <- quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")
  expect_equal(e$effect_test, sqrt(0.06 / 0.94))
  expect_identical(e$n_per_group, 52L)
  f <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  g <- quiet_plan(test = "anova_oneway", effect = 0.0625 / 1.0625, k = 3, effect_type = "eta2")
  expect_identical(f$n_per_group, g$n_per_group)
})
test_that("anova arguments are validated", {
  for (bad in list(NULL, 1, 2.5, NA_real_, "a", c(2, 3))) {
    expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = bad), "'k'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, k = 3), "anova_oneway", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, effect_type = "eta2"), "anova_oneway", fixed = TRUE)
  for (bad in c(0, 1, 1.2)) {
    expect_error(plan_study(test = "anova_oneway", effect = bad, k = 3, effect_type = "eta2"), "eta2", fixed = TRUE)
  }
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, alternative = "two.sided"), "alternative", fixed = TRUE)
})
test_that("anova limits give readable errors", {
  expect_identical(tryCatch(plan_study(test = "anova_oneway", effect = 1e-5, k = 3), error = conditionMessage),
    msg("err_infeasible_plan_anova_oneway"))
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_identical(tryCatch(sensitivity(p, n = 3), error = conditionMessage), msg("err_infeasible"))
  expect_error(sensitivity(p, n = 1), "n = 1", fixed = TRUE)
})
test_that("anova sensitivity reports the entered unit", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  f <- pwr::pwr.anova.test(k = 3, n = 53, power = 0.8)$f
  expect_equal(sensitivity(p, n = 53, power = 0.8)$mde, f, tolerance = 0.001)
  e <- quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")
  expect_equal(sensitivity(e, n = 53, power = 0.8)$mde, f^2 / (1 + f^2), tolerance = 0.001)
  expect_identical(attr(sensitivity(e), "effect_type"), "eta2")
})
test_that("tampered anova plans are refused in sensitivity", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  for (bad in list(list(k = NULL), list(k = 2.5), list(effect_type = "d"), list(groups = 4L))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  }
})
test_that("huge k is refused without warnings", {
  expect_no_warning(expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3e9), "'k'", fixed = TRUE))
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  q <- utils::modifyList(p, list(k = 3e9, groups = 3e9)); class(q) <- class(p)
  expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
})
test_that("test names need an exact match", {
  expect_error(plan_study(test = "anova", effect = 0.25, k = 3), "t_paired", fixed = TRUE)
  expect_error(plan_study(test = "t_p", effect = 0.5, r = 0.5), "t_paired", fixed = TRUE)
  expect_identical(quiet_plan(effect = 0.5, alternative = "one")$alternative, "one.sided")
})
test_that("anova methods paragraph in English", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expected <- paste0(
    "An a priori power analysis was conducted in R with the plansize package (version ",
    as.character(utils::packageVersion("plansize")), "), using pwrss (version ",
    p$engine_version, "), to determine the sample size required for the planned analysis ",
    "(one-way ANOVA). The effect size used for planning was Cohen's f = 0.25 for 3 groups of equal size. ",
    "The rationale for choosing this effect size was not specified. For the overall F test ",
    "with alpha = .05 and power = .80, the required sample size was 53 participants per group ",
    "(159 in total). This sample size applies to the overall F test only; a significant result ",
    "indicates that not all group means are equal, but not which ones differ. Post hoc comparisons are ",
    "needed to identify the differing groups; with a correction for multiple comparisons, they usually require a larger sample than ",
    "the overall test.")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  e <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"), lang = "en"))
  expect_match(e, "eta squared = 0.06 for 3 groups of equal size, which corresponds to Cohen's f = 0.25.", fixed = TRUE)
  d <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3, dropout = 0.1), lang = "en"))
  expect_match(d, "the recruitment target was 59 participants per group (177 in total).", fixed = TRUE)
})
test_that("anova Turkish text and print", {
  x <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"), lang = "tr"))
  expect_match(x, "tek y\u00f6nl\u00fc varyans analizi (ANOVA) i\u00e7in", fixed = TRUE)
  expect_match(x, "Planlamada e\u015fit b\u00fcy\u00fckl\u00fckte 3 grup i\u00e7in etki b\u00fcy\u00fckl\u00fc\u011f\u00fc eta kare = 0.06", fixed = TRUE)
  expect_match(x, "post hoc kar\u015f\u0131la\u015ft\u0131rmalar gerekir", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"))))
  expect_true(any(grepl("Number of groups (k, equal sizes): 3", out, fixed = TRUE)))
  expect_true(any(grepl("(eta squared): 0.06", out, fixed = TRUE)))
  expect_true(any(grepl("(Cohen's f): 0.25", out, fixed = TRUE)))
  expect_true(any(grepl("Post hoc", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
  s <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(sensitivity(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")))))
  expect_true(any(grepl("(eta squared)", s, fixed = TRUE)))
})
test_that("no sprintf warnings across tests and variants", {
  plans <- list(
    list(effect = 0.5), list(test = "t_paired", effect = 0.5, r = 0.5),
    list(test = "anova_oneway", effect = 0.25, k = 3),
    list(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"))
  for (a in plans) for (dr in c(0, 0.1)) for (de in c(1, 1.5)) for (lg in c("en", "tr")) {
    p <- do.call(plan_study, c(a, list(effect_basis = "pilot", dropout = dr, deff = de)))
    withr::with_options(list(plansize.lang = lg), {
      expect_no_warning(capture.output(print(p)))
      expect_no_warning(capture.output(print(sensitivity(p))))
      expect_no_warning(write_methods(p))
    })
  }
})
test_that("tampered anova plans are refused in print and methods", {
  q <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3); q$k <- NULL
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
test_that("relabelled anova plans are refused", {
  q <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3); q$test <- "t_independent"
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
