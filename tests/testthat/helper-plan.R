# Silence only the basis guardrail warning; other warnings stay visible.
quiet_plan_with <- function(f) {
  withCallingHandlers(f(), plansize_basis_warning = function(w) invokeRestart("muffleWarning"))
}
quiet_plan <- function(...) quiet_plan_with(function() plan_study(...))

# Max parenthesis depth; a stray ")" at depth 0 counts as unbalanced too.
paren_depth <- function(x) {
  ch <- strsplit(x, "")[[1]]
  d <- 0L; mx <- 0L
  for (c1 in ch) {
    if (c1 == "(") d <- d + 1L else if (c1 == ")") d <- d - 1L
    if (d < 0L) return(Inf)
    mx <- max(mx, d)
  }
  if (d != 0L) Inf else mx
}
