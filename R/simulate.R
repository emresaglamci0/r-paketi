#' Check a plan's power by simulation
#'
#' Draws `reps` studies with the planned effect, runs the planned test on each and compares the
#' share of significant results (empirical power) with the analytic power pwrss gives for the same n.
#' This checks that the formula holds at this n under normal (or binomial) data and a correct effect;
#' it says nothing about real data and it is not the observed power.
#'
#' @param plan A `plansize_plan` for `"t_independent"`, `"t_paired"`, `"anova_oneway"`, `"prop_two"`
#'   or `"cor_pearson"`.
#' @param n Sample size to simulate: per group (the whole sample for `"t_paired"` and
#'   `"cor_pearson"`), before dropout and design effect. Default: the analytic n of the plan rounded
#'   up, not `plan$n_per_group`. Dropout and design effect are not simulated. With your own `n`, `status` compares only with the
#'   formula (the target rule belongs to the planned n) and a note says so.
#' @param reps Number of simulated studies, a whole number of at least 100. The rule of the package
#'   needs at least 10000; with fewer, `pass` and `status` are `NA` because the gap can be noise.
#' @param seed Optional whole number. With a seed the function leaves your random number stream
#'   unchanged; without one it uses and advances your stream like any random R function.
#' @details `status` is `"pass"` when empirical power is within 0.02 of the analytic power and at
#'   least the target minus 0.02, `"warn"` when it is more than 0.02 above the analytic power (the
#'   plan is safe; the formula is conservative at this n) and `"fail"` otherwise. `"warn"` is
#'   expected for two-sided correlations from r = .6 and one-sided from r = .5 (Fisher z is
#'   conservative; for example a correlation of .8 with `n = 10`), and for two proportions with a small p (such as .05 and
#'   .01), where exact binomial power exceeds the normal approximation. Do not widen the 0.02.
#' @return A `plansize_simulation` list: `test, n, reps, seed, power_sim, mc_se, ci, power_analytic,
#'   diff, target, status, pass, notes` (`notes` are codes the print method explains).
#' @export
simulate_power <- function(plan, n = NULL, reps = 10000, seed = NULL) {
  check_plan(plan)
  spec <- test_spec[[plan$test]]
  if (is.null(spec$simulate)) fail("err_sim_unsupported", msg(paste0("val_", plan$test)))
  unit <- function(k) is_num1(plan[[k]]) && plan[[k]] > 0 && plan[[k]] < 1
  if (!is_num1(plan$n_analytic) || plan$n_analytic <= 0 || !unit("alpha") || !unit("power") ||
      !is_num1(plan$dropout) || !is_num1(plan$deff)) fail("err_plan", "plan")
  n_user <- n
  if (is.null(n)) n <- round_up(plan$n_analytic)
  if (!is_num1(n) || n != round(n) || n < spec$min_n) fail("err_sim_n", "n", spec$min_n)
  if (!is_num1(reps) || reps != round(reps) || reps < 100) fail("err_reps", "reps")
  if (!is.null(seed) && (!is_num1(seed) || seed != round(seed) || abs(seed) > .Machine$integer.max)) {
    fail("err_sim_seed", "seed")
  }
  if (!is.null(seed)) {
    old <- if (exists(".Random.seed", globalenv(), inherits = FALSE)) get(".Random.seed", globalenv())
    on.exit(if (is.null(old)) {
      if (exists(".Random.seed", globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
    } else assign(".Random.seed", old, envir = globalenv()), add = TRUE)
    set.seed(seed)
  }
  draw <- spec$simulate(n, plan)
  p <- suppressWarnings(vapply(seq_len(reps), function(i) draw(), 0))
  power_sim <- sum(p < plan$alpha, na.rm = TRUE) / reps  # a NaN p value is not a rejection
  mc_se <- sqrt(power_sim * (1 - power_sim) / reps)
  analytic <- spec$power(n, plan)
  status <- sim_status(analytic, power_sim, plan$power, reps, planned = is.null(n_user))
  structure(list(test = plan$test, n = n, reps = reps, seed = seed, power_sim = power_sim,
    mc_se = mc_se, ci = power_sim + c(-1, 1) * 1.96 * mc_se, power_analytic = analytic,
    diff = power_sim - analytic, target = plan$power, status = status,
    pass = if (is.na(status)) NA else status == "pass",
    notes = c(character(), if (is.null(n_user) && (plan$dropout > 0 || plan$deff > 1)) "adjust",
              if (!is.null(n_user)) "n", if (reps < 10000) "reps")),
    class = "plansize_simulation")
}

# Spec rule (section 6): |sim - analytic| <= 0.02 and sim >= target - 0.02; 1e-9 only absorbs float error.
# The target rule belongs to the planned n, so a user-given n (planned = FALSE) skips it.
# Fisher z power is conservative for cor_pearson; empirical above analytic is expected at large r
sim_status <- function(analytic, sim, target, reps, planned = TRUE) {
  if (reps < 10000) return(NA_character_)
  if (planned && sim < target - 0.02 - 1e-9) return("fail")
  d <- sim - analytic
  if (abs(d) <= 0.02 + 1e-9) "pass" else if (d > 0) "warn" else "fail"
}

#' Print a simulation check
#'
#' @param x A `plansize_simulation` from [simulate_power()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.plansize_simulation <- function(x, ...) {
  check_simulation(x)
  f <- function(v) fmt_prob(round(v, 4))
  cat(msg("sim_title"), "\n", msg("plan_test", msg(paste0("val_", x$test))), "\n",
      msg_for("sim_n", x$test, fmt_plain(x$n)), "\n", msg("sim_reps", fmt_plain(x$reps)), "\n",
      msg("sim_power", f(x$power_sim), f(x$ci[1]), f(x$ci[2])), "\n",
      msg("sim_analytic", f(x$power_analytic)), "\n", msg("sim_diff", fmt_num(round(x$diff, 3))), "\n",
      msg("sim_target", f(x$target)), "\n", sep = "")
  if (!is.na(x$status)) cat(msg(paste0("sim_", x$status)), "\n", sep = "")
  for (k in x$notes) cat(msg(paste0("sim_note_", k)), "\n", sep = "")
  cat("\n", msg("sim_explain"), "\n", sep = "")
  invisible(x)
}
