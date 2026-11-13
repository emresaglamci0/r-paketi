#' Plan a study's sample size
#'
#' Computes the analytic n for an independent two-sample t test, a paired
#' (repeated-measures) t test, the overall F test of a one-way ANOVA with k
#' equal groups, a comparison of two independent proportions (pooled-SE z test) or a Pearson correlation (Fisher z test of H0: rho = 0),
#' then applies the design effect and dropout
#' correction with one final ceiling.
#'
#' @param test `"t_independent"` (default), `"t_paired"`, `"anova_oneway"`, `"prop_two"` or `"cor_pearson"`.
#' @param effect Effect size, a single number: positive for the t tests and ANOVA; not used with `"prop_two"`;
#'   for `"cor_pearson"` the expected Pearson r, between -1 and 1 and not 0 (its sign sets the
#'   direction of a one-sided test). Cohen's d for the t tests; for
#'   "anova_oneway", Cohen's f or eta squared as set by effect_type. For
#'   `"t_paired"`, d is the mean change divided by the SD of one measurement (pre and
#'   post SDs assumed equal), not by the SD of the difference scores; do not enter a dz here.
#' @param r Only for `"t_paired"`: the correlation between the two repeated measurements,
#'   strictly between -1 and 1 (d is converted to dz = d / sqrt(2 * (1 - r))). An error
#'   for the other tests. For `"cor_pearson"`, give the expected correlation as `effect`, not as `r`.
#' @param k Number of equal-sized groups, a single whole number of at least 2.
#'   Required for `"anova_oneway"`; an error for the t tests.
#' @param effect_type `"f"` (default) or `"eta2"`: whether `effect` for
#'   `"anova_oneway"` is Cohen's f or eta squared (converted by f = sqrt(eta2 / (1 - eta2))).
#'   An error for the t tests. The F test has no direction, so `alternative`
#'   must not be set for `"anova_oneway"`.
#'   Use eta squared from a one-way design; partial eta squared from a design with other
#'   factors or covariates is not the same quantity.
#' @param p1,p2 Expected proportions in group 1 and group 2, each strictly between 0 and 1 and
#'   different. Required for `"prop_two"` (pooled-SE z test; the effect is the difference
#'   p1 - p2, so `effect` must not be given); an error for the other tests.
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
#' @details For "prop_two", pwrss returns an already rounded n, so the dropout and design effect correction is applied to that rounded n; the recruitment target can be a few participants higher than a single final rounding would give.
#'
#' For "cor_pearson", n uses the Fisher z approximation without the bias correction of pwr::pwr.r.test (about 1 participant higher), so results can differ slightly from pwr or G*Power; the approximation is rough below about 10 participants but errs on the safe side.
#' @return A list of class `plansize_plan`.
#' @export
plan_study <- function(test = "t_independent", effect, r = NULL, k = NULL,
                       p1 = NULL, p2 = NULL,
                       effect_type = c("f", "eta2"),
                       effect_basis = c("unknown", "prior_study", "pilot",
                                        "smallest_of_interest", "convention", "observed"),
                       effect_source = NULL, alpha = 0.05, power = 0.80,
                       alternative = c("two.sided", "one.sided"),
                       dropout = 0, deff = 1) {
  test <- check_choice(test, names(test_spec), "test", exact = TRUE)
  spec <- test_spec[[test]]
  given <- c(if (!missing(effect)) "effect", if (!missing(effect_type)) "effect_type",
             if (!missing(alternative)) "alternative", if (!is.null(p1)) "p1", if (!is.null(p2)) "p2")
  args <- list(r = r, k = k, effect_type = effect_type, p1 = p1, p2 = p2)
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
