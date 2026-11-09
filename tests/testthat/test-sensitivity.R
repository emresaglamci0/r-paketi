test_that("sensitivity matches pwr without corrections", {
  skip_if_not_installed("pwr")
  s <- sensitivity(plan_study(effect = 0.5), n = 64, power = 0.8)
  expect_s3_class(s, "plansize_sensitivity")
  expect_equal(s$mde, pwr::pwr.t.test(n = 64, power = 0.8)$d, tolerance = 0.001)
})
test_that("default n comes from plan and grid expands", {
  p <- plan_study(effect = 0.5)
  expect_identical(nrow(sensitivity(p)), 3L)
  expect_true(all(sensitivity(p)$n_recruited == 64L))
  expect_identical(nrow(sensitivity(p, n = c(50, 100))), 6L)
})
test_that("corrections reduce effective n", {
  s <- sensitivity(plan_study(effect = 0.5, dropout = 0.1, deff = 1.5), n = 100, power = 0.8)
  expect_identical(s$n_effective, 60)
})
test_that("too small n errors before reaching the engine", {
  p <- plan_study(effect = 0.5, dropout = 0.5)
  expect_error(sensitivity(p, n = 3), "n = 3")
  expect_error(sensitivity(p, n = 0), "\x27n\x27")
  expect_error(sensitivity(list(), n = 10), "plan")
})
test_that("bad n and power are rejected with readable errors", {
  p <- plan_study(effect = 0.5)
  expect_error(sensitivity(p, n = NA_real_), "'n'")
  expect_error(sensitivity(p, n = c(10, Inf)), "'n'")
  expect_error(sensitivity(p, n = "a"), "'n'")
  expect_error(sensitivity(p, n = 1, power = 0.8), "n = 1")
  expect_error(sensitivity(p, power = c(0.8, 1)), "'power'")
})
test_that("n_effective below 3 gives readable error, 3 works", {
  p <- plan_study(effect = 0.5)
  expect_error(sensitivity(p, n = 2, power = 0.8), "n = 2")
  expect_error(sensitivity(p, n = 2.5, power = 0.8), "n = 2.5")
  expect_true(is.numeric(sensitivity(p, n = 3, power = 0.8)$mde))
})
test_that("infeasible design gives the readable message", {
  e <- tryCatch(sensitivity(plan_study(effect = 0.5, alpha = 0.001), n = 3, power = 0.99),
    error = function(e) conditionMessage(e))
  expect_identical(e, msg("err_infeasible"))
})

test_that("n_effective floating point tolerance", {
  expect_identical(sensitivity(plan_study(effect = 0.5, dropout = 0.35), n = 100, power = 0.8)$n_effective, 65)
  expect_identical(sensitivity(plan_study(effect = 0.5, dropout = 0.34), n = 50, power = 0.8)$n_effective, 33)
})
test_that("sensitivity checks power range, power above alpha and missing plan", {
  p <- plan_study(effect = 0.5)
  for (l in c("en", "tr")) {
    withr::local_options(plansize.lang = l)
    for (pw in list(0.995, 0.005, c(0.8, 0.995))) {
      e <- tryCatch(sensitivity(p, n = 64, power = pw), error = conditionMessage)
      expect_match(e, "power", fixed = TRUE)
      expect_false(grepl("does not have a valid", e, fixed = TRUE))
    }
    expect_error(sensitivity(p, n = 64, power = 0.03), msg("err_power_alpha"), fixed = TRUE)
    expect_error(sensitivity(), "plan")
  }
})

