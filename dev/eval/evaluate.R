# Main plansize evaluation: plan -> bootstrap power -> status table + console log.
t0 <- Sys.time()
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("dev/eval/make-education-data.R"); source("dev/eval/eval-helpers.R")
d <- make_education_data()
e <- estimate_effects(d)
dir.create("docs/eval", showWarnings = FALSE)
sink(file("docs/eval/2026-11-15-konsol.txt", open = "wt", encoding = "UTF-8"), split = FALSE)
cat("Estimated effects:\n"); print(unlist(e))

# Run expr, return value (or condition) + captured warning classes/messages.
catch <- function(expr) {
  w <- character()
  v <- withCallingHandlers(tryCatch(expr, error = function(c) c),
    warning = function(c) { w <<- c(w, paste0("[", class(c)[1], "] ", conditionMessage(c))); invokeRestart("muffleWarning") })
  list(value = v, warnings = w)
}
P <- function(...) plan_study(..., effect_basis = "prior_study")
specs <- list(
  t_independent = list(quote(P("t_independent", effect = e$d_ind)), "ozel_ders", e$d_ind),
  t_paired = list(quote(P("t_paired", effect = e$d_paired, r = e$r_paired)), NULL, e$d_paired),
  anova_oneway = list(quote(P("anova_oneway", effect = e$f_anova, k = 3)), "okul_turu", e$f_anova),
  prop_two = list(quote(P("prop_two", p1 = e$p1, p2 = e$p2)), "ozel_ders", e$p1 - e$p2),
  cor_pearson = list(quote(P("cor_pearson", effect = e$r_cor)), NULL, e$r_cor),
  chisq_indep = list(quote(P("chisq_indep", effect = e$w_chisq, rows = 3, cols = 2)), NULL, e$w_chisq),
  reg_overall = list(quote(P("reg_overall", effect = e$r2_reg, effect_type = "r2", predictors = 5)), NULL, e$r2_reg),
  reg_partial = list(quote(P("reg_partial", effect = e$r2_change, effect_type = "r2_change",
                             r2_covariates = e$r2_cov, predictors = 5, tested = 2)), NULL, e$r2_change))
plans <- list(); warns <- list()
for (nm in names(specs)) {
  r <- catch(eval(specs[[nm]][[1]])); plans[[nm]] <- r$value; warns[[nm]] <- r$warnings
  cat("\n=====", nm, "=====\n"); if (length(r$warnings)) cat("PLAN WARNINGS:", r$warnings, sep = "\n  ")
  print(r$value)
}
plans$anova_oneway_dogal <- plans$anova_oneway

row <- function(test, effect, n_plan, n_big, bp, tol, target, note = "")
  data.frame(test = test, effect = effect, n_plan = n_plan, n_evrenden_buyuk = n_big,
             power_boot = bp$power, mc_se = bp$mc_se, n_na = bp$n_na,
             durum = if (abs(bp$power - target) <= tol) "KALDI" else "INCELE",
             n_warn = bp$n_warn, note = note)
res <- list(); set.seed(1)
for (nm in c(names(specs), "anova_oneway_dogal")) {
  pl <- plans[[nm]]; sp <- if (nm == "anova_oneway_dogal") list(NULL, NULL, e$f_anova) else specs[[nm]]
  strata <- sp[[2]]; test <- sub("_dogal", "", nm)
  n <- if (is.null(strata)) pl$n_total else pl$n_per_group
  avail <- if (is.null(strata)) nrow(d) else min(table(d[[strata]]))
  bp <- boot_power(d, test, n, strata = strata); note <- ""
  if (nm == "reg_overall") {
    nr <- plansize:::random_predictor_n(pl)
    b2 <- boot_power(d, test, nr)
    note <- sprintf("DMAR random n = %s; boot power at X = %.3f (n_na %d, n_warn %d)", nr, b2$power, b2$n_na, b2$n_warn)
  }
  if (nm == "reg_partial") note <- "no random-predictor n in package for reg_partial"
  if (nm == "anova_oneway_dogal") note <- "natural proportions, no stratification"
  if (length(warns[[nm]])) note <- paste(note, "plan warning:", paste(warns[[nm]], collapse = " | "))
  res[[nm]] <- row(nm, sp[[3]], n, n > avail, bp, .027, .80, trimws(note))
}

