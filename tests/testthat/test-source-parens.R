# Max parenthesis depth; a stray ")" at depth 0 counts as unbalanced too.
paren_depth <- function(x) {
  ch <- strsplit(x, "")[[1]]
  d <- 0L; mx <- 0L
  for (c1 in ch) {
    if (c1 == "(") d <- d + 1L else if (c1 == ")") d <- d - 1L
    if (d < 0L) return(Inf)
    mx <- max(mx, d)
  }
  if (d != 0L) Inf else mx
}

src_plans <- list(
  t_independent = function(s) quiet_plan(effect = 0.5, effect_source = s),
  anova_oneway = function(s) quiet_plan(test = "anova_oneway", effect = 0.25, k = 3, effect_source = s),
  chisq_indep = function(s) quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3, effect_source = s),
  reg_overall_f2 = function(s) quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2",
                                          predictors = 3, effect_source = s),
  reg_partial_f2 = function(s) quiet_plan(test = "reg_partial", effect = 0.15, effect_type = "f2",
                                          predictors = 5, tested = 2, effect_source = s)
)

test_that("source parentheses never nest in the methods text", {
  for (nm in names(src_plans)) for (s in c("Yilmaz (2021)", "A (B (C))")) for (lg in c("en", "tr")) {
    x <- as.character(unclass(write_methods(src_plans[[nm]](s), lang = lg)))
    info <- paste(nm, s, lg)
    expect_lte(paren_depth(x), 1, label = info)
  }
})
test_that("source parentheses become square brackets in the methods text only", {
  p <- quiet_plan(effect = 0.5, effect_source = "Yilmaz (2021)")
  expect_match(unclass(write_methods(p, lang = "en")), "d = 0.50 (Yilmaz [2021]).", fixed = TRUE)
  expect_match(unclass(write_methods(quiet_plan(effect = 0.5, effect_source = "A (B (C))"), lang = "en")),
               "(A [B [C]])", fixed = TRUE)
  expect_identical(p$effect_source, "Yilmaz (2021)")
  expect_output(print(p), "Yilmaz (2021)", fixed = TRUE)
})
