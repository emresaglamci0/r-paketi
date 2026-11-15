# Self-test of dev/release-sim.R. Run from the repo root:
#   Rscript dev/release-sim-selftest.R
source("dev/release-sim.R")
tmp <- file.path(Sys.getenv("TMPDIR", tempdir()), "release-sim-selftest")
dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
tmp <- normalizePath(tmp, winslash = "/")  # the child script gets this path inside a string literal
ok <- function(cond, what) {
  if (!isTRUE(cond)) stop("FAILED: ", what, call. = FALSE)
  cat("ok:", what, "\n")
}
stops <- function(expr) inherits(try(expr, silent = TRUE), "try-error")
# TRUE only when expr stops with an error matching pattern, so the right stop must fire.
stops_with <- function(expr, pattern) {
  e <- tryCatch({ expr; NULL }, error = function(e) conditionMessage(e))
  !is.null(e) && grepl(pattern, e, fixed = TRUE)
}
fresh <- function(out) unlink(paste0(out, c(".csv", ".md")))  # never read files of an earlier run

g <- make_grid(25, 20261115)
ok(identical(g, make_grid(25, 20261115)), "same seed gives the same grid")
ok(setequal(vapply(g, `[[`, "", "test"), names(plansize:::test_spec)), "every test has plans")

ok(identical(label("pass", character()), "ok") && identical(label("warn", character()), "conservative") &&
   identical(label("fail", character()), "fail") && identical(label(NA, "random_partial"), "info_random") &&
   identical(label(NA, "random_no_dmar"), "info_no_dmar") && identical(label(NA, c("reps", "random")), "low_reps"),
   "label maps every defined status")
ok(stops(label(NA, character())) && stops(label(NA, "random")) && stops(label("other", character())),
   "undefined status stops")

edges <- build_plans(Filter(function(x) x$edge, g))
ok(length(edges) == 24 && !any(vapply(edges, function(x) is.null(x$plan), NA)), "no edge case is skipped")

bad <- list(list(test = "anova_oneway", args = list(effect = 0.25, k = 3, alternative = "one.sided"),
                 edge = FALSE, seed = 1))
ok(stops_with(build_plans(bad), "unexpected plan_study error"), "unexpected plan_study error stops")
huge <- list(list(test = "t_independent", args = list(effect = 3), edge = FALSE, seed = 1))
normal <- list(list(test = "t_independent", args = list(effect = 0.5), edge = FALSE, seed = 2))
ok(stops_with(build_plans(c(huge, huge, normal, normal, normal)), "over 20%"), "more than 20% skipped stops")
ok(stops_with(build_plans(list(modifyList(huge[[1]], list(edge = TRUE)))), "edge case does not plan"),
   "an edge case that does not plan stops")

# One infeasible plan in five (20%) is written as a skipped row with its error text.
pass_sim <- function(plan, reps, seed, predictor_type) list(n = 10, reps = reps, seed = seed,
  power_sim = 0.8, ci = c(0.79, 0.81), power_analytic = 0.8, reference = "pwrss", diff = 0,
  target = plan$power, status = "pass", notes = character())
sk <- file.path(tmp, "skip"); fresh(sk)
s <- main(500, sim = pass_sim, out = sk, grid = c(huge, rep(normal, 4)))
ok(sum(s$label == "skipped") == 1 && sum(s$label == "ok") == 4 &&
   any(grepl("pwrss cannot solve", readLines(paste0(sk, ".md")), fixed = TRUE)), "a skipped plan keeps its row and error")

ok(in_family("cor_pearson", list(effect = 0.6)) && !in_family("cor_pearson", list(effect = 0.5999)) &&
   in_family("cor_pearson", list(effect = -0.5, alternative = "one.sided")) &&
   !in_family("cor_pearson", list(effect = 0.4999, alternative = "one.sided")) &&
   in_family("prop_two", list(p1 = 0.5, p2 = 0.15)) && !in_family("prop_two", list(p1 = 0.5, p2 = 0.1501)) &&
   in_family("chisq_indep", list(effect = 0.45, rows = 2, cols = 2)) &&  # w_max(2, 2) = 1: exactly on the edge
   !in_family("chisq_indep", list(effect = 0.449 * plansize:::w_max(3, 3), rows = 3, cols = 3)) &&
   !in_family("t_independent", list(effect = 2)), "family thresholds sit exactly where the plan fixed them")

fresh(file.path(tmp, "a")); fresh(file.path(tmp, "b"))
a <- main(500, 2, 20261115, out = file.path(tmp, "a"), edges = FALSE)
main(500, 2, 20261115, out = file.path(tmp, "b"), edges = FALSE)
ok(identical(readLines(file.path(tmp, "a.csv")), readLines(file.path(tmp, "b.csv"))), "same seed gives the same CSV")
ok(nrow(a) == 20 && all(a$label %in% c("low_reps", "skipped")), "small run: one row per run, low_reps")

# Deliberate break in a child process. `rule` decides the fake status from reps.
run_child <- function(name, rule) {
  child <- file.path(tmp, paste0(name, ".R")); out <- file.path(tmp, name); fresh(out)
  writeLines(c('source("dev/release-sim.R")',
    'fake <- function(plan, reps, seed, predictor_type) list(n = 10, reps = reps, seed = seed,',
    '  power_sim = 0.5, ci = c(0.49, 0.51), power_analytic = 0.8, reference = "pwrss", diff = -0.3,',
    sprintf('  target = plan$power, status = %s, notes = character())', rule),
    sprintf('main(500, 1, 1, sim = fake, out = "%s", edges = FALSE)', out)), child)
  list(status = as.integer(system2(file.path(R.home("bin"), "Rscript"), child)), out = out)
}
# Fails on the first run, passes on the rerun: judged on the rerun, so no stop.
rec <- run_child("recover", 'if (reps < 1e5) "fail" else "pass"')
csv <- read.csv(paste0(rec$out, ".csv"))
ok(identical(rec$status, 0L) && nrow(csv) == 20 && sum(csv$reps == 1e5) == 10 &&
   !any(startsWith(readLines(paste0(rec$out, ".md")), "- FAIL ")), "a fail that passes on rerun does not stop")
# Always fails: rerun, summary listing and exit 2 (an R error would give 1).
brk <- run_child("break", '"fail"')
ok(identical(brk$status, 2L), "persistent fail exits with status 2")
out <- brk$out
csv <- read.csv(paste0(out, ".csv"))
first <- csv[csv$reps == 500, ]
rerun <- csv[csv$reps == 1e5, ]
ok(nrow(first) == 10 && nrow(rerun) == 10 && nrow(csv) == 20 && all(rerun$seed == first$seed + 1e6) &&
   all(csv$label == "fail"), "every failed run is rerun with seed + 1e6 and 100000 reps")
ok(sum(startsWith(readLines(paste0(out, ".md")), "- FAIL ")) == 10, "summary lists every persistent fail")
cat("self-test passed\n")
