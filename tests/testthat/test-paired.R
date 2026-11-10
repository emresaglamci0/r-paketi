test_that("paired n matches stats and pwr references", {
  grid <- expand.grid(d = c(0.2, 0.5, 0.8), power = c(0.8, 0.9), alpha = c(0.05, 0.01))
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    n <- engine_n(g$d, g$alpha, g$power, "two.sided", "paired")$n
    ref <- stats::power.t.test(delta = g$d, sd = 1, sig.level = g$alpha, power = g$power, type = "paired")$n
    expect_lte(abs(n - ref), 1)
  }
  ref1 <- stats::power.t.test(delta = 0.5, sd = 1, power = 0.8, type = "paired", alternative = "one.sided")$n
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "one.sided", "paired")$n - ref1), 1)
  skip_if_not_installed("pwr")
  expect_equal(engine_mde(34, 0.05, 0.8, "two.sided", "paired"),
    pwr::pwr.t.test(n = 34, power = 0.8, type = "paired")$d, tolerance = 0.001)
})
test_that("d and r convert to dz and drive n", {
  for (r in c(0.2, 0.5, 0.8)) {
    p <- quiet_plan(test = "t_paired", effect = 0.5, r = r)
    dz <- 0.5 / sqrt(2 * (1 - r))
    expect_equal(p$effect_test, dz)
    ref <- stats::power.t.test(delta = dz, sd = 1, power = 0.8, type = "paired")$n
    expect_lte(abs(p$n_analytic - ref), 1)
  }
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.2)$n_per_group, 53L)
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.8)$n_per_group, 15L)
})
test_that("paired plan counts participants once", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(34L, 34L, 1L))
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1)$n_per_group, 38L)
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, deff = 1.5, dropout = 0.1)$n_per_group, 56L)
})
test_that("independent plan is unchanged", {
  p <- quiet_plan(effect = 0.5)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(64L, 128L, 2L))
  expect_equal(p$effect_test, 0.5)
})
test_that("r is validated", {
  expect_error(plan_study(test = "t_paired", effect = 0.5), "'r'", fixed = TRUE)
  for (bad in list(1, -1, NA_real_, c(0.2, 0.5), "a")) {
    expect_error(plan_study(test = "t_paired", effect = 0.5, r = bad), "'r'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, r = 0.5), "t_paired", fixed = TRUE)
  expect_s3_class(quiet_plan(test = "t_paired", effect = 0.5, r = 0), "plansize_plan")
  expect_s3_class(quiet_plan(test = "t_paired", effect = 0.5, r = -0.3), "plansize_plan")
})
test_that("unknown test lists the supported tests", {
  expect_error(plan_study(test = "anova", effect = 0.5), "t_paired", fixed = TRUE)
})
test_that("paired limits give readable errors", {
  expect_identical(tryCatch(plan_study(test = "t_paired", effect = 3, r = 0.5), error = conditionMessage),
    msg("err_infeasible_plan_t_paired"))
  expect_identical(tryCatch(plan_study(test = "t_paired", effect = 0.8, r = 0.95), error = conditionMessage),
    "pwrss cannot solve this design: the required number of participants is under 4 or over 10 billion. A very high r makes dz much larger than d; check effect, r, alpha and power.")
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expect_error(sensitivity(p, n = 3), "n = 3", fixed = TRUE)
  expect_true(is.numeric(sensitivity(p, n = 4)$mde))
})
test_that("paired sensitivity reports d under the same r", {
  skip_if_not_installed("pwr")
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.8)
  dz <- pwr::pwr.t.test(n = 34, power = 0.8, type = "paired")$d
  expect_equal(sensitivity(p, n = 34, power = 0.8)$mde, dz * sqrt(2 * (1 - 0.8)), tolerance = 0.001)
})
test_that("tampered plans are refused in sensitivity", {
  p <- quiet_plan(effect = 0.5)
  for (bad in list(list(effect_basis = "observed"), list(effect_basis = NULL), list(test = "anova"))) {
    q <- utils::modifyList(p, bad)
    class(q) <- class(p)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  }
})
test_that("paired methods paragraph in English", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expected <- paste0(
    "An a priori power analysis was conducted in R with the plansize package (version ",
    as.character(utils::packageVersion("plansize")), "), using pwrss (version ",
    p$engine_version, "), to determine the sample size required for the planned analysis ",
    "(paired t test). The effect size used for planning was Cohen's d = 0.50, defined as the mean change divided by the standard deviation of a single measurement; with an ",
    "assumed correlation of r = .50 between the two measurements, this corresponds to ",
    "dz = 0.50. The rationale for choosing this effect size was not specified. For a ",
    "two-sided test with alpha = .05 and power = .80, the required sample size was ",
    "34 participants, each measured twice.")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  d <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1), lang = "en"))
  expect_match(d, "dropout rate of 10%, the recruitment target was 38 participants.", fixed = TRUE)
  n <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = -0.3), lang = "en"))
  expect_match(n, "r = -.30", fixed = TRUE)
  expect_match(n, "dz = 0.31", fixed = TRUE)
})
test_that("paired Turkish text and print", {
  x <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1), lang = "tr"))
  expect_match(x, "ba\u011f\u0131ml\u0131 \u00f6rneklemler t testi i\u00e7in", fixed = TRUE)
  expect_match(x, "korelasyon r = .50", fixed = TRUE)
  expect_match(x, "her biri iki kez \u00f6l\u00e7\u00fclecek 34 kat\u0131l\u0131mc\u0131d\u0131r", fixed = TRUE)
  expect_match(x, "kat\u0131l\u0131mc\u0131 say\u0131s\u0131 38 olarak", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5))))
  expect_true(any(grepl("(r): 0.5", out, fixed = TRUE)))
  expect_true(any(grepl("dz", out, fixed = TRUE)))
  expect_false(any(grepl("Total", out, fixed = TRUE)))
  s <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(sensitivity(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)))))
  expect_true(any(grepl("Recruited participants", s, fixed = TRUE)))
  expect_true(any(grepl("assuming the same r", s, fixed = TRUE)))
})
test_that("tampered plans are refused in print and methods", {
  q <- quiet_plan(effect = 0.5); q$effect_basis <- "observed"
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
test_that("a paired plan without a valid r is refused everywhere", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  for (bad in list(NULL, 1, -1, NA_real_, c(0.2, 0.3), "a")) {
    q <- p; q["r"] <- list(bad)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
test_that("tamper: missing groups or effect_test is refused", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  for (field in c("groups", "effect_test")) {
    q <- p; q[field] <- list(NULL)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
test_that("negative r matches stats", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = -0.3)
  ref <- stats::power.t.test(delta = 0.5 / sqrt(2 * 1.3), sd = 1, power = 0.8, type = "paired")$n
  expect_lte(abs(p$n_analytic - ref), 1)
})
test_that("one-sided paired sensitivity matches pwr", {
  skip_if_not_installed("pwr")
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, alternative = "one.sided")
  dz <- pwr::pwr.t.test(n = 34, power = 0.8, type = "paired", alternative = "greater")$d
  expect_equal(sensitivity(p, n = 34, power = 0.8)$mde, dz * sqrt(2 * (1 - 0.5)), tolerance = 0.001)
})
test_that("no warnings across tests, adjustments and languages", {
  for (tst in c("t_independent", "t_paired")) for (dr in c(0, 0.1)) for (df in c(1, 1.5)) for (l in c("en", "tr")) {
    p <- if (tst == "t_paired") quiet_plan(test = tst, effect = 0.5, r = 0.5, dropout = dr, deff = df, effect_basis = "pilot")
         else quiet_plan(test = tst, effect = 0.5, dropout = dr, deff = df, effect_basis = "pilot")
    withr::with_options(list(plansize.lang = l), {
      expect_no_warning(capture.output(print(p)))
      expect_no_warning(capture.output(print(sensitivity(p))))
      expect_no_warning(write_methods(p))
    })
  }
})

test_that("paired source and definition do not stack parentheses", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, effect_source = "Yilmaz, 2021")
  e <- unclass(write_methods(p, lang = "en"))
  expect_match(e, "d = 0.50 (Yilmaz, 2021), defined as", fixed = TRUE)
  expect_false(grepl(") (", e, fixed = TRUE))
  expect_false(grepl(") (", unclass(write_methods(p, lang = "tr")), fixed = TRUE))
})

