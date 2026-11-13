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

# design is "independent" (effect = d), "paired" (effect = dz) or "anova"
# (effect = Cohen's f, k groups, alternative ignored).
engine_n <- function(effect, alpha, power, alternative, design, k = NULL) {
  if (design == "anova") {
    r <- guard_pwrss(pwrss::power.f.ancova(eta.squared = effect^2 / (1 + effect^2),
      factor.levels = k, power = power, alpha = alpha, ceil.n = FALSE, verbose = 0),
      "err_infeasible_plan_anova_oneway")
    return(list(n = r$n.total / k))
  }
  r <- guard_pwrss(pwrss::power.t.student(d = effect, power = power, alpha = alpha,
    alternative = alternative, design = design, ceil.n = FALSE, verbose = 0),
    if (design == "paired") "err_infeasible_plan_t_paired" else "err_infeasible_plan")
  list(n = r$n[[length(r$n)]])
}

engine_mde <- function(n, alpha, power, alternative, design, k = NULL) {
  if (design == "anova") {
    r <- guard_pwrss(pwrss::power.f.ancova(eta.squared = NULL, factor.levels = k,
      n.total = n * k, power = power, alpha = alpha, ceil.n = FALSE, verbose = 0))
    return(sqrt(r$eta.squared / (1 - r$eta.squared)))
  }
  r <- guard_pwrss(pwrss::power.t.student(d = NULL, n2 = n, power = power, alpha = alpha,
    alternative = alternative, design = design, ceil.n = FALSE, verbose = 0))
  r$d
}

# Two independent proportions, pooled-SE z test. Returns n per group.
# shortcut: pwrss twoprops ignores ceil.n and returns a rounded n, so dropout and deff are applied to a rounded n; the result can be a few participants per group higher (more with larger dropout or deff); compute an unrounded n if pwrss adds support
engine_n_props <- function(p1, p2, alpha, power, alternative) {
  r <- tryCatch(pwrss::power.z.twoprops(prob1 = p1, prob2 = p2, power = power, alpha = alpha,
    alternative = alternative, std.error = "pooled", ceil.n = FALSE, verbose = 0),
    error = function(e) {
      if (grepl("not feasible|null.sd|margin", conditionMessage(e))) fail("err_infeasible_plan_prop_two")
      stop(e)
    })
  r$n[[length(r$n)]]
}

# Detectable p1 for group 2 fixed at p2; `increase` TRUE searches above p2.
# pwrss's own search lands on the flat power-near-1 region, so the root is found here on pwrss's power function.
# If pw has the same sign at both ends of lim, uniroot errors and the result is err_infeasible.
engine_mde_props <- function(n, p2, increase, alpha, power, alternative) {
  pw <- function(p1) pwrss::power.z.twoprops(prob1 = p1, prob2 = p2, n2 = n, power = NULL,
    alpha = alpha, alternative = alternative, std.error = "pooled", verbose = 0)$power - power
  lim <- if (increase) c(p2 + 1e-4, 0.9999) else c(1e-4, p2 - 1e-4)
  tryCatch(stats::uniroot(pw, lim, tol = 1e-8)$root, error = function(e) fail("err_infeasible"))
}
