#' Plan a study's sample size
#'
#' Computes the analytic per-group n for an independent two-sample t test,
#' then applies the design effect and dropout correction with one final ceiling.
#'
#' @param test Test name. Only `"t_independent"` is supported.
#' @param effect Standardized effect (Cohen's d), positive single number.
#' @param effect_basis Where the effect came from.
#' @param effect_source Optional free-text source of the effect.
#' @param alpha Significance level, in (0, 1).
#' @param power Target power, from 0.01 to 0.99 and greater than alpha.
#' @param alternative `"two.sided"` or `"one.sided"`.
#' @param dropout Expected dropout proportion, in [0, 1).
#' @param deff Design effect, at least 1.
#' @return A list of class `plansize_plan`.
#' @export
plan_study <- function(test = "t_independent", effect,
                       effect_basis = c("unknown", "prior_study", "pilot",
                                        "smallest_of_interest", "convention", "observed"),
                       effect_source = NULL, alpha = 0.05, power = 0.80,
                       alternative = c("two.sided", "one.sided"),
                       dropout = 0, deff = 1) {
  check_required(missing(effect), "effect")
  if (!identical(test, "t_independent")) fail("err_test", format(test))
  check_positive_number(effect, "effect")
  effect_basis <- check_choice(effect_basis, eval(formals()$effect_basis), "effect_basis")
  alternative <- check_choice(alternative, eval(formals()$alternative), "alternative")
  if (!is.null(effect_source) && !(is.character(effect_source) &&
      length(effect_source) == 1L && !is.na(effect_source))) {
    fail("err_effect_source", "effect_source")
  }
  check_probability(alpha, "alpha")
  check_power(power, alpha)
  if (!is_num1(dropout) || dropout < 0 || dropout >= 1) fail("err_dropout", "dropout")
  if (!is_num1(deff) || deff < 1) fail("err_deff", "deff")

  e <- engine_n(effect, alpha, power, alternative)
  n_raw <- ceiling(e$n * deff / (1 - dropout))
  if (2 * n_raw > .Machine$integer.max) fail("err_overflow")
  n_group <- as.integer(n_raw)
  structure(list(
    test = test, effect = effect, effect_basis = effect_basis,
    effect_source = effect_source, alpha = alpha, power = power,
    alternative = alternative, dropout = dropout, deff = deff,
    n_analytic = e$n, n_per_group = n_group, n_total = 2L * n_group,
    method = e$method, engine_version = as.character(utils::packageVersion("pwrss"))
  ), class = "plansize_plan")
}
