# Independent of global options (OutDec, digits, scipen).
fmt_num <- function(x) {
  format(x, nsmall = 2, scientific = FALSE, trim = TRUE, decimal.mark = ".", digits = 7)
}

fmt_plain <- function(x) {
  format(x, scientific = FALSE, trim = TRUE, decimal.mark = ".", digits = 7)
}

# APA style: no leading zero for values bounded by 1.
fmt_prob <- function(x) sub("^(-?)0[.]", "\\1.", fmt_num(x))

#' Write a methods paragraph
#'
#' Turns a plan into a copyable methods paragraph in English or Turkish.
#'
#' The paragraph is valid only for a plan made before data collection.
#'
#' @param plan A `plansize_plan` from [plan_study()].
#' @param lang `"en"` or `"tr"`. Defaults to the `plansize.lang` option, then `"en"`.
#' @return A single string of class `plansize_methods`.
#' @export
write_methods <- function(plan, lang = NULL) {
  check_required(missing(plan), "plan")
  check_plan(plan)
  lang <- resolve_lang(lang)
  has_src <- !is.null(plan$effect_source) && nzchar(trimws(plan$effect_source))
  # APA: parentheses inside parentheses become square brackets (method text only).
  src <- if (has_src) paste0(" (", chartr("()", "[]", plan$effect_source), ")") else ""
  n_req <- as.integer(ceiling(plan$n_analytic))
  spec <- test_spec[[plan$test]]
  # Text keys are tried as <base>_<variant>, then <base>.
  variant <- spec$variant(plan)
  # Total counts are quoted only when there is more than one group.
  tot <- function(n_group, n_all) if (plan$groups > 1L) c(n_group, n_all) else n_group
  parts <- c(
    msg_for("m_intro", plan$test, msg(paste0("val_", plan$test), lang = lang),
        as.character(utils::packageVersion("plansize")), plan$engine_version, lang = lang),
    spec$effect_sentence(plan, src, lang),
    msg(paste0("m_basis_", plan$effect_basis), lang = lang),
    do.call(msg_for, c(list("m_result", variant),
        if (spec$directional) list(msg(paste0("val_", plan$alternative), lang = lang)),
        list(fmt_prob(plan$alpha), fmt_prob(plan$power)),
        as.list(tot(n_req, plan$groups * n_req)), list(lang = lang)))
  )
  drop <- fmt_plain(100 * plan$dropout)
  deff <- fmt_plain(plan$deff)
  has_d <- plan$dropout > 0
  has_f <- plan$deff > 1
  if (has_d && has_f) {
    parts <- c(parts, do.call(msg_for, c(list("m_adjust_both", variant, drop, deff),
      as.list(tot(plan$n_per_group, plan$n_total)), list(lang = lang))))
  } else if (has_d) {
    parts <- c(parts, do.call(msg_for, c(list("m_adjust_dropout", variant, drop),
      as.list(tot(plan$n_per_group, plan$n_total)), list(lang = lang))))
  } else if (has_f) {
    parts <- c(parts, do.call(msg_for, c(list("m_adjust_deff", variant, deff),
      as.list(tot(plan$n_per_group, plan$n_total)), list(lang = lang))))
  }
  parts <- c(parts, msg_for_opt("m_posthoc", plan$test, lang = lang))
  structure(paste(parts, collapse = " "), class = c("plansize_methods", "character"))
}

#' Print a methods paragraph
#'
#' @param x A `plansize_methods` from [write_methods()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.plansize_methods <- function(x, ...) {
  writeLines(unclass(x))
  invisible(x)
}
