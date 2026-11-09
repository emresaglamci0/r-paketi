test_that("package namespace loads", {
  expect_true(requireNamespace("plansize", quietly = TRUE))
})
