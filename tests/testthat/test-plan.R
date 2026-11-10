test_that("basic plan gives 64 per group", {
  p <- quiet_plan(effect = 0.5)
  expect_s3_class(p, "plansize_plan")
  expect_identical(p$n_per_group, 64L)
  expect_identical(p$n_total, 128L)
  expect_identical(p$effect_basis, "unknown")
})
test_that("corrections apply in spec order with one final ceiling", {
  expect_identical(quiet_plan(effect = 0.5, dropout = 0.1)$n_per_group, 71L)
  expect_identical(quiet_plan(effect = 0.5, deff = 1.5, dropout = 0.1)$n_per_group, 107L)
})
test_that("invalid inputs give readable errors", {
  for (e in list(0, -0.5, NA_real_, c(0.2, 0.5), "a")) {
    expect_error(plan_study(effect = e), "effect")
  }
  for (a in list(0, 1, 1.5, -0.1, "a")) {
    expect_error(plan_study(effect = 0.5, alpha = a), "alpha")
    expect_error(plan_study(effect = 0.5, power = a), "power")
  }
  expect_error(plan_study(effect = 0.5, dropout = 1), "dropout")
  expect_error(plan_study(effect = 0.5, dropout = -0.1), "dropout")
  expect_error(plan_study(effect = 0.5, deff = 0.9), "deff")
  expect_error(plan_study(test = "anova", effect = 0.5), "t_paired", fixed = TRUE)
})
test_that("engine prints nothing", {
  expect_output(quiet_plan(effect = 0.5), NA)
})

test_that("infeasible plan_study designs give the plan message", {
  expect_error(plan_study(effect = 3), msg("err_infeasible_plan"), fixed = TRUE)
  expect_error(plan_study(effect = 1e-5), msg("err_infeasible_plan"), fixed = TRUE)
})
test_that("wrong choices and missing args give bilingual errors", {
  for (l in c("en", "tr")) {
    withr::local_options(plansize.lang = l)
    e <- tryCatch(plan_study(effect = 0.5, alternative = "greater"), error = conditionMessage)
    expect_match(e, "alternative", fixed = TRUE)
    expect_match(e, "one.sided", fixed = TRUE)
    expect_false(grepl("should be one of", e, fixed = TRUE))
    expect_error(plan_study(effect = 0.5, effect_basis = "zzz"), "effect_basis")
    expect_error(plan_study(), "effect")
  }
  expect_identical(quiet_plan(effect = 0.5, alternative = "one")$alternative, "one.sided")
  expect_error(plan_study(effect = 0.5, effect_source = 1), "effect_source")
  expect_error(plan_study(effect = 0.5, effect_source = c("a", "b")), "effect_source")
})
test_that("power range and power above alpha are checked", {
  for (l in c("en", "tr")) {
    withr::local_options(plansize.lang = l)
    for (pw in c(0.995, 0.005)) {
      e <- tryCatch(plan_study(effect = 0.5, power = pw), error = conditionMessage)
      expect_match(e, "power", fixed = TRUE)
      expect_false(grepl("does not have a valid", e, fixed = TRUE))
    }
    expect_error(plan_study(effect = 0.5, alpha = 0.2, power = 0.2), msg("err_power_alpha"),
      fixed = TRUE)
  }
})
test_that("n_effective-related rounding is tolerant and overflow is an error", {
  expect_identical(quiet_plan(effect = 0.5)$n_per_group, 64L)
  expect_no_warning(e <- tryCatch(plan_study(effect = 1e-4), error = conditionMessage))
  expect_identical(e, msg("err_overflow"))
  expect_no_warning(e <- tryCatch(plan_study(effect = 0.5, deff = 1e9), error = conditionMessage))
  expect_identical(e, msg("err_overflow"))
})
test_that("one sided plan matches power.t.test", {
  ref <- stats::power.t.test(delta = 0.5, sd = 1, power = 0.8, type = "two.sample",
    alternative = "one.sided")$n
  expect_lte(abs(quiet_plan(effect = 0.5, alternative = "one.sided")$n_analytic - ref), 1)
})
test_that("errors appear in Turkish", {
  withr::local_options(plansize.lang = "tr")
  expect_error(plan_study(effect = -1), "Arg\u00fcman")
})
test_that("observed effect basis is refused before the engine", {
  expect_error(plan_study(effect = 0.5, effect_basis = "observed"), "sensitivity()", fixed = TRUE)
  expect_error(plan_study(effect = 50, effect_basis = "observed"), "sensitivity()", fixed = TRUE)
  withr::with_options(list(plansize.lang = "tr"),
    expect_error(plan_study(effect = 0.5, effect_basis = "observed"), "kullan\u0131lamaz", fixed = TRUE))
})
test_that("unknown and convention warn with their own class", {
  expect_warning(plan_study(effect = 0.5), class = "plansize_basis_warning")
  expect_warning(plan_study(effect = 0.5, effect_basis = "convention"), class = "plansize_basis_warning")
  withr::with_options(list(plansize.lang = "tr"),
    expect_warning(plan_study(effect = 0.5), "dayana\u011f\u0131 bilinmiyor", fixed = TRUE))
})
test_that("justified bases do not warn", {
  for (b in c("prior_study", "pilot", "smallest_of_interest")) {
    expect_no_warning(plan_study(effect = 0.5, effect_basis = b))
  }
})
test_that("a warned plan is still complete", {
  p <- quiet_plan(effect = 0.5)
  expect_no_warning(quiet_plan(effect = 0.5))
  expect_identical(p$n_per_group, 64L)
  expect_identical(p$effect_basis, "unknown")
})
test_that("an invalid call errors without the basis warning", {
  expect_no_warning(try(plan_study(effect = 0), silent = TRUE))
  expect_no_warning(try(plan_study(effect = 3), silent = TRUE))
})
test_that("later steps do not warn again", {
  p <- quiet_plan(effect = 0.5)
  expect_no_warning(sensitivity(p))
  expect_no_warning(write_methods(p))
})
test_that("the muffler leaves other warnings visible", {
  expect_warning(quiet_plan_with(function() warning("other")), "other")
})
