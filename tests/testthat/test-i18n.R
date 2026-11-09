test_that("default language is en", {
  withr::with_options(list(plansize.lang = NULL), expect_identical(resolve_lang(), "en"))
})
test_that("option selects tr and argument overrides option", {
  withr::with_options(list(plansize.lang = "tr"), {
    expect_identical(resolve_lang(), "tr")
    expect_identical(resolve_lang("en"), "en")
  })
})
test_that("invalid language errors", {
  expect_error(resolve_lang("de"), "de")
})
test_that("Turkish characters survive", {
  expect_identical(msg("probe", lang = "tr"), "\u00d6rneklem \u015f\u0131\u011f")
})
test_that("placeholders are filled", {
  expect_identical(msg("probe_n", 64, lang = "en"), "n = 64")
})
test_that("unknown key errors", {
  expect_error(msg("no_such_key"), "no_such_key")
})
test_that("every row has both languages", {
  x <- read_messages()
  expect_true(all(nzchar(x$en) & nzchar(x$tr)))
  expect_false(anyDuplicated(x$key) > 0)
})
