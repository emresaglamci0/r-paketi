# Internal argument checks. Errors name the argument; texts in messages.csv.

fail <- function(key, ...) stop(msg(key, ...), call. = FALSE)

is_num1 <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)

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
check_choice <- function(x, choices, name) {
  if (identical(x, choices)) return(choices[1])
  i <- if (is.character(x) && length(x) == 1L) pmatch(x, choices) else NA_integer_
  if (is.na(i)) {
    note <- if (name == "alternative") msg("hint_alternative") else ""
    fail("err_choice", name, paste(choices, collapse = ", "), note)
  }
  choices[i]
}

check_required <- function(missing_arg, name) {
  if (missing_arg) fail("err_missing", name)
}
