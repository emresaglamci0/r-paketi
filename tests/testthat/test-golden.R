# Output of the original three tests must not change when internals are refactored.
test_that("plans, prints and methods text match the golden file", {
  gold <- readRDS(test_path("fixtures", "golden.rds"))
  now <- golden_build()
  expect_identical(names(now$plans), names(gold$plans))
  for (nm in names(gold$plans)) {
    for (part in names(gold$plans[[nm]])) {
      expect_identical(now$plans[[nm]][[part]], gold$plans[[nm]][[part]], label = paste(nm, part))
    }
  }
})
test_that("error messages match the golden file", {
  gold <- readRDS(test_path("fixtures", "golden.rds"))
  # The list of valid tests is replaced by a placeholder, so new tests do not break this.
  now <- lapply(golden_errors(), golden_strip_tests)
  expect_identical(now, lapply(gold$errors, golden_strip_tests))
})
