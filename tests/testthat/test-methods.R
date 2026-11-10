ver <- function() as.character(utils::packageVersion("plansize"))

test_that("full English paragraph for a basic plan", {
  p <- quiet_plan(effect = 0.5)
  expected <- paste0(
    "An a priori power analysis for an independent two-sample t test was conducted in R ",
    "with the plansize package (version ", ver(), "), using pwrss (version ",
    p$engine_version, "). The effect size used for planning was Cohen's d = 0.50. ",
    "The rationale for choosing this effect size was not specified. For a two-sided test with ",
    "alpha = .05 and power = .80, the required sample size was 64 participants ",
    "per group (128 in total).")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  expect_s3_class(write_methods(p, lang = "en"), "plansize_methods")
})
test_that("Turkish paragraph has the key phrases", {
  x <- unclass(write_methods(quiet_plan(effect = 0.5), lang = "tr"))
  expect_match(x, "a priori g\u00fc\u00e7 analiziyle", fixed = TRUE)
  expect_match(x, "Cohen d = 0.50", fixed = TRUE)
  expect_match(x, "Alfa = .05, g\u00fc\u00e7 = .80 ve iki y\u00f6nl\u00fc test", fixed = TRUE)
  expect_match(x, "grup ba\u015f\u0131na 64, toplamda 128", fixed = TRUE)
})
test_that("language comes from option and argument overrides", {
  p <- quiet_plan(effect = 0.5)
  withr::with_options(list(plansize.lang = "tr"), {
    expect_match(unclass(write_methods(p)), "belirlenmi\u015ftir", fixed = TRUE)
    expect_match(unclass(write_methods(p, lang = "en")), "was conducted", fixed = TRUE)
  })
  expect_error(write_methods(p, lang = "de"), "Unsupported language: de")
})
test_that("adjustment sentence matches the corrections", {
  no <- unclass(write_methods(quiet_plan(effect = 0.5), lang = "en"))
  expect_false(grepl("recruitment", no, fixed = TRUE))
  d <- unclass(write_methods(quiet_plan(effect = 0.5, dropout = 0.1), lang = "en"))
  expect_match(d, "dropout rate of 10%, the recruitment target was 71 participants per group (142 in total)", fixed = TRUE)
  expect_match(d, "required sample size was 64 participants", fixed = TRUE)
  f <- unclass(write_methods(quiet_plan(effect = 0.5, deff = 1.5), lang = "en"))
  expect_match(f, "design effect of 1.5, the recruitment target was 96 participants per group (192 in total)", fixed = TRUE)
  b <- unclass(write_methods(quiet_plan(effect = 0.5, dropout = 0.1, deff = 1.5), lang = "en"))
  expect_match(b, "dropout rate of 10% and a design effect of 1.5, the recruitment target was 107", fixed = TRUE)
})
test_that("number formats follow the rules", {
  x <- unclass(write_methods(quiet_plan(effect = 1.25, alpha = 0.0001, power = 0.85, alternative = "one.sided", dropout = 0.125), lang = "en"))
  expect_match(x, "d = 1.25", fixed = TRUE)
  expect_match(x, "one-sided test", fixed = TRUE)
  expect_match(x, "alpha = .0001 and power = .85", fixed = TRUE)
  expect_match(x, "12.5%", fixed = TRUE)
  expect_match(unclass(write_methods(quiet_plan(effect = 0.125), lang = "en")), "d = 0.125", fixed = TRUE)
})
test_that("effect source is verbatim and optional", {
  s <- unclass(write_methods(quiet_plan(effect = 0.5, effect_source = "Yilmaz 100% 2021"), lang = "en"))
  expect_match(s, "d = 0.50 (Yilmaz 100% 2021).", fixed = TRUE)
  n <- unclass(write_methods(quiet_plan(effect = 0.5), lang = "en"))
  expect_false(grepl("()", n, fixed = TRUE))
})
test_that("every effect basis has a sentence in both languages", {
  for (b in c("unknown", "prior_study", "pilot", "smallest_of_interest", "convention")) {
    expect_true(nzchar(msg(paste0("m_basis_", b), lang = "en")))
    expect_true(nzchar(msg(paste0("m_basis_", b), lang = "tr")))
  }
  expect_match(unclass(write_methods(quiet_plan(effect = 0.5, effect_basis = "pilot"), lang = "en")), "pilot study", fixed = TRUE)
})
test_that("invalid plan and missing plan are readable", {
  expect_error(write_methods(list()), "plan")
  expect_error(write_methods(), "plan")
})
test_that("print writes plain text and returns invisibly", {
  x <- write_methods(quiet_plan(effect = 0.5), lang = "tr")
  out <- capture.output(v <- withVisible(print(x)))
  expect_false(v$visible)
  expect_false(any(grepl("[1]", out, fixed = TRUE)))
  expect_false(any(grepl("\"", out, fixed = TRUE)))
})
test_that("blank effect source gives no parentheses", {
  for (s in c("", "   ")) {
    x <- unclass(write_methods(quiet_plan(effect = 0.5, effect_source = s), lang = "en"))
    expect_false(grepl("()", x, fixed = TRUE))
    expect_false(grepl("( ", x, fixed = TRUE))
    expect_match(x, "d = 0.50.", fixed = TRUE)
  }
})
test_that("numbers do not depend on global options", {
  withr::with_options(list(OutDec = ",", digits = 3, scipen = -5), {
    p <- quiet_plan(effect = 0.5, dropout = 0.125)
    x <- unclass(write_methods(p, lang = "en"))
    expect_match(x, "d = 0.50", fixed = TRUE)
    expect_match(x, "alpha = .05", fixed = TRUE)
    expect_match(x, "12.5%", fixed = TRUE)
    big <- unclass(write_methods(quiet_plan(effect = 0.5, deff = 1e5), lang = "en"))
    expect_match(big, "design effect of 100000,", fixed = TRUE)
    expect_false(grepl("e+", big, fixed = TRUE))
  })
})
test_that("Turkish adjustment, source, side and print", {
  d <- unclass(write_methods(quiet_plan(effect = 0.5, dropout = 0.1,
                                        effect_source = "Yilmaz, 2021"), lang = "tr"))
  expect_match(d, "%10", fixed = TRUE)
  expect_match(d, "grup ba\u015f\u0131na 71, toplamda 142", fixed = TRUE)
  expect_match(d, "(Yilmaz, 2021).", fixed = TRUE)
  o <- unclass(write_methods(quiet_plan(effect = 0.5, alternative = "one.sided"), lang = "tr"))
  expect_match(o, "tek y\u00f6nl\u00fc test", fixed = TRUE)
  out <- capture.output(print(write_methods(quiet_plan(effect = 0.5), lang = "tr")))
  expect_true(any(grepl("g\u00fc\u00e7", out, fixed = TRUE)))
})
test_that("each effect basis sentence appears in the paragraph", {
  for (b in c("unknown", "prior_study", "pilot", "smallest_of_interest", "convention")) {
    for (l in c("en", "tr")) {
      x <- unclass(write_methods(quiet_plan(effect = 0.5, effect_basis = b), lang = l))
      expect_match(x, msg(paste0("m_basis_", b), lang = l), fixed = TRUE)
    }
  }
})
test_that("large n prints without scientific notation", {
  x <- unclass(write_methods(quiet_plan(effect = 0.01), lang = "en"))
  expect_false(grepl("e+", x, fixed = TRUE))
  expect_match(x, "participants per group", fixed = TRUE)
})
