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

# Dropout and design effect checks shared by the plan functions.
check_adjust <- function(dropout, deff) {
  if (!is_num1(dropout) || dropout < 0 || dropout >= 1) fail("err_dropout", "dropout")
  if (!is_num1(deff) || deff < 1) fail("err_deff", "deff")
  invisible(NULL)
}

# Round up with a floating-point margin (400 * 1.1 is 440.00000000000006).
round_up <- function(x) ceiling(x - 1e-9)

# Guards against hand-edited plans before sensitivity().
check_plan <- function(x) {
  if (inherits(x, "plansize_precision")) fail("err_precision_plan")
  ok_basis <- c("unknown", "prior_study", "pilot", "smallest_of_interest", "convention")
  ok <- inherits(x, "plansize_plan") &&
    is.character(x$test) && length(x$test) == 1L && x$test %in% names(test_spec) &&
    is.character(x$effect_basis) && length(x$effect_basis) == 1L && x$effect_basis %in% ok_basis &&
    is_num1(x$groups)
  spec <- if (ok) test_spec[[x$test]]
  if (ok && spec$directional) {
    ok <- is.character(x$alternative) && length(x$alternative) == 1L && x$alternative %in% c("two.sided", "one.sided")
  }
  if (ok && !spec$directional) ok <- isTRUE(is.na(x$alternative))
  if (ok) ok <- spec$check(x)
  if (!ok) fail("err_plan", "plan")
  invisible(x)
}

# Guards against hand-edited precision plans before print and write_methods.
check_precision_plan <- function(x) {
  num <- c("p", "e", "conf_level", "n0", "n_analytic", "n_required", "dropout", "deff")
  ok <- inherits(x, "plansize_precision") && is.list(x) &&
    all(vapply(num, function(k) is_num1(x[[k]]), TRUE)) &&
    (is.null(x$N) || is_num1(x$N)) && identical(x$method, "cochran_wald")
  if (!ok) fail("err_precision_obj", "plan")
  invisible(x)
}
