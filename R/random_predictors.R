# Random-predictor information line for reg_overall (print only; the plan n stays fixed-X).
RANDOM_N_MAX <- 1e5  # above this DMAR is slow (21 s at 1e6) and gives almost the pwrss n

has_dmar <- function() requireNamespace("DMAR", quietly = TRUE)

dmar_required_n <- function(r2, k, alpha, power) {
  r <- DMAR::ss_power_R2(population_R2 = r2, p = k, alpha_level = alpha,
                         desired_power = power, random_predictors = TRUE)
  r$value[r$term == "necessary_N"]
}

# Integer n for random predictors, or NULL when DMAR is missing, too slow or fails.
# shortcut: DMAR returns a rounded n, so deff and dropout apply to a rounded value (at most
# 1 participant above a single final rounding); switch if DMAR ever returns the unrounded n.
random_predictor_n <- function(plan) {
  if (!has_dmar() || plan$n_analytic > RANDOM_N_MAX) return(NULL)
  n <- tryCatch(dmar_required_n(plan$effect_test, plan$predictors, plan$alpha, plan$power),
                error = function(e) NULL, warning = function(w) NULL)
  if (length(n) != 1L || !is.finite(n) || n < 1) return(NULL)
  as.integer(ceiling(n * plan$deff / (1 - plan$dropout)))
}
