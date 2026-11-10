# Thin wrappers around pwrss. No power math is implemented here.

# Translate only pwrss's infeasible-design error; rethrow anything else as is.
guard_pwrss <- function(expr, key = "err_infeasible") {
  tryCatch(expr, error = function(e) {
    if (grepl("not feasible", conditionMessage(e), fixed = TRUE)) {
      stop(msg(key), call. = FALSE)
    }
    stop(e)
  })
}

# design is "independent" (effect = d) or "paired" (effect = dz).
engine_n <- function(effect, alpha, power, alternative, design) {
  r <- guard_pwrss(pwrss::power.t.student(d = effect, power = power, alpha = alpha,
    alternative = alternative, design = design, ceil.n = FALSE, verbose = 0),
    if (design == "paired") "err_infeasible_plan_t_paired" else "err_infeasible_plan")
  list(n = r$n[[length(r$n)]], method = paste0("student_t_", design))
}

engine_mde <- function(n, alpha, power, alternative, design) {
  r <- guard_pwrss(pwrss::power.t.student(d = NULL, n2 = n, power = power, alpha = alpha,
    alternative = alternative, design = design, ceil.n = FALSE, verbose = 0))
  r$d
}
