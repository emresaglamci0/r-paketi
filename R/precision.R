#' Plan a sample size for estimating one proportion
#'
#' Sample size so that the confidence interval of one proportion has half-width
#' `e` (Cochran's normal-approximation formula, `n0 = z^2 p (1 - p) / e^2`).
#' Corrections are applied in this order, with one final rounding up: finite
#' population correction `n0 / (1 + (n0 - 1) / N)` (only if `N` is given), then
#' `* deff`, then `/ (1 - dropout)`. The order is a method decision from the
#' package design; no published source for putting the finite population
#' correction before the design effect was found. Applying the design effect
#' first would give a smaller n (407 instead of 463 for `e = .05`, `N = 1000`,
#' `deff = 1.5`, `dropout = .1`), so this order errs on the safe side. Some
#' sources use `n0 / (1 + n0 / N)`; before `deff` and `dropout` the difference is at most 1 participant.
#'
#' `p = 0.5` is the most conservative value (largest n). The Wald (normal)
#' approximation is weak when p is near 0 or 1 and when n is small: for p = .1
#' and n = 139 the true coverage of a nominal 95% interval is about .93, and
#' for p = .02 and n = 31 about .47. `e` is the half-width of the interval, not
#' the full width. Precision is not power: this plan does not test a
#' hypothesis, so [sensitivity()] does not accept it.
#'
#' @param p Expected proportion, strictly between 0 and 1. Default 0.5.
#' @param e Half-width of the confidence interval, above 0 and below
#'   `min(p, 1 - p)`. Required.
#' @param conf_level Confidence level, strictly between 0 and 1.
#' @param N Population size (a whole number, at least 2) or `NULL` for an
#'   infinite population. A warning is given if the plan exceeds `N`.
#' @param dropout Expected nonresponse or dropout proportion, in [0, 1).
#' @param deff Design effect, at least 1.
#' @return A list of class `plansize_precision`; `n_required` is the integer
#'   recruitment target.
#' @export
plan_precision <- function(p = 0.5, e, conf_level = 0.95, N = NULL, dropout = 0, deff = 1) {
  check_required(missing(e), "e")
  check_probability(p, "p")
  check_probability(conf_level, "conf_level")
  check_positive_number(e, "e")
  if (e >= min(p, 1 - p) - 1e-9) fail("err_precision_e")
  if (!is.null(N) && (!is_num1(N) || N < 2 || N != round(N))) fail("err_precision_N", "N")
  check_adjust(dropout, deff)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  n0 <- z^2 * p * (1 - p) / e^2
  n_an <- if (is.null(N)) n0 else n0 / (1 + (n0 - 1) / N)
  n_raw <- round_up(n_an * deff / (1 - dropout))
  if (n_raw > .Machine$integer.max) fail("err_precision_big")
  if (!is.null(N) && n_raw > N) {
    warning(structure(class = c("plansize_precision_warning", "warning", "condition"),
      list(message = msg("warn_precision_N", fmt_plain(n_raw), fmt_plain(N)), call = NULL)))
  }
  structure(list(p = p, e = e, conf_level = conf_level, z = z, N = N, n0 = n0,
                 n_analytic = n_an, n_required = as.integer(n_raw), dropout = dropout,
                 deff = deff, method = "cochran_wald"), class = "plansize_precision")
}

#' Print a precision plan
#'
#' @param x A `plansize_precision` from [plan_precision()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.plansize_precision <- function(x, ...) {
  check_precision_plan(x)
  cat(msg("prec_title"), "\n", msg("prec_n", fmt_plain(x$n_required)), "\n\n", sep = "")
  cat(msg("prec_p", fmt_plain(x$p)), "\n", msg("prec_e", fmt_plain(x$e)), "\n",
      msg("prec_conf", fmt_plain(100 * x$conf_level)), "\n", sep = "")
  if (!is.null(x$N)) cat(msg("prec_N", fmt_plain(x$N)), "\n", sep = "")
  cat(msg("plan_dropout", fmt_plain(100 * x$dropout)), "\n", msg("plan_deff", fmt_plain(x$deff)), "\n",
      msg("prec_method", msg(paste0("val_", x$method))), "\n", sep = "")
  invisible(x)
}

# Methods paragraph; keys are tried per language by msg(). No nested parentheses.
methods_precision <- function(x, lang) {
  check_precision_plan(x)
  m <- function(key, ...) msg(key, ..., lang = lang)
  parts <- c(m("m_precision_intro", as.character(utils::packageVersion("plansize"))),
    m("m_precision_result", fmt_prob(x$p), fmt_prob(x$e), fmt_plain(100 * x$conf_level),
      fmt_plain(round_up(x$n0))))
  if (!is.null(x$N)) parts <- c(parts, m("m_precision_fpc", fmt_plain(x$N), fmt_plain(round_up(x$n_analytic))))
  d <- c(dropout = x$dropout > 0, deff = x$deff > 1)
  if (any(d)) {
    args <- c(if (d[["dropout"]]) fmt_plain(100 * x$dropout), if (d[["deff"]]) fmt_plain(x$deff))
    key <- paste0("m_precision_adjust_", if (all(d)) "both" else names(d)[d])
    parts <- c(parts, do.call(m, as.list(c(key, args, fmt_plain(x$n_required)))))
  } else {
    parts <- c(parts, m("m_precision_final", fmt_plain(x$n_required)))
  }
  structure(paste(parts, collapse = " "), class = c("plansize_methods", "character"))
}
