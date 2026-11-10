#' Plan a study's sample size
#'
#' Computes the analytic n for an independent two-sample t test, a paired
#' (repeated-measures) t test or the overall F test of a one-way ANOVA with k
#' equal groups, then applies the design effect and dropout
#' correction with one final ceiling.
#'
#' @param test `"t_independent"` (default), `"t_paired"` or `"anova_oneway"`.
#' @param effect Standardized effect, a positive single number: Cohen's d for the t tests; for
#'   "anova_oneway", Cohen's f or eta squared as set by effect_type. For
#'   `"t_paired"`, d is the mean change divided by the SD of one measurement (pre and
#'   post SDs assumed equal), not by the SD of the difference scores; do not enter a dz here.
#' @param r Correlation between the two repeated measures, strictly between -1 and 1.
#'   Required for `"t_paired"` (d is converted to dz = d / sqrt(2 * (1 - r))); an error
#'   for `"t_independent"`.
#' @param k Number of equal-sized groups, a single whole number of at least 2.
#'   Required for `"anova_oneway"`; an error for the t tests.
#' @param effect_type `"f"` (default) or `"eta2"`: whether `effect` for
#'   `"anova_oneway"` is Cohen's f or eta squared (converted by f = sqrt(eta2 / (1 - eta2))).
#'   An error for the t tests. The F test has no direction, so `alternative`
#'   must not be set for `"anova_oneway"`.
#'   Use eta squared from a one-way design; partial eta squared from a design with other
#'   factors or covariates is not the same quantity.
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
plan_study <- function(test = "t_independent", effect, r = NULL, k = NULL,
                       effect_type = c("f", "eta2"),
                       effect_basis = c("unknown", "prior_study", "pilot",
                                        "smallest_of_interest", "convention", "observed"),
                       effect_source = NULL, alpha = 0.05, power = 0.80,
                       alternative = c("two.sided", "one.sided"),
                       dropout = 0, deff = 1) {
  check_required(missing(effect), "effect")
  test <- check_choice(test, names(test_spec), "test", exact = TRUE)
  spec <- test_spec[[test]]
  anova <- spec$design == "anova"
  if (!anova && !is.null(k)) fail("err_k_unused")
  if (!anova && !missing(effect_type)) fail("err_effect_type_unused")
  if (anova) {
    if (!is_num1(k) || k < 2 || k != round(k) || k > .Machine$integer.max) fail("err_k")
    k <- as.integer(k)
    effect_type <- check_choice(effect_type, eval(formals()$effect_type), "effect_type")
    if (effect_type == "eta2") {
      if (!is_num1(effect) || effect <= 0 || effect >= 1) fail("err_eta2")
    } else {
      check_positive_number(effect, "effect")
    }
    if (!missing(alternative)) fail("err_alt_anova")
  } else {
    check_positive_number(effect, "effect")
    effect_type <- NA_character_
  }
  if (spec$design == "paired") {
    check_required(is.null(r), "r")
    if (!is_num1(r) || r <= -1 || r >= 1) fail("err_r")
  } else if (!is.null(r)) {
    fail("err_r_unused")
  }
  effect_basis <- check_choice(effect_basis, eval(formals()$effect_basis), "effect_basis")
  if (effect_basis == "observed") fail("err_observed")
  alternative <- if (anova) NA_character_ else
    check_choice(alternative, eval(formals()$alternative), "alternative")
  if (!is.null(effect_source) && !(is.character(effect_source) &&
      length(effect_source) == 1L && !is.na(effect_source))) {
    fail("err_effect_source", "effect_source")
  }
  check_probability(alpha, "alpha")
  check_power(power, alpha)
  if (!is_num1(dropout) || dropout < 0 || dropout >= 1) fail("err_dropout", "dropout")
  if (!is_num1(deff) || deff < 1) fail("err_deff", "deff")

  groups <- if (anova) k else spec$groups
  effect_test <- if (spec$design == "paired") effect / sqrt(2 * (1 - r)) else
    if (anova && effect_type == "eta2") sqrt(effect / (1 - effect)) else effect
  e <- engine_n(effect_test, alpha, power, alternative, spec$design, k)
  n_raw <- ceiling(e$n * deff / (1 - dropout))
  if (groups * n_raw > .Machine$integer.max) fail("err_overflow")
  n_group <- as.integer(n_raw)
  warn_basis(effect_basis)
  structure(list(
    test = test, effect = effect, effect_type = effect_type,
    k = if (anova) k else NA_integer_, r = r, effect_test = effect_test, effect_basis = effect_basis,
    effect_source = effect_source, alpha = alpha, power = power,
    alternative = alternative, dropout = dropout, deff = deff,
    n_analytic = e$n, n_per_group = n_group, n_total = groups * n_group, groups = groups,
    method = e$method, engine_version = as.character(utils::packageVersion("pwrss"))
  ), class = "plansize_plan")
}
