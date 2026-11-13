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
  # The invalid-test message lists the valid tests, so it gained prop_two in slice 6.
  now <- lapply(golden_errors(), sub, pattern = ", prop_two", replacement = "", fixed = TRUE)
  expect_identical(now, gold$errors)
})
