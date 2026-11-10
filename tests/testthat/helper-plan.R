# Silence only the basis guardrail warning; other warnings stay visible.
quiet_plan_with <- function(f) {
  withCallingHandlers(f(), plansize_basis_warning = function(w) invokeRestart("muffleWarning"))
}
quiet_plan <- function(...) quiet_plan_with(function() plan_study(...))
