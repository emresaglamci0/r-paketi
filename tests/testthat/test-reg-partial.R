# Same-method reference: pwr's noncentral F with f2 rescaled so lambda = f2 * n (pwrss uses lambda = f2 * n).
pwr_same <- function(n, k, u, f2, alpha = 0.05) {
  pwr::pwr.f2.test(u = u, v = n - k - 1, f2 = f2 * n / (n - k + u), sig.level = alpha)$power
}
# dR2, covariate R2, k, tested, plan n (checked against pwrss, fixed-design simulation and rescaled pwr)
partial_cases <- list(
  c(0.06, 0.20, 4, 1, 99), c(0.10, 0.20, 5, 2, 71), c(0.13, 0, 3, 1, 55),
  c(0.05, 0.10, 10, 1, 136), c(0.26, 0, 6, 3, 36), c(0.02, 0.30, 8, 2, 331))
q_part <- function(...) quiet_plan(test = "reg_partial", ...)
# Source-free variant of a reg_partial plan.
no_source <- function(plan) {
  if (identical(plan$effect_type, "f2")) {
    q_part(effect = plan$effect, effect_type = "f2", predictors = plan$predictors, tested = plan$tested)
  } else {
    q_part(effect = plan$effect, effect_type = "r2_change", r2_covariates = plan$r2_covariates,
           predictors = plan$predictors, tested = plan$tested)
  }
}

test_that("engine tested argument defaults to the overall test", {
  expect_equal(engine_n_reg(0.13, 3, 0.05, 0.8, tested = 3), engine_n_reg(0.13, 3, 0.05, 0.8))
  expect_equal(engine_n_reg(0.13, 3, 0.05, 0.8), 76.985, tolerance = 1e-5)
  expect_equal(engine_mde_reg(100, 5, 0.05, 0.8, tested = 5), engine_mde_reg(100, 5, 0.05, 0.8))
})
test_that("partial n matches the same-method pwr power at the integer boundary", {
  for (cs in partial_cases) {
    f2 <- cs[1] / (1 - cs[1] - cs[2]); k <- cs[3]; u <- cs[4]
    n <- ceiling(engine_n_reg(cs[1] / (1 - cs[2]), k, 0.05, 0.8, tested = u))
    expect_identical(n, cs[5])
    expect_gte(pwr_same(n, k, u, f2), 0.8)
    expect_lt(pwr_same(n - 1, k, u, f2), 0.8)
  }
})
test_that("plain pwr is a different method: larger by less than k - tested", {
  # pwr.f2.test uses lambda = f2 * (u + v + 1), pwrss uses f2 * n; not a +-1 reference.
  for (cs in partial_cases) {
    f2 <- cs[1] / (1 - cs[1] - cs[2])
    ref <- pwr::pwr.f2.test(u = cs[4], f2 = f2, power = 0.8)$v + cs[3] + 1
    d <- ref - engine_n_reg(cs[1] / (1 - cs[2]), cs[3], 0.05, 0.8, tested = cs[4])
    expect_gt(d, 0); expect_lt(d, cs[3] - cs[4])
  }
})
test_that("tested = 1 is the two-sided t test of one predictor", {
  tt <- pwrss::power.t.reg(beta = sqrt(0.06), k.total = 4, r.squared = 0.26, power = 0.8,
                           ceil.n = FALSE, verbose = 0)$n
  expect_equal(engine_n_reg(0.06 / 0.8, 4, 0.05, 0.8, tested = 1), tt, tolerance = 1e-6)
})
test_that("engine values for other alpha, power and f2", {
  expect_equal(engine_n_reg(0.10 / 0.8, 5, 0.01, 0.8, tested = 2), 101.9848, tolerance = 1e-5)
  expect_equal(engine_n_reg(0.10 / 0.8, 5, 0.05, 0.9, tested = 2), 91.7533, tolerance = 1e-5)
  expect_equal(engine_n_reg(0.15 / 1.15, 5, 0.05, 0.8, tested = 2), 67.4674, tolerance = 1e-5)
})

