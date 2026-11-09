test_that("plan prints the group size in both languages", {
  p <- plan_study(effect = 0.5)
  withr::with_options(list(plansize.lang = "en"), expect_output(print(p), "64"))
  withr::with_options(list(plansize.lang = "tr"),
    expect_output(print(p), "\u00d6rneklem"))
})
test_that("print returns invisibly", {
  p <- plan_study(effect = 0.5)
  capture.output(v1 <- withVisible(print(p)))
  capture.output(v2 <- withVisible(print(sensitivity(p))))
  expect_false(v1$visible)
  expect_false(v2$visible)
  expect_identical(v1$value, p)
})
test_that("sensitivity prints a table", {
  expect_output(print(sensitivity(plan_study(effect = 0.5))), "0[.][0-9]+")
})
test_that("effect source line appears only when given", {
  withr::local_options(plansize.lang = "en")
  expect_output(print(plan_study(effect = 0.5, effect_source = "Smith 2020")), "Smith 2020")
  expect_false(any(grepl("Smith", capture.output(print(plan_study(effect = 0.5))))))
})

test_that("print of a column subset works", {
  withr::local_options(plansize.lang = "en")
  s <- sensitivity(plan_study(effect = 0.5))
  out <- capture.output(print(s[, c("n_recruited", "mde")]))
  expect_false(any(grepl("NA", out)))
  expect_match(out[2], "Recruited per group")
})
