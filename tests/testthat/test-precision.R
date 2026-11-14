# Sources: spec section 6-7 (z = 1.96: n0 384.16 -> 385; N 1000, deff 1.5, dropout .1 -> 463);
# cochranSize 0.1.0 vignette (N 1000 -> 277.7335; N 2000 -> 323; N 500, p .3, e .03, 99% -> 379).
# The 3 x 3 n0 grid is the plan's own table (formula consistency only, no independent package).
pp <- function(...) plan_precision(...)

test_that("n0 grid and finite-population n match the sources", {
  grid <- list("0.9" = c(271, 752, 6764), "0.95" = c(385, 1068, 9604), "0.99" = c(664, 1844, 16588))
  for (cl in names(grid)) for (i in 1:3) {
    x <- pp(e = c(0.05, 0.03, 0.01)[i], conf_level = as.numeric(cl))
    expect_identical(x$n_required, as.integer(grid[[cl]][i]))
  }
  x <- pp(e = 0.05)
  expect_equal(x$n0, 384.16, tolerance = 1e-3)  # spec, z = 1.96
  expect_equal(x$n0, 384.1459, tolerance = 1e-6)
  expect_identical(x$n_required, 385L)
  expect_s3_class(x, "plansize_precision")
  expect_false(inherits(x, "plansize_plan"))
  expect_equal(pp(e = 0.05, N = 1000)$n_analytic, 277.7335, tolerance = 1e-5)
  expect_identical(pp(e = 0.05, N = 2000)$n_required, 323L)
  expect_identical(pp(p = 0.3, e = 0.03, conf_level = 0.99, N = 500)$n_required, 379L)
})

test_that("corrections apply in spec order with one final rounding", {
  x <- pp(e = 0.05, N = 1000, deff = 1.5, dropout = 0.1)
  expect_identical(x$n_required, 463L)
  expect_equal(x$n_analytic, 277.74, tolerance = 1e-3)
  # spec intermediates (documentation only): 277.74, 416.60, 462.89
  expect_false(x$n_required %in% c(391L, 407L, 464L))  # wrong orders / intermediate rounding
  expect_identical(round_up(400 * 1.1), 440)
})

test_that("invalid input gives the documented errors", {
  e <- function(key, ...) msg(key, ...)
  expect_error(pp(e = 0.5), e("err_precision_e"), fixed = TRUE)
  expect_error(pp(p = 0, e = 0.05), e("err_probability", "p"), fixed = TRUE)
  expect_error(pp(p = 1, e = 0.05), e("err_probability", "p"), fixed = TRUE)
  expect_error(pp(e = 0.05, N = 1), e("err_precision_N", "N"), fixed = TRUE)
  expect_error(pp(e = 0.05, N = 100.5), e("err_precision_N", "N"), fixed = TRUE)
  expect_error(pp(e = 0.05, conf_level = 1), e("err_probability", "conf_level"), fixed = TRUE)
  expect_error(pp(e = 0.05, deff = 0.9), e("err_deff", "deff"), fixed = TRUE)
  expect_error(pp(e = 0.05, dropout = 1), e("err_dropout", "dropout"), fixed = TRUE)
  expect_error(pp(), e("err_missing", "e"), fixed = TRUE)
  expect_error(pp(e = 1e-7), e("err_precision_big"), fixed = TRUE)
  withr::local_options(plansize.lang = "tr")
  expect_error(pp(e = 0.5), msg("err_precision_e", lang = "tr"), fixed = TRUE)
  expect_error(pp(e = 1e-7), msg("err_precision_big", lang = "tr"), fixed = TRUE)
})

test_that("a plan larger than N warns", {
  expect_warning(pp(e = 0.05, N = 20, dropout = 0.3), msg("warn_precision_N", "28", "20"), fixed = TRUE,
                 class = "plansize_precision_warning")
  expect_no_warning(pp(e = 0.05, N = 20))
  expect_identical(suppressWarnings(pp(e = 0.05, N = 20, dropout = 0.3))$n_required, 28L)
})

test_that("precision plans are refused by sensitivity and bad classes by check_plan", {
  expect_error(sensitivity(pp(e = 0.05)), "plan_study()", fixed = TRUE)
  expect_error(sensitivity(pp(e = 0.05)), msg("err_precision_plan"), fixed = TRUE)
  bad <- structure(list(), class = "something")
  expect_error(sensitivity(bad), msg("err_plan", "plan"), fixed = TRUE)
  expect_s3_class(sensitivity(quiet_plan(effect = 0.5)), "plansize_sensitivity")
})

test_that("write_methods writes the precision paragraph", {
  x <- pp(e = 0.05, N = 1000, deff = 1.5, dropout = 0.1)
  en <- as.character(unclass(write_methods(x, lang = "en")))
  tr <- as.character(unclass(write_methods(x, lang = "tr")))
  expect_match(en, "463", fixed = TRUE)
  expect_match(en, "10%", fixed = TRUE)
  expect_match(tr, "463", fixed = TRUE)
  expect_match(tr, "%10", fixed = TRUE)
  expect_match(tr, "Cochran", fixed = TRUE)
  expect_false(grepl("))", en, fixed = TRUE))
  expect_lte(paren_depth(en), 1)
  expect_lte(paren_depth(tr), 1)
  expect_match(as.character(unclass(write_methods(pp(e = 0.05), lang = "tr"))), "385", fixed = TRUE)
  expect_match(unclass(write_methods(quiet_plan(effect = 0.5), lang = "en")), "pwrss", fixed = TRUE)
})

test_that("print shows the plan in both languages and ignores OutDec", {
  x <- pp(e = 0.05, N = 1000, deff = 1.5, dropout = 0.1)
  expect_output(print(x), "463", fixed = TRUE)
  expect_output(print(x), msg("prec_title"), fixed = TRUE)
  withr::local_options(plansize.lang = "tr", OutDec = ",")
  expect_output(print(x), msg("prec_title", lang = "tr"), fixed = TRUE)
  expect_output(print(x), "0.05", fixed = TRUE)
  expect_output(print(x), "463", fixed = TRUE)
})

test_that("equality of e and min(p, 1 - p) is an error despite floating point", {
  expect_error(pp(p = 0.7, e = 0.3), msg("err_precision_e"), fixed = TRUE)
})

test_that("hand-edited precision plans are rejected by print and write_methods", {
  x <- pp(e = 0.05, N = 1000)
  x$N <- "x"
  bad <- structure(list(), class = "plansize_precision")
  for (b in list(x, bad)) {
    expect_error(print(b), msg("err_precision_obj", "plan"), fixed = TRUE)
    expect_error(write_methods(b), msg("err_precision_obj", "plan"), fixed = TRUE)
  }
})
