#' Print a sample size plan
#'
#' @param x A `plansize_plan` from [plan_study()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.plansize_plan <- function(x, ...) {
  check_plan(x)
  cat(msg("plan_title"), "\n", sep = "")
  cat(msg_for("plan_n_group", x$test, x$n_per_group), "\n")
  if (x$groups > 1L) cat(msg("plan_n_total", x$n_total), "\n")
  cat("\n")
  cat(msg("plan_test", msg(paste0("val_", x$test))), "\n")
  anova <- test_spec[[x$test]]$design == "anova"
  eta2 <- anova && x$effect_type == "eta2"
  if (anova) cat(msg("plan_k", x$k), "\n")
  cat(msg_for("plan_effect", if (eta2) c(paste0(x$test, "_eta2"), x$test) else x$test,
              if (anova) fmt_num(x$effect) else format(x$effect)), "\n")
  if (eta2) cat(msg("plan_f", fmt_num(round(x$effect_test, 2))), "\n")
  if (test_spec[[x$test]]$design == "paired") {
    cat(msg("plan_r", format(x$r)), "\n")
    cat(msg("plan_dz", fmt_num(round(x$effect_test, 2))), "\n")
  }
  cat(msg("plan_basis", msg(paste0("val_", x$effect_basis))), "\n")
  if (!is.null(x$effect_source)) cat(msg("plan_source", x$effect_source), "\n")
  cat(msg("plan_alpha", format(x$alpha)), "\n")
  cat(msg("plan_power", format(x$power)), "\n")
  if (!anova) cat(msg("plan_alt", msg(paste0("val_", x$alternative))), "\n")
  cat(msg("plan_dropout", format(100 * x$dropout)), "\n")
  cat(msg("plan_deff", format(x$deff)), "\n")
  cat(msg("plan_method", x$method, x$engine_version), "\n")
  if (anova) cat("\n", msg_for("plan_note", x$test), "\n", sep = "")
  invisible(x)
}

#' Print a sensitivity table
#'
#' @param x A `plansize_sensitivity` from [sensitivity()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.plansize_sensitivity <- function(x, ...) {
  test <- attr(x, "test")
  if (identical(attr(x, "effect_type"), "eta2")) test <- c(paste0(test, "_eta2"), test)
  d <- as.data.frame(unclass(x))
  if ("mde" %in% names(d)) d$mde <- round(d$mde, 3)
  known <- names(d) %in% c("n_recruited", "n_effective", "power", "mde")
  names(d)[known] <- vapply(names(d)[known], function(k) msg_for(paste0("col_", k), test), "")
  cat(msg_for("sens_title", test), "\n", sep = "")
  print(d, row.names = FALSE)
  invisible(x)
}
