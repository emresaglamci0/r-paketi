#' Smallest detectable effect for given sample sizes
#'
#' For each combination of recruited per-group n and power, returns the
#' smallest standardized effect detectable after dropout and design effect.
#'
#' @param plan A `plansize_plan` from [plan_study()].
#' @param n Recruited per-group sample sizes (participants for "t_paired"). Defaults to `plan$n_per_group`.
#' @param power Target powers, each from 0.01 to 0.99 and greater than the plan's alpha.
#' @details `n_effective` is `floor(n * (1 - dropout) / deff)`, rounded down, so the
#'   minimum detectable effect for a plan with dropout can be slightly above the
#'   planned effect (conservative).
#' @return A data frame of class `plansize_sensitivity` with columns
#'   `n_recruited`, `n_effective`, `power`, `mde`. For "anova_oneway" `mde` is in the
#'   plan's `effect_type` (f or eta squared); the unit is kept in `attr(, "effect_type")`.
#' @export
sensitivity <- function(plan, n = NULL, power = c(0.80, 0.90, 0.95)) {
  check_required(missing(plan), "plan")
  check_plan(plan)
  spec <- test_spec[[plan$test]]
  if (is.null(n)) n <- plan$n_per_group
  if (!is.numeric(n) || length(n) < 1L || any(!is.finite(n)) || any(n <= 0)) {
    fail("err_positive", "n")
  }
  if (!is.numeric(power) || length(power) < 1L) fail("err_power_range", "power")
  for (p in power) check_power(p, plan$alpha)

  g <- expand.grid(n_recruited = n, power = power)
  g$n_effective <- floor(g$n_recruited * (1 - plan$dropout) / plan$deff + 1e-9)
  small <- which(g$n_effective < spec$min_n)
  if (length(small)) fail("err_n_small", format(g$n_recruited[small[1]]), spec$min_n)
  g$mde <- mapply(engine_mde, n = g$n_effective, power = g$power,
    MoreArgs = list(alpha = plan$alpha, alternative = plan$alternative, design = spec$design,
      k = plan[["k"]]))
  # Paired engine returns dz; report d under the plan's r.
  if (spec$design == "paired") g$mde <- g$mde * sqrt(2 * (1 - plan$r))
  # ANOVA engine returns f; report in the unit the user entered.
  if (spec$design == "anova" && plan$effect_type == "eta2") g$mde <- g$mde^2 / (1 + g$mde^2)
  g <- g[c("n_recruited", "n_effective", "power", "mde")]
  structure(g, class = c("plansize_sensitivity", "data.frame"), test = plan$test,
    effect_type = plan$effect_type)
}