# Precision: draw n_required of 500 without replacement.
pp <- plan_precision(p = e$p_gecti, e = .05, N = 500); cat("\n===== plan_precision =====\n"); print(pp)
cov_prec <- function(y, n, p, e, reps = 2000) {
  hits <- wide <- numeric(reps)
  for (i in seq_len(reps)) {
    ph <- mean(y[sample.int(length(y), n)])
    hits[i] <- abs(ph - p) <= e
    wide[i] <- 1.96 * sqrt(ph * (1 - ph) / n) * sqrt((length(y) - n) / (length(y) - 1)) > e
  }
  list(power = mean(hits), mc_se = sqrt(mean(hits) * (1 - mean(hits)) / reps), n_na = 0L, n_warn = 0L, wide = mean(wide))
}
cp <- cov_prec(d$gecti, pp$n_required, e$p_gecti, .05)
res$plan_precision <- row("plan_precision", e$p_gecti, pp$n_required, pp$n_required > nrow(d), cp, .015, .95,
                          sprintf("share FPC Wald half-width > .05: %.3f", cp$wide))
out <- do.call(rbind, res); rownames(out) <- NULL
write.csv(out, "docs/eval/2026-11-15-sonuclar.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat("\n===== RESULTS =====\n"); print(out[, 1:9]); print(out$note)

# Step 3: pilot experiment (t_independent only).
cat("\n===== PILOT =====\n"); set.seed(2)
ig <- split(seq_len(nrow(d)), d$ozel_ders); pw <- character()
npg <- rep(NA_real_, 500); tp <- rep(NA_real_, 500)
for (i in 1:500) {
  b <- d[unlist(lapply(ig, function(ix) sample(ix, 15))), ]
  g <- b$ozel_ders == "evet"; x1 <- b$mat_son[g]; x0 <- b$mat_son[!g]
  dp <- (mean(x1) - mean(x0)) / sqrt((var(x1) + var(x0)) / 2)
  if (dp <= 0) next
  r <- catch(plan_study("t_independent", effect = dp, effect_basis = "pilot"))
  pw <- c(pw, r$warnings); npg[i] <- r$value$n_per_group
  tp[i] <- power.t.test(n = npg[i], delta = e$d_ind)$power
}
cat(sprintf("planlanamaz share: %.3f\nn median: %s  max: %s\nshare n_per_group > 500: %.3f\ntrue power median: %.3f\nshare true power < .50: %.3f\n",
  mean(is.na(npg)), median(npg, na.rm = TRUE), max(npg, na.rm = TRUE), mean(npg > 500, na.rm = TRUE),
  median(tp, na.rm = TRUE), mean(tp < .5, na.rm = TRUE)))
cat("plansize warnings during pilot plans (unique, count):\n"); print(table(pw))

# Step 4: other functions on all 8 plans.
cat("\n===== OTHER FUNCTIONS =====\n")
for (nm in names(specs)) {
  pl <- plans[[nm]]; cat("\n---", nm, "---\n")
  for (f in list(quote(sensitivity(pl)), quote(write_methods(pl, "tr")), quote(write_methods(pl, "en")))) {
    r <- catch(eval(f))
    if (inherits(r$value, "condition")) cat("ERROR:", conditionMessage(r$value), "\n") else print(r$value)
    if (length(r$warnings)) cat("WARN:", r$warnings, sep = "\n  ")
  }
  r <- catch(simulate_power(pl, reps = 10000, seed = 1))
  if (inherits(r$value, "condition")) cat("simulate_power ERROR:", conditionMessage(r$value), "\n")
  else cat("simulate_power status:", format(r$value$status), "\n")
  if (length(r$warnings)) cat("simulate_power WARN:", r$warnings, sep = "\n  ")
}

# Step 5: deliberately bad inputs.
cat("\n===== BAD INPUTS =====\n")
bad <- list(
  t_effect_neg = quote(P("t_independent", effect = -0.3)),
  basis_observed = quote(plan_study("t_independent", effect = .3, effect_basis = "observed")),
  prop_p1_eq_p2 = quote(P("prop_two", p1 = .5, p2 = .5)),
  chisq_one_sided = quote(P("chisq_indep", effect = .2, rows = 3, cols = 2, alternative = "one.sided")),
  partial_tested_eq_predictors = quote(P("reg_partial", effect = .05, effect_type = "r2_change", r2_covariates = .1, predictors = 3, tested = 3)),
  power_1 = quote(P("t_independent", effect = .3, power = 1)),
  dropout_1 = quote(P("t_independent", effect = .3, dropout = 1)))
for (nm in names(bad)) {
  r <- catch(eval(bad[[nm]]))
  if (inherits(r$value, "condition")) cat(sprintf("%s: ERROR class=%s | %s\n", nm, class(r$value)[1], conditionMessage(r$value)))
  else cat(sprintf("%s: NO ERROR, returned n_per_group=%s  <-- FINDING\n", nm, r$value$n_per_group))
  if (length(r$warnings)) cat("  warnings:", r$warnings, "\n")
}
cat("\nElapsed:", format(Sys.time() - t0), "\n")
sink()
