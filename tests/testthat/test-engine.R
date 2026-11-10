test_that("pwrss output contract holds", {
  r <- pwrss::power.t.student(d = 0.5, power = 0.8, alpha = 0.05,
    alternative = "two.sided", design = "independent", ceil.n = FALSE, verbose = 0)
  expect_true(all(c("n", "power", "d") %in% names(r)))
  expect_length(r$n, 2)
})
test_that("engine_n matches independent references", {
  grid <- expand.grid(d = c(0.2, 0.5, 0.8), power = c(0.8, 0.9), alpha = c(0.05, 0.01))
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    n <- engine_n(g$d, g$alpha, g$power, "two.sided", "independent")$n
    ref <- stats::power.t.test(delta = g$d, sd = 1, sig.level = g$alpha, power = g$power)$n
    expect_lte(abs(n - ref), 1)
  }
  skip_if_not_installed("pwr")
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "two.sided", "independent")$n -
    pwr::pwr.t.test(d = 0.5, power = 0.8)$n), 1)
})
test_that("one sided matches reference", {
  ref <- stats::power.t.test(delta = 0.5, sd = 1, power = 0.8, alternative = "one.sided")$n
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "one.sided", "independent")$n - ref), 1)
})
test_that("engine_mde matches pwr", {
  skip_if_not_installed("pwr")
  expect_equal(engine_mde(64, 0.05, 0.8, "two.sided", "independent"),
    pwr::pwr.t.test(n = 64, power = 0.8)$d, tolerance = 0.001)
})

test_that("pwrss still signals infeasible designs with 'not feasible'", {
  expect_error(
    pwrss::power.t.student(d = NULL, n2 = 3, power = 0.99, alpha = 0.001,
      alternative = "two.sided", design = "independent", ceil.n = FALSE, verbose = 0),
    "not feasible")
})

test_that("engine_mde one sided matches pwr", {
  skip_if_not_installed("pwr")
  expect_equal(engine_mde(64, 0.05, 0.8, "one.sided", "independent"),
    pwr::pwr.t.test(n = 64, power = 0.8, alternative = "greater")$d, tolerance = 0.001)
})
