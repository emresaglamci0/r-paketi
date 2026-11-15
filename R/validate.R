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
# shortcut: absolute margin, no effect above about 1e7 per group; switch to a relative margin if such n become realistic.
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

# Guards against hand-edited simulation results before print.
check_simulation <- function(x) {
  num <- c("power_sim", "mc_se", "power_analytic", "diff", "target")
  st <- x[["status"]]
  one_of <- function(v, set) is.character(v) && length(v) == 1L && v %in% set
  ok <- inherits(x, "plansize_simulation") && is.list(x) && one_of(x$test, names(test_spec)) &&
    all(vapply(num, function(k) is_num1(x[[k]]), TRUE)) && is.numeric(x$ci) && length(x$ci) == 2L &&
    is_num1(x$n) && x$n >= 1 && x$n == round(x$n) && is_num1(x$reps) && x$reps >= 100 && all(is.finite(x$ci)) &&
    is.character(st) && length(st) == 1L && (is.na(st) || st %in% c("pass", "warn", "fail")) &&
    is.character(x$notes) && all(x$notes %in% c("adjust", "n", "reps", "random", "random_no_dmar", "random_partial")) &&
    identical(is.na(st), x$reps < 10000 || any(c("random_no_dmar", "random_partial") %in% x$notes)) &&
    identical(x$pass, if (is.na(st)) NA else st == "pass") &&
    one_of(x$predictor_type, if (x$test %in% c("reg_overall", "reg_partial")) c("fixed", "random") else "fixed") &&
    one_of(x$reference, c("pwrss", "dmar")) &&
    identical(x$reference == "dmar", "random" %in% x$notes) &&
    identical(x$predictor_type == "random", any(startsWith(x$notes, "random")))
  if (!ok) fail("err_sim_obj", "x")
  invisible(x)
}
