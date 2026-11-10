#' Plan a study's sample size
#'
#' Computes the analytic n for an independent two-sample t test or a paired
#' (repeated-measures) t test, then applies the design effect and dropout
#' correction with one final ceiling.
#'
#' @param test `"t_independent"` (default) or `"t_paired"`.
#' @param effect Standardized effect (Cohen's d), positive single number. For
#'   `"t_paired"`, d is the mean change divided by the SD of one measurement (pre and
#'   post SDs assumed equal), not by the SD of the difference scores; do not enter a dz here.
#' @param r Correlation between the two repeated measures, strictly between -1 and 1.
#'   Required for `"t_paired"` (d is converted to dz = d / sqrt(2 * (1 - r))); an error
#'   for `"t_independent"`.
#' @param effect_basis Where the effect came from: "unknown" (default), "prior_study",
#'   "pilot", "smallest_of_interest", "convention" or "observed". "unknown" and
#'   "convention" give a warning of class `plansize_basis_warning`; "observed" is an
#'   error, use [sensitivity()] instead. The chosen basis is stated in the methods text.
#' @param effect_source Optional free-text source of the effect.
#' @param alpha Significance level, in (0, 1).
#' @param power Target power, from 0.01 to 0.99 and greater than alpha.
#' @param alternative `"two.sided"` or `"one.sided"`.
#' @param dropout Expected dropout proportion, in [0, 1).
#' @param deff Design effect, at least 1.
#' @return A list of class `plansize_plan`.
#' @export
plan_study <- function(test = "t_independent", effect, r = NULL,
                       effect_basis = c("unknown", "prior_study", "pilot",
                                        "smallest_of_interest", "convention", "observed"),
                       effect_source = NULL, alpha = 0.05, power = 0.80,
                       alternative = c("two.sided", "one.sided"),
                       dropout = 0, deff = 1) {
  check_required(missing(effect), "effect")
  test <- check_choice(test, names(test_spec), "test")
  spec <- test_spec[[test]]
  check_positive_number(effect, "effect")
  if (spec$design == "paired") {
    check_required(is.null(r), "r")
    if (!is_num1(r) || r <= -1 || r >= 1) fail("err_r")
  } else if (!is.null(r)) {
    fail("err_r_unused")
  }
  effect_basis <- check_choice(effect_basis, eval(formals()$effect_basis), "effect_basis")
  if (effect_basis == "observed") fail("err_observed")
  alternative <- check_choice(alternative, eval(formals()$alternative), "alternative")
  if (!is.null(effect_source) && !(is.character(effect_source) &&
      length(effect_source) == 1L && !is.na(effect_source))) {
    fail("err_effect_source", "effect_source")
  }
  check_probability(alpha, "alpha")
  check_power(power, alpha)
  if (!is_num1(dropout) || dropout < 0 || dropout >= 1) fail("err_dropout", "dropout")
  if (!is_num1(deff) || deff < 1) fail("err_deff", "deff")

  effect_test <- if (spec$design == "paired") effect / sqrt(2 * (1 - r)) else effect
  e <- engine_n(effect_test, alpha, power, alternative, spec$design)
  n_raw <- ceiling(e$n * deff / (1 - dropout))
  if (spec$groups * n_raw > .Machine$integer.max) fail("err_overflow")
  n_group <- as.integer(n_raw)
  warn_basis(effect_basis)
  structure(list(
    test = test, effect = effect, r = r, effect_test = effect_test, effect_basis = effect_basis,
    effect_source = effect_source, alpha = alpha, power = power,
    alternative = alternative, dropout = dropout, deff = deff,
    n_analytic = e$n, n_per_group = n_group, n_total = spec$groups * n_group, groups = spec$groups,
    method = e$method, engine_version = as.character(utils::packageVersion("pwrss"))
  ), class = "plansize_plan")
}
