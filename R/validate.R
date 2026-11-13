# Internal argument checks. Errors name the argument; texts in messages.csv.

fail <- function(key, ...) stop(msg(key, ...), call. = FALSE)

is_num1 <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)

# A single proportion strictly between 0 and 1.
is_prob1 <- function(x) is_num1(x) && x > 0 && x < 1

check_positive_number <- function(x, name) {
  if (!is_num1(x) || x <= 0) fail("err_positive", name)
  invisible(x)
}

check_probability <- function(x, name) {
  if (!is_num1(x) || x <= 0 || x >= 1) fail("err_probability", name)
  invisible(x)
}

# pwrss accepts power only within 0.01 to 0.99.
check_power <- function(x, alpha, name = "power") {
  if (!is_num1(x) || x < 0.01 || x > 0.99) fail("err_power_range", name)
  if (x <= alpha) fail("err_power_alpha")
  invisible(x)
}

# Returns the matched choice; the untouched default (all choices) gives the first.
check_choice <- function(x, choices, name, exact = FALSE) {
  if (identical(x, choices)) return(choices[1])
  i <- if (is.character(x) && length(x) == 1L) (if (exact) match else pmatch)(x, choices) else NA_integer_
  if (is.na(i)) {
    note <- if (name == "alternative") msg("hint_alternative") else ""
    fail("err_choice", name, paste(choices, collapse = ", "), note)
  }
  choices[i]
}

check_required <- function(missing_arg, name) {
  if (missing_arg) fail("err_missing", name)
}

# Classed so tests and callers can silence this guardrail alone.
warn_basis <- function(basis) {
  if (basis %in% c("unknown", "convention")) {
    warning(structure(class = c("plansize_basis_warning", "warning", "condition"),
      list(message = msg(paste0("warn_", basis)), call = NULL)))
  }
  invisible(basis)
}

# Guards against hand-edited plans before sensitivity().
check_plan <- function(x) {
  ok_basis <- c("unknown", "prior_study", "pilot", "smallest_of_interest", "convention")
  ok <- inherits(x, "plansize_plan") &&
    is.character(x$test) && length(x$test) == 1L && x$test %in% names(test_spec) &&
    is.character(x$effect_basis) && length(x$effect_basis) == 1L && x$effect_basis %in% ok_basis &&
    is_num1(x$groups)
  spec <- if (ok) test_spec[[x$test]]
  if (ok && spec$directional) {
    ok <- is.character(x$alternative) && length(x$alternative) == 1L && x$alternative %in% c("two.sided", "one.sided")
  }
  if (ok) ok <- spec$check(x)
  if (!ok) fail("err_plan", "plan")
  invisible(x)
}