test_that("reg_partial plan", {
  p <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(71L, 71L, 1L))
  expect_equal(p$effect_test, 0.125)
  expect_identical(p$effect, 0.10)
  expect_identical(p$tested, 2L)
  expect_true(is.na(p$alternative))
  expect_identical(q_part(effect = 0.13, effect_type = "r2_change", r2_covariates = 0, predictors = 3,
                          tested = 1)$n_total, 55L)
  pf <- q_part(effect = 0.10 / 0.70, effect_type = "f2", predictors = 5, tested = 2)
  expect_identical(pf$n_total, 71L)
  expect_true(is.na(pf$r2_covariates))
  expect_identical(q_part(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2)$n_total, 68L)
  # 70.667 / 0.9 = 78.5 -> 79 (one ceiling, after dropout)
  expect_identical(q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20,
                          predictors = 5, tested = 2, dropout = 0.1)$n_total, 79L)
})
test_that("covariate R2 matters: same dR2, larger covariate R2 needs less n", {
  a <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0, predictors = 5, tested = 2)$n_total
  b <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2)$n_total
  expect_identical(a, 90L)  # pwrss 89.885
  expect_identical(b, 71L)
})
test_that("reg_partial arguments are validated", {
  ok <- list(test = "reg_partial", effect = 0.1, effect_type = "r2_change", r2_covariates = 0.2,
             predictors = 5, tested = 2)
  chk <- function(over, pat) expect_error(do.call(plan_study, utils::modifyList(ok, over)), pat, fixed = TRUE)
  for (b in list(0, -0.1, NA_real_, "a", c(0.1, 0.2))) chk(list(effect = b), "'effect'")
  for (b in list(0, -1, 100, NA_real_, "a")) {
    expect_error(plan_study(test = "reg_partial", effect = b, effect_type = "f2", predictors = 5, tested = 2),
                 "'effect'", fixed = TRUE)
  }
  # tested: required, whole number, 1 .. predictors - 1
  for (b in list(0, 1.5, NA_real_, -1, "a", c(1, 2), 5, 6)) chk(list(tested = b), "'tested'")
  expect_error(do.call(plan_study, utils::modifyList(ok, list(tested = NULL))), "'tested'", fixed = TRUE)
  # tested = predictors points to the overall test
  chk(list(tested = 5), "reg_overall")
  chk(list(predictors = 3, tested = 3), "reg_overall")
  # predictors
  for (b in list(0, 1.5, 1001, NA_real_, "a")) chk(list(predictors = b), "'predictors'")
  expect_error(do.call(plan_study, utils::modifyList(ok, list(predictors = NULL))), "'predictors'", fixed = TRUE)
  # r2_covariates: required with r2_change, 0 allowed, below 1, effect + r2_covariates <= 0.99
  for (b in list(1, -0.1, NA_real_, 0.95, "a")) chk(list(r2_covariates = b), "'r2_covariates'")
  expect_error(do.call(plan_study, utils::modifyList(ok, list(r2_covariates = NULL))), "'r2_covariates'", fixed = TRUE)
  expect_identical(do.call(quiet_plan, utils::modifyList(ok, list(r2_covariates = 0)))$n_total, 90L)
  # f2 with r2_covariates is an error (f2 already accounts for the covariates)
  chk(list(effect_type = "f2"), "'r2_covariates'")
  # effect_type: required, exact, length 1
  chk(list(effect_type = "r2"), "'effect_type'"); chk(list(effect_type = "f"), "'effect_type'")
  chk(list(effect_type = "r2_chang"), "'effect_type'"); chk(list(effect_type = NA_character_), "'effect_type'")
  chk(list(effect_type = NULL), "'effect_type'")
  chk(list(effect_type = c("r2_change", "f2")), "'effect_type'")  # must not pass via identical(x, choices)
  # argument rejection
  chk(list(alternative = "one.sided"), "alternative")
  chk(list(alternative = "two.sided"), "alternative")
  chk(list(k = 3), "'k'"); chk(list(rows = 2), "'rows'"); chk(list(r = 0.3), "'r'")
  expect_error(do.call(plan_study, utils::modifyList(ok, list(p1 = 0.4, p2 = 0.3))), "p1", fixed = TRUE)
})
test_that("other tests refuse tested and r2_covariates", {
  base <- list(
    list(test = "t_independent", effect = 0.5), list(test = "t_paired", effect = 0.5, r = 0.5),
    list(test = "anova_oneway", effect = 0.25, k = 3), list(test = "prop_two", p1 = 0.45, p2 = 0.30),
    list(test = "cor_pearson", effect = 0.3), list(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3),
    list(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3))
  for (a in base) for (extra in list(list(tested = 1), list(r2_covariates = 0.2), list(tested = 1, r2_covariates = 0.2)))
    expect_identical(tryCatch(do.call(plan_study, c(a, extra)), error = conditionMessage), msg("err_partial_unused"))
})
test_that("effect_type and predictors stay refused by the other tests", {
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, effect_type = "r2_change"), "'effect_type'", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2_change", predictors = 3), "'effect_type'", fixed = TRUE)
  expect_error(plan_study(test = "t_independent", effect = 0.5, effect_type = "r2_change"), "reg_partial", fixed = TRUE)
  expect_error(plan_study(test = "t_independent", effect = 0.5, predictors = 3), "reg_partial", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, predictors = 3), "reg_overall", fixed = TRUE)
})
test_that("reg_overall and anova behaviour is unchanged", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  expect_identical(p$n_total, 77L)
  expect_null(p[["tested"]])
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)$n_per_group, 53L)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, tested = 1),
               "'tested'", fixed = TRUE)
})
test_that("reg_partial sensitivity", {
  p <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2)
  s <- sensitivity(p, n = 100, power = 0.8)
  expect_equal(s$mde, 0.09048 * 0.8, tolerance = 1e-3)  # partial R2 .09048, back in dR2 units
  # power at the returned mde is the target (no flat-region artifact)
  expect_equal(pwrss::power.f.reg(r.squared.change = s$mde / 0.8, k.total = 5, k.tested = 2,
                                  n = 100, verbose = 0)$power, 0.8, tolerance = 1e-3)
  pf <- q_part(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2)
  expect_equal(sensitivity(pf, n = 100, power = 0.8)$mde, 0.09048 / (1 - 0.09048), tolerance = 1e-3)
  expect_identical(attr(sensitivity(pf), "effect_type"), "f2")
  expect_identical(tryCatch(sensitivity(p, n = 2), error = conditionMessage), msg("err_n_small", 2, 3))
})
test_that("near-impossible reg_partial designs give the readable error", {
  # pwrss "Design is not feasible.": n below k + 2 (f2 99) or above 1e10 (f2 1e-10)
  for (a in list(list(effect = 99, predictors = 2), list(effect = 1e-10, predictors = 1000)))
    expect_identical(tryCatch(do.call(plan_study, c(list(test = "reg_partial", effect_type = "f2", tested = 1), a)),
                              error = conditionMessage), msg("err_infeasible_plan_reg_partial"))
})
test_that("reg_partial methods and print", {
  p <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2,
              effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "R-squared change of 0.10 (Yilmaz, 2021)", fixed = TRUE)
  expect_match(x, "2 of 5 predictors", fixed = TRUE)
  expect_match(x, "R-squared = 0.20", fixed = TRUE)
  expect_match(x, "the required sample size was 71 participants in total.", fixed = TRUE)
  expect_match(x, "Predictors were treated as fixed", fixed = TRUE)
  expect_match(unclass(write_methods(p, lang = "tr")), "2 / 5 yorday\u0131c\u0131", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Tested predictors: 2 of 5; R-squared without them: 0.20", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
  expect_false(any(grepl("NA", out, fixed = TRUE)))
})
test_that("reg_partial f2 plan shows no NA and no covariate line", {
  pf <- q_part(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2, effect_source = "Pilot A")
  expect_match(unclass(write_methods(pf, lang = "en")), "Cohen's f-squared = 0.15 (Pilot A)", fixed = TRUE)
  for (lg in c("en", "tr")) {
    out <- withr::with_options(list(plansize.lang = lg), capture.output(print(pf)))
    expect_false(any(grepl("NA", out, fixed = TRUE)))
    expect_false(any(grepl("R-squared without", out, fixed = TRUE)))
    expect_false(grepl("NA", unclass(write_methods(pf, lang = lg)), fixed = TRUE))
  }
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(pf)))
  expect_true(any(grepl("Tested predictors: 2 of 5", out, fixed = TRUE)))
})
test_that("reg_partial methods have no double parentheses", {
  p <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2,
              effect_source = "Yilmaz, 2021")
  pf <- q_part(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2, effect_source = "Pilot A")
  for (pl in list(p, pf, no_source(p), no_source(pf))) for (lg in c("en", "tr")) {
    x <- unclass(write_methods(pl, lang = lg))
    expect_false(grepl("((", x, fixed = TRUE))
    expect_false(grepl("))", x, fixed = TRUE))
    expect_false(grepl(") (", x, fixed = TRUE))
  }
})
test_that("tampered reg_partial plans are refused", {
  p <- q_part(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2)
  pf <- q_part(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2)
  refused <- function(plan, bad) {
    q <- utils::modifyList(plan, bad); class(q) <- class(plan)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
  for (bad in list(list(tested = NULL), list(tested = 5L), list(tested = 0L), list(tested = 1.5),
                   list(effect_test = 0.5), list(r2_covariates = NULL), list(r2_covariates = 0.95),
                   list(predictors = NULL), list(effect_type = "r2"), list(effect_type = NA_character_)))
    refused(p, bad)
  for (bad in list(list(tested = NULL), list(tested = 5L), list(effect_test = 0.5)))
    refused(pf, bad)
})
