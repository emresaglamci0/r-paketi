#' Plan a study's sample size
#'
#' Computes the analytic n for an independent two-sample t test, a paired
#' (repeated-measures) t test, the overall F test of a one-way ANOVA with k
#' equal groups, a comparison of two independent proportions (pooled-SE z test) or a Pearson correlation (Fisher z test of H0: rho = 0) or a chi-square test of independence (Cohen's w),
#' then applies the design effect and dropout
#' correction with one final ceiling.
#'
#' @param test `"t_independent"` (default), `"t_paired"`, `"anova_oneway"`, `"prop_two"`, `"cor_pearson"`, `"chisq_indep"`, `"reg_overall"` (overall F test of a multiple regression) or `"reg_partial"` (F test of the R squared change from a subset of the predictors).
#' @param effect Effect size, a single number: positive for the t tests and ANOVA; not used with `"prop_two"`;
#'   for `"cor_pearson"` the expected Pearson r, between -1 and 1 and not 0 (its sign sets the
#'   direction of a one-sided test); for `"chisq_indep"` Cohen's w, above 0 and at most 1 (the
#'   test has no direction, so `alternative` must not be set). Cohen's d for the t tests; for
#'   "anova_oneway", Cohen's f or eta squared as set by effect_type. For "reg_overall", R squared or Cohen f squared as set by effect_type; for "reg_partial", the R squared change or the partial Cohen f squared of the tested predictors, as set by effect_type. For
#'   `"t_paired"`, d is the mean change divided by the SD of one measurement (pre and
#'   post SDs assumed equal), not by the SD of the difference scores; do not enter a dz here.
#'   For "chisq_indep", w is not Cramer's V: for tables larger than 2 x 2, w = V * sqrt(min(rows, cols) - 1). w above 1 is possible when rows and cols are both at least 3, but pwrss does not support it.
#' @param r Only for `"t_paired"`: the correlation between the two repeated measurements,
#'   strictly between -1 and 1 (d is converted to dz = d / sqrt(2 * (1 - r))). An error
#'   for the other tests. For `"cor_pearson"`, give the expected correlation as `effect`, not as `r`.
#' @param k Number of equal-sized groups, a single whole number of at least 2.
#'   Required for `"anova_oneway"`; an error for the t tests.
#' @param effect_type For `"anova_oneway"`: `"f"` (default) or `"eta2"`, whether `effect`
#'   is Cohen's f or eta squared (converted by f = sqrt(eta2 / (1 - eta2))).
#'   The F test has no direction, so `alternative` must not be set for `"anova_oneway"`.
#'   Use eta squared from a one-way design; partial eta squared from a design with other
#'   factors or covariates is not the same quantity.
#'   For `"reg_overall"`: required, `"r2"` or `"f2"` (exact match, no default). `"r2"` is the
#'   R squared of the whole model (share of variance explained by all predictors together,
#'   intercept excluded), above 0 and at most 0.99; `"f2"` is Cohen's f squared = R2 / (1 - R2),
#'   above 0 and at most 99 (not the partial f squared of one predictor).
#'   Cohen's f squared benchmarks .02, .15 and .35 (small, medium, large) are not R squared
#'   values: as R squared they are .02, .13 and .26. Entering .15 as `"r2"` instead of `"f2"`
#'   gives a different plan without an error, so check which measure your source reports.
#'   Do not enter an adjusted R squared (papers label it "adjusted" or "R2adj"); use the
#'   plain R squared. An error for the other tests.
#'   For `"reg_partial"`: required, `"r2_change"` or `"f2"` (exact match, no default).
#'   `"r2_change"` is the increase in R squared (Delta R squared) when the tested predictors
#'   are added to the model with the other predictors (the covariates); `r2_covariates`, the
#'   R squared of the model without the tested predictors, is then required. `"f2"` is Cohen's
#'   f squared of the tested set = Delta R squared / (1 - R squared of the full model);
#'   `r2_covariates` must not be given because f squared already accounts for the covariates.
#'   pwrss is given the partial R squared = Delta R squared / (1 - `r2_covariates`) (equal to
#'   f2 / (1 + f2)), because the argument pwrss calls `r.squared.change` is used as f2 =
#'   r.squared.change / (1 - r.squared.change); entering Delta R squared directly would
#'   overstate n whenever the covariates explain variance.
#' @param predictors Number of predictors in the regression model, a single whole number from
#'   1 to 1000. Required for `"reg_overall"` and `"reg_partial"` (for `"reg_partial"` the total,
#'   tested predictors included); an error for the other tests. Count a
#'   categorical predictor by its dummy variables (a 4-level factor is 3 predictors).
#' @param tested Only for `"reg_partial"`: number of predictors tested together, a whole number
#'   from 1 to `predictors` - 1 (to test all predictors use `"reg_overall"`). With `tested = 1`
#'   the test equals the two-sided t test of one predictor. An error for the other tests.
#' @param r2_covariates Only for `"reg_partial"` with `effect_type = "r2_change"`: R squared of
#'   the model without the tested predictors, from 0 up to but not including 1, with
#'   `effect` + `r2_covariates` at most 0.99. An error for the other tests and for `"f2"`.
#'   It is not the R squared of the full model: with full-model R squared .30 and an R squared
#'   change of .10, enter `effect = 0.10, r2_covariates = 0.20`. Do not enter the partial R
#'   squared (.10 / (1 - .20) = .125) as `effect`; with `"r2_change"` that gives a smaller n.
#' @param p1,p2 Expected proportions in group 1 and group 2, each strictly between 0 and 1 and
#'   different. Required for `"prop_two"` (pooled-SE z test; the effect is the difference
#'   p1 - p2, so `effect` must not be given); an error for the other tests.
#' @param rows,cols Number of rows and columns of the contingency table, each a single whole number
#'   from 2 to 1000. Required for `"chisq_indep"` (df = (rows - 1) * (cols - 1)); an error for the other tests.
#' @param effect_basis Where the effect came from: "unknown" (default), "prior_study",
#'   "pilot", "smallest_of_interest", "convention" or "observed". "unknown" and
#'   "convention" give a warning of class `plansize_basis_warning`; "observed" is an
#'   error, use [sensitivity()] instead. The chosen basis is stated in the methods text.
#' @param effect_source Optional free-text source of the effect. In the methods text, parentheses inside it are shown as square brackets.
#' @param alpha Significance level, in (0, 1).
#' @param power Target power, from 0.01 to 0.99 and greater than alpha.
#' @param alternative `"two.sided"` or `"one.sided"`.
#' @param dropout Expected dropout proportion, in [0, 1).
#' @param deff Design effect, at least 1.
#' @details For `reg_overall`, print also shows the participants needed if predictors are random (Sampson's random model via DMAR). Measured predictors, as in most observational studies, are random, and recruiting that number keeps the target power. The line is absent when the suggested package DMAR is not installed, when the plan n is above 100,000, or when DMAR fails. The plan n and the methods text keep the fixed-predictor assumption.
#' @details For "prop_two", pwrss returns an already rounded n, so the dropout and design effect correction is applied to that rounded n; the recruitment target can be a few participants higher than a single final rounding would give.
#'
#' For "cor_pearson", n uses the Fisher z approximation without the bias correction of pwr::pwr.r.test (about 1 participant higher), so results can differ slightly from pwr or G*Power; the approximation is rough below about 10 participants but errs on the safe side.
#'
#' For "chisq_indep", n is for Pearson's chi-square test without continuity correction; in R use chisq.test(x, correct = FALSE) for 2 x 2 tables, as the default Yates correction lowers power.
#'
#' For "reg_overall", n is the total for the overall F test of a multiple regression (H0: R squared = 0), with `groups` 1. The F model treats the predictors as fixed; with random predictors the power is slightly lower (about 0.78 instead of 0.80 in a simulation with R2 = 0.13 and 3 predictors). Tests of single predictors are covered only through `"reg_partial"` with `tested = 1`.
#'
#' For "reg_partial", n is the total for the F test of the R squared change of `tested` of `predictors` predictors (H0: Delta R squared = 0), with `groups` 1. pwrss uses the noncentrality f squared * n (fixed predictors, as in G*Power's "R2 increase, fixed model"); this was checked against a fixed-design simulation. pwr::pwr.f2.test uses Cohen's f squared * (u + v + 1) instead, a different method that gives 0 to `predictors` - `tested` more participants; do not treat it as a reference for this test. The F model treats the predictors as fixed; with random predictors the power is lower (about 0.77 instead of 0.80 in a simulation, and lower still with a small n and a large R squared).
#' @return A list of class `plansize_plan`.
#' @export
plan_study <- function(test = "t_independent", effect, r = NULL, k = NULL,
                       p1 = NULL, p2 = NULL, rows = NULL, cols = NULL, predictors = NULL,
                       tested = NULL, r2_covariates = NULL,
                       effect_type = c("f", "eta2"),
                       effect_basis = c("unknown", "prior_study", "pilot",
                                        "smallest_of_interest", "convention", "observed"),
                       effect_source = NULL, alpha = 0.05, power = 0.80,
                       alternative = c("two.sided", "one.sided"),
                       dropout = 0, deff = 1) {
  test <- check_choice(test, names(test_spec), "test", exact = TRUE)
  spec <- test_spec[[test]]
  given <- c(if (!missing(effect)) "effect", if (!missing(effect_type)) "effect_type",
             if (!missing(alternative)) "alternative", if (!is.null(p1)) "p1", if (!is.null(p2)) "p2",
             if (!is.null(rows)) "rows", if (!is.null(cols)) "cols")
  args <- list(r = r, k = k, effect_type = effect_type, p1 = p1, p2 = p2, rows = rows, cols = cols,
               predictors = predictors, tested = tested, r2_covariates = r2_covariates)
  if (!missing(effect)) args$effect <- effect
  prep <- spec$prepare(args, given)
  effect_basis <- check_choice(effect_basis, eval(formals()$effect_basis), "effect_basis")
  if (effect_basis == "observed") fail("err_observed")
  alternative <- if (!spec$directional) NA_character_ else
    check_choice(alternative, eval(formals()$alternative), "alternative")
  if (!is.null(effect_source) && !(is.character(effect_source) &&
      length(effect_source) == 1L && !is.na(effect_source))) {
    fail("err_effect_source", "effect_source")
  }
  check_probability(alpha, "alpha")
  check_power(power, alpha)
  if (!is_num1(dropout) || dropout < 0 || dropout >= 1) fail("err_dropout", "dropout")
  if (!is_num1(deff) || deff < 1) fail("err_deff", "deff")

  groups <- spec$groups(prep$extra)
  n_analytic <- spec$n(c(prep$extra, list(effect_test = prep$effect_test, alpha = alpha,
                                          power = power, alternative = alternative)))
  n_raw <- ceiling(n_analytic * deff / (1 - dropout))
  if (groups * n_raw > .Machine$integer.max) fail("err_overflow")
  n_group <- as.integer(n_raw)
  warn_basis(effect_basis)
  structure(c(
    list(test = test, effect = prep$effect), prep$extra,
    list(effect_test = prep$effect_test, effect_basis = effect_basis,
      effect_source = effect_source, alpha = alpha, power = power,
      alternative = alternative, dropout = dropout, deff = deff,
      n_analytic = n_analytic, n_per_group = n_group, n_total = groups * n_group,
      groups = groups, method = spec$method,
      engine_version = as.character(utils::packageVersion("pwrss")))
  ), class = "plansize_plan")
}
