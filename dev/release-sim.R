# Pre-release simulation sweep (slice 13b): seeded random plans for every test, checked with
# simulate_power(). Run from the repo root:
#   Rscript dev/release-sim.R <reps> <random plans per test> <seed>
# Writes docs/release-sim/<today>.csv and .md; exits with status 2 on a persistent fail
# (status 1 is any R error).
if (!isNamespaceLoaded("plansize")) pkgload::load_all(".", quiet = TRUE)

# Hand-picked edge cases, alpha .05 and power .8 (two-sided unless stated).
EDGES <- list(
  t_independent = list(list(effect = 1.5), list(effect = 0.15), list(effect = 0.8, alternative = "one.sided")),
  t_paired = list(list(effect = 0.6, r = 0.9), list(effect = 0.5, r = -0.3), list(effect = 1.2, r = 0.5)),
  anova_oneway = list(list(effect = 0.25, k = 2), list(effect = 0.6, k = 8), list(effect = 0.1, k = 3)),
  prop_two = list(list(p1 = 0.05, p2 = 0.01, alternative = "one.sided"), list(p1 = 0.95, p2 = 0.85),
                  list(p1 = 0.5, p2 = 0.4)),
  cor_pearson = list(list(effect = 0.8), list(effect = -0.5, alternative = "one.sided"), list(effect = 0.1)),
  chisq_indep = list(list(effect = 0.5, rows = 2, cols = 2), list(effect = 0.1, rows = 5, cols = 5),
                     list(effect = 0.8, rows = 2, cols = 3)),
  reg_overall = list(list(effect = 0.4, effect_type = "r2", predictors = 1),
                     list(effect = 0.02, effect_type = "r2", predictors = 12),
                     list(effect = 0.3, effect_type = "r2", predictors = 3)),
  reg_partial = list(list(effect = 0.1, effect_type = "r2_change", r2_covariates = 0.1, predictors = 2, tested = 1),
                     list(effect = 0.1, effect_type = "r2_change", r2_covariates = 0.1, predictors = 12, tested = 11),
                     list(effect = 0.1, effect_type = "r2_change", r2_covariates = 0, predictors = 5, tested = 2)))

# One random plan's test-specific arguments; i is the plan's number within its test.
draw_args <- function(test, i) {
  u <- function(lo, hi) round(stats::runif(1, lo, hi), 4)
  switch(test,
    t_independent = list(effect = round(exp(stats::runif(1, log(0.15), log(1.5))), 4)),
    t_paired = list(effect = u(0.2, 1.2), r = u(-0.3, 0.9)),
    anova_oneway = list(effect = u(0.1, 0.6), k = sample(2:8, 1)),
    prop_two = {
      p <- c(0, 0)
      while (abs(p[1] - p[2]) < 0.08) p <- c(u(0.05, 0.95), u(0.05, 0.95))
      list(p1 = p[1], p2 = p[2])
    },
    cor_pearson = list(effect = u(0.1, 0.8) * sample(c(-1, 1), 1)),
    chisq_indep = {
      rc <- sample(2:5, 2, replace = TRUE)
      list(effect = u(0.1, 0.9 * plansize:::w_max(rc[1], rc[2])), rows = rc[1], cols = rc[2])
    },
    reg_overall = list(effect = u(0.02, 0.4), effect_type = "r2", predictors = sample(1:12, 1)),
    reg_partial = {
      d <- u(0.01, 0.2); cov <- u(0, 0.3); k <- sample(2:12, 1); tested <- sample.int(k - 1, 1)
      part <- d / (1 - cov)  # every fifth plan enters the same effect as partial f2
      if (i %% 5 == 0) list(effect = part / (1 - part), effect_type = "f2", predictors = k, tested = tested)
      else list(effect = d, effect_type = "r2_change", r2_covariates = cov, predictors = k, tested = tested)
    })
}

make_grid <- function(n_random, seed, edges = TRUE) {
  set.seed(seed)
  g <- list()
  for (test in names(plansize:::test_spec)) {
    for (i in seq_len(n_random)) {
      args <- draw_args(test, i)
      if (plansize:::test_spec[[test]]$directional) args$alternative <- sample(c("two.sided", "one.sided"), 1)
      g[[length(g) + 1]] <- list(test = test, args = c(args, alpha = sample(c(0.05, 0.01), 1),
                                                       power = sample(c(0.8, 0.9), 1)), edge = FALSE)
    }
    if (edges) for (a in EDGES[[test]]) g[[length(g) + 1]] <- list(test = test, args = a, edge = TRUE)
  }
  for (i in seq_along(g)) g[[i]]$seed <- seed + i
  g
}

