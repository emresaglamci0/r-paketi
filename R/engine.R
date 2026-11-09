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

engine_n <- function(effect, alpha, power, alternative) {
  r <- guard_pwrss(pwrss::power.t.student(d = effect, power = power, alpha = alpha,
    alternative = alternative, design = "independent", ceil.n = FALSE, verbose = 0),
    "err_infeasible_plan")
  list(n = r$n[[2]], method = "student_t_independent")
}

engine_mde <- function(n, alpha, power, alternative) {
  r <- guard_pwrss(pwrss::power.t.student(d = NULL, n2 = n, power = power, alpha = alpha,
    alternative = alternative, design = "independent", ceil.n = FALSE, verbose = 0))
  r$d
}