params <- function(args) paste(names(args), vapply(args, as.character, ""), sep = "=", collapse = ";")

# Adds $plan (or $error for a pwrss infeasible design) to every grid entry.
build_plans <- function(grid) {
  keys <- grep("^err_infeasible", plansize:::read_messages()$key, value = TRUE)
  known <- unlist(lapply(c("en", "tr"), function(l) vapply(keys, plansize:::msg, "", lang = l)))
  for (i in seq_along(grid)) {
    x <- grid[[i]]
    p <- tryCatch(do.call(plan_study, c(list(test = x$test, effect_basis = "pilot"), x$args)),
                  error = function(e) conditionMessage(e))
    if (is.character(p) && !p %in% known) stop("unexpected plan_study error for ", x$test, " ", params(x$args), ": ", p)
    if (is.character(p) && x$edge) stop("edge case does not plan: ", x$test, " ", params(x$args), ": ", p)
    if (is.character(p)) grid[[i]]$error <- p else grid[[i]]$plan <- p
  }
  for (test in unique(vapply(grid, `[[`, "", "test"))) {
    r <- Filter(function(x) x$test == test && !x$edge, grid)
    if (length(r) && mean(vapply(r, function(x) !is.null(x$error), NA)) > 0.2) stop("over 20% of ", test, " plans skipped")
  }
  grid
}

label <- function(status, notes) {
  if (identical(status, "pass")) return("ok")
  if (identical(status, "warn")) return("conservative")
  if (identical(status, "fail")) return("fail")
  if (!identical(status, NA_character_) && !identical(status, NA)) stop("undefined status: ", status)
  for (k in c("reps", "random_partial", "random_no_dmar")) {
    if (k %in% notes) return(c(reps = "low_reps", random_partial = "info_random", random_no_dmar = "info_no_dmar")[[k]])
  }
  stop("undefined NA status, notes: ", paste(notes, collapse = ","))
}

# Fixed families where the formula is known to be conservative (set before the run).
in_family <- function(test, a) {
  switch(test,
    cor_pearson = abs(a$effect) >= (if (identical(a$alternative, "one.sided")) 0.5 else 0.6),
    prop_two = min(a$p1, a$p2) <= 0.15,
    chisq_indep = a$effect / plansize:::w_max(a$rows, a$cols) >= 0.45,
    FALSE)
}

row_of <- function(x, pt, s) {
  data.frame(test = x$test, predictor_type = pt, params = params(x$args), n = s$n, reps = s$reps, seed = s$seed,
             power_sim = s$power_sim, ci_lo = s$ci[1], ci_hi = s$ci[2], power_analytic = s$power_analytic,
             reference = s$reference, diff = s$diff, target = s$target,
             status = if (is.na(s$status)) "NA" else s$status, label = label(s$status, s$notes))
}

main <- function(reps, n_random, seed, sim = simulate_power, out = file.path("docs/release-sim", Sys.Date()),
                 edges = TRUE, grid = make_grid(n_random, seed, edges)) {
  t0 <- proc.time()[["elapsed"]]
  grid <- build_plans(grid)
  rows <- list(); skipped <- character(); persistent <- character()
  for (x in grid) {
    reg <- x$test %in% c("reg_overall", "reg_partial")
    for (pt in if (reg) c("fixed", "random") else "fixed") {
      if (!is.null(x$error)) {
        rows[[length(rows) + 1]] <- data.frame(test = x$test, predictor_type = pt, params = params(x$args),
          n = NA, reps = reps, seed = x$seed, power_sim = NA, ci_lo = NA, ci_hi = NA, power_analytic = NA,
          reference = NA, diff = NA, target = x$args$power %||% 0.8, status = "skipped", label = "skipped")
        skipped <- c(skipped, sprintf("- %s/%s %s: %s", x$test, pt, params(x$args), x$error))
        next
      }
      r <- row_of(x, pt, sim(x$plan, reps = reps, seed = x$seed, predictor_type = pt))
      if (r$label == "fail") {
        r <- rbind(r, row_of(x, pt, sim(x$plan, reps = 1e5, seed = x$seed + 1e6, predictor_type = pt)))
        if (r$label[2] == "fail") persistent <- c(persistent, sprintf("- FAIL %s/%s %s", x$test, pt, r$params[1]))
      }
      rows[[length(rows) + 1]] <- r
      cat(x$test, pt, r$label, "\n")
    }
  }
  res <- do.call(rbind, rows)
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(res, paste0(out, ".csv"), row.names = FALSE)
  write_summary(res, grid, skipped, persistent, proc.time()[["elapsed"]] - t0, paste0(out, ".md"))
  if (length(persistent)) {
    message(length(persistent), " persistent fail(s); see ", out, ".md")
    quit(status = 2)
  }
  invisible(res)
}

write_summary <- function(res, grid, skipped, persistent, secs, file) {
  is_rerun <- duplicated(res[c("test", "predictor_type", "params")]) & res$reps == 1e5
  first <- res[!is_rerun, ]
  key <- paste(first$test, first$predictor_type, sep = "/")
  labs <- c("ok", "conservative", "fail", "info_random", "info_no_dmar", "low_reps", "skipped")
  tab <- vapply(split(first, factor(key, unique(key))), function(d) c(
    runs = nrow(d), vapply(labs, function(l) sum(d$label == l), 0),
    max_abs_diff = round(suppressWarnings(max(abs(d$diff), na.rm = TRUE)), 4)), numeric(length(labs) + 2))
  args <- setNames(lapply(grid, `[[`, "args"), vapply(grid, function(x) paste(x$test, params(x$args)), ""))
  cons <- first[first$label == "conservative", ]
  fam <- vapply(seq_len(nrow(cons)), function(i) in_family(cons$test[i], args[[paste(cons$test[i], cons$params[i])]]), NA)
  line <- function(d) if (nrow(d)) sprintf("- %s/%s %s: diff %.4f", d$test, d$predictor_type, d$params, d$diff) else "- none"
  rerun <- res[is_rerun, ]
  out_fam <- cons[!fam, ]
  mirror <- sum(out_fam$test == "prop_two" &
    vapply(seq_len(nrow(out_fam)), function(i) { a <- args[[paste(out_fam$test[i], out_fam$params[i])]]
      max(a$p1, a$p2) >= 0.85 }, NA))
  si <- utils::sessionInfo()
  ver <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
  writeLines(c("# Release simulation sweep", "",
    sprintf("- %s; %s; %s", si$R.version$version.string, si$platform, si$running),
    sprintf("- plansize %s, pwrss %s, DMAR %s", getNamespaceVersion("plansize"), ver("pwrss"), ver("DMAR")),
    sprintf("- wall time %.1f min", secs / 60), "", "## How to read this and its limits", "",
    "- Labels: ok = simulate_power() pass; conservative = warn (empirical power more than .02 above the formula, the plan is safe); fail = first-run fail; info_random = random reg_partial, no formula to compare with, so no pass rule; skipped = plan_study() could not solve the design.",
    "- Columns count first runs; a fail is rerun with a new seed and 100000 reps and judged on the rerun only (section Reruns).",
    "- max_abs_diff includes info_random rows: random predictors give lower power than the fixed-predictor formula, so large negative gaps there are expected, not failures.",
    "- random reg_overall is compared with DMAR without the target rule, because the plan n is for fixed predictors; such rows can sit below the target power.",
    "- Detection limit: with 20000 reps a true gap just past .02 (e.g. -.021) is caught only about half the time. The sweep finds gross deviations; it does not prove the .02 edge.",
    "- Known conservative families were fixed before the run and are not widened afterwards.",
    if (mirror) sprintf("- %d prop_two row(s) outside the families have max(p1, p2) >= .85. This may be the mirror of the min(p) <= .15 family (relabelling success and failure turns p into 1 - p); a hypothesis, labels unchanged.", mirror),
    "", "## Per test", "",
    paste("| test |", paste(rownames(tab), collapse = " | "), "|"), paste0(strrep("|---", nrow(tab) + 1), "|"),
    sprintf("| %s | %s |", colnames(tab), apply(tab, 2, paste, collapse = " | ")), "",
    "## Conservative, outside the known families", "", line(out_fam), "",
    "## Conservative, inside the known families", "", line(cons[fam, ]), "",
    "## Skipped", "", if (length(skipped)) skipped else "- none", "",
    "## Reruns (100000 reps)", "", if (nrow(rerun)) sprintf("- %s/%s %s: %s, diff %.4f", rerun$test,
      rerun$predictor_type, rerun$params, rerun$label, rerun$diff) else "- none", "",
    "## Persistent fails", "", if (length(persistent)) persistent else "- none"), file)
}

if (sys.nframe() == 0L) {
  a <- suppressWarnings(as.numeric(commandArgs(trailingOnly = TRUE)))
  if (length(a) != 3L || anyNA(a) || any(a != round(a)) || a[1] < 100 || a[2] < 1) {
    stop("usage: Rscript dev/release-sim.R <reps >= 100> <random plans per test >= 1> <seed>")
  }
  main(a[1], a[2], a[3])
}
