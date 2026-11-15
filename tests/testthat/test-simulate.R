# Independent references for the analytic power at the planned n. Same method only where noted:
# stats::power.t.test, stats::power.prop.test, pwr::pwr.anova.test. pwrss masks power.t.test
# when attached, so always write stats::. pwr::pwr.r.test uses the bias-corrected Fisher z, a
# different method from pwrss, so its tolerance is 0.01.
sim_plan <- function(...) quiet_plan(effect_basis = "pilot", ...)

sim_cases <- function() {
  list(
    ind_two = list(plan = sim_plan(effect = 0.5), n = 64),
    ind_one = list(plan = sim_plan(effect = 0.5, alternative = "one.sided"), n = 51),
    pair_r5 = list(plan = sim_plan(test = "t_paired", effect = 0.5, r = 0.5), n = 34),
    pair_rneg = list(plan = sim_plan(test = "t_paired", effect = 0.5, r = -0.3), n = 84),
    pair_r7 = list(plan = sim_plan(test = "t_paired", effect = 0.4, r = 0.7), n = 32),
    anova = list(plan = sim_plan(test = "anova_oneway", effect = 0.25, k = 3), n = 53),
    prop = list(plan = sim_plan(test = "prop_two", p1 = 0.45, p2 = 0.30), n = 163),
    prop_one = list(plan = sim_plan(test = "prop_two", p1 = 0.10, p2 = 0.05, alternative = "one.sided"), n = 343),
    prop_rev = list(plan = sim_plan(test = "prop_two", p1 = 0.05, p2 = 0.10, alternative = "one.sided"), n = 343),
    cor = list(plan = sim_plan(test = "cor_pearson", effect = 0.3), n = 85),
    cor_neg = list(plan = sim_plan(test = "cor_pearson", effect = -0.3, alternative = "one.sided"), n = 68),
    cor_r5 = list(plan = sim_plan(test = "cor_pearson", effect = 0.5), n = 30),
    chi_33 = list(plan = sim_plan(test = "chisq_indep", effect = 0.3, rows = 3, cols = 3), n = 133),
    chi_22 = list(plan = sim_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2), n = 88),
    chi_25 = list(plan = sim_plan(test = "chisq_indep", effect = 0.1, rows = 2, cols = 5), n = 1194),
    reg_13 = list(plan = reg_plan(0.13, 3), n = 77),
    reg_30 = list(plan = reg_plan(0.30, 3), n = 30),
    reg_05 = list(plan = reg_plan(0.05, 10), n = 318),
    part_r2 = list(plan = part_plan(), n = 71),
    part_f2 = list(plan = sim_plan(test = "reg_partial", effect = 0.15, effect_type = "f2", predictors = 5,
                                   tested = 2), n = 68)
  )
}
reg_plan <- function(r2, k) sim_plan(test = "reg_overall", effect = r2, effect_type = "r2", predictors = k)
part_plan <- function() sim_plan(test = "reg_partial", effect = 0.10, effect_type = "r2_change",
                                 r2_covariates = 0.20, predictors = 5, tested = 2)

# Exact binomial power is above pwrss for small p, so the plan is safe and status is "warn".
warn_cases <- function() {
  list(
    prop_small_p = list(plan = sim_plan(test = "prop_two", p1 = 0.05, p2 = 0.01, alternative = "one.sided"), n = 224),
    cor_r8 = list(plan = sim_plan(test = "cor_pearson", effect = 0.8), n = 10),
    # The chi-square formula is conservative for a small table with a large w.
    chi_23_w8 = list(plan = sim_plan(test = "chisq_indep", effect = 0.8, rows = 2, cols = 3), n = 16)
  )
}

test_that("analytic power matches independent references", {
  skip_if_not_installed("pwr")
  cs <- sim_cases()
  an <- function(k) test_spec[[cs[[k]]$plan$test]]$power(cs[[k]]$n, cs[[k]]$plan)
  tt <- function(k, ..., type = "two.sample") stats::power.t.test(n = cs[[k]]$n, delta = cs[[k]]$plan$effect_test,
    sd = 1, type = type, ...)$power
  expect_equal(an("ind_two"), tt("ind_two"), tolerance = 1e-3)
  expect_equal(an("ind_one"), tt("ind_one", alternative = "one.sided"), tolerance = 1e-3)
  for (k in c("pair_r5", "pair_rneg", "pair_r7")) expect_equal(an(k), tt(k, type = "paired"), tolerance = 1e-3)
  expect_equal(an("prop"), stats::power.prop.test(n = 163, p1 = 0.45, p2 = 0.30)$power, tolerance = 1e-3)
  expect_equal(an("prop_one"), stats::power.prop.test(n = 343, p1 = 0.10, p2 = 0.05,
    alternative = "one.sided")$power, tolerance = 1e-3)
  expect_equal(an("anova"), pwr::pwr.anova.test(k = 3, n = 53, f = 0.25)$power, tolerance = 1e-3)
  expect_equal(an("cor"), pwr::pwr.r.test(n = 85, r = 0.3)$power, tolerance = 0.01)
  expect_equal(an("cor_neg"), pwr::pwr.r.test(n = 68, r = 0.3, alternative = "greater")$power, tolerance = 0.01)
  expect_equal(an("chi_33"), pwr::pwr.chisq.test(w = 0.3, N = 133, df = 4)$power, tolerance = 1e-3)
  expect_equal(an("chi_22"), pwr::pwr.chisq.test(w = 0.3, N = 88, df = 1)$power, tolerance = 1e-3)
  expect_equal(an("reg_13"), pwr::pwr.f2.test(u = 3, v = 73, f2 = 0.13 / 0.87)$power, tolerance = 1e-3)
  expect_equal(an("reg_30"), pwr::pwr.f2.test(u = 3, v = 26, f2 = 0.30 / 0.70)$power, tolerance = 1e-3)
  expect_equal(an("reg_05"), pwr::pwr.f2.test(u = 10, v = 307, f2 = 0.05 / 0.95)$power, tolerance = 1e-3)
  # pwr uses lambda = f2 * (u + v + 1); the rescaled f2 gives lambda = f2 * n as in pwrss (slice 9b).
  f2 <- 0.10 / (1 - 0.30)
  expect_equal(an("part_r2"), pwr::pwr.f2.test(u = 2, v = 71 - 5 - 1, f2 = f2 * 71 / (71 - 5 + 2))$power,
               tolerance = 1e-3)
})

test_that("simulated power agrees with the analytic power (tolerance 0.02, never widened)", {
  skip_on_cran()
  for (nm in names(sim_cases())) {
    cs <- sim_cases()[[nm]]
    if (nm == "cor_r5") expect_identical(sim_plan(test = "cor_pearson", effect = 0.5)$n_per_group, 30L)
    r <- simulate_power(cs$plan, reps = 10000, seed = 11)
    expect_identical(r$n, cs$n, label = nm)
    expect_lte(abs(r$diff), 0.02, label = paste(nm, "diff"))
    expect_gte(r$power_sim, cs$plan$power - 0.02, label = paste(nm, "target"))
    expect_identical(r$status, "pass", label = nm)
    expect_true(r$pass, label = nm)
    expect_identical(r$reference, "pwrss", label = nm)
    if (cs$plan$test %in% c("chisq_indep", "reg_overall", "reg_partial")) {
      expect_match(capture.output(print(r)), msg_for("sim_n", cs$plan$test, r$n), fixed = TRUE, all = FALSE)
    }
  }
  for (nm in names(warn_cases())) {
    cs <- warn_cases()[[nm]]
    r <- simulate_power(cs$plan, n = cs$n, reps = 10000, seed = 11)
    expect_identical(round_up(cs$plan$n_analytic), cs$n, label = nm)
    expect_identical(r$status, "warn", label = nm)
    expect_false(r$pass, label = nm)
  }
})

test_that("seed is reproducible and the user's RNG is kept", {
  withr::local_preserve_seed()
  p <- sim_plan(effect = 0.5)
  a <- simulate_power(p, reps = 200, seed = 5)
  expect_identical(a$power_sim, simulate_power(p, reps = 200, seed = 5)$power_sim)
  set.seed(1); before <- get(".Random.seed", globalenv())
  simulate_power(p, reps = 200, seed = 5)
  expect_identical(get(".Random.seed", globalenv()), before)
  rm(".Random.seed", envir = globalenv())
  simulate_power(p, reps = 200, seed = 5)
  expect_false(exists(".Random.seed", globalenv(), inherits = FALSE))
  set.seed(1); before <- get(".Random.seed", globalenv())
  r <- simulate_power(p, reps = 200)
  expect_false(identical(get(".Random.seed", globalenv()), before))
  expect_true(is.na(r$pass)); expect_true(is.na(r$status))
})

test_that("invalid input gives the documented errors in both languages", {
  p <- sim_plan(effect = 0.5)
  e <- function(f, key, ...) expect_error(f, msg(key, ...), fixed = TRUE)
  for (lang in c("en", "tr")) {
    withr::local_options(plansize.lang = lang)
    e(simulate_power(p, reps = 10), "err_reps", "reps")
    e(simulate_power(p, reps = 99), "err_reps", "reps")
    e(simulate_power(p, reps = 1000.5), "err_reps", "reps")
    for (n in list(0, 1.5, NA, "a")) e(simulate_power(p, n = n, reps = 200), "err_sim_n", "n", 3)
    e(simulate_power(p, reps = 200, seed = "a"), "err_sim_seed", "seed")
    e(simulate_power(plan_precision(e = 0.05)), "err_precision_plan")
    bad <- p; bad$n_analytic <- "a"
    e(simulate_power(bad, reps = 200), "err_plan", "plan")
    bad <- p; bad$alpha <- 2
    e(simulate_power(bad, reps = 200), "err_plan", "plan")
    e(simulate_power(p, reps = 200, predictor_type = "random"), "err_sim_predictor_type", "predictor_type")
    e(simulate_power(reg_plan(0.13, 3), reps = 200, predictor_type = "rand"), "err_choice", "predictor_type",
      "fixed, random", "")
    e(simulate_power(reg_plan(0.05, 10), n = 11, reps = 200), "err_sim_n", "n", 12)
  }
})

test_that("dropout and design effect are not simulated and the note says so", {
  p <- sim_plan(effect = 0.5, dropout = 0.1, deff = 1.5)
  r <- simulate_power(p, reps = 200, seed = 1)
  expect_identical(r$n, round_up(p$n_analytic))
  expect_false(r$n == p$n_per_group)
  expect_true(all(c("adjust", "reps") %in% r$notes))
  expect_identical(simulate_power(p, n = 30, reps = 200, seed = 1)$n, 30)
})

test_that("print shows the result in both languages and refuses edited objects", {
  p <- sim_plan(effect = 0.5, dropout = 0.1, deff = 1.5)
  r <- simulate_power(p, reps = 200, seed = 1)
  out <- capture.output(print(r))
  expect_match(out, "Empirical power", fixed = TRUE, all = FALSE)
  expect_match(out, "not the observed power", fixed = TRUE, all = FALSE)
  expect_match(out, msg("sim_note_adjust"), fixed = TRUE, all = FALSE)
  expect_match(out, as.character(r$n), fixed = TRUE, all = FALSE)
  withr::local_options(plansize.lang = "tr", OutDec = ",")
  tr <- capture.output(print(r))
  expect_match(tr, "Ampirik g\u00fc\u00e7", fixed = TRUE, all = FALSE)
  expect_match(tr, "g\u00f6zlenen g\u00fc\u00e7 de\u011fildir", fixed = TRUE, all = FALSE)
  expect_false(any(grepl("[0-9],[0-9]", tr)))
  r$reps <- 5
  expect_error(print(r), msg("err_sim_obj", "x"), fixed = TRUE)
  r <- simulate_power(p, reps = 200, seed = 1); r$status <- "maybe"
  expect_error(print(r), msg("err_sim_obj", "x"), fixed = TRUE)
})

test_that("status classification uses fixed numbers (analytic, simulated, target, reps)", {
  expect_identical(sim_status(0.80, 0.80, 0.80, 10000), "pass")
  expect_identical(sim_status(0.80, 0.82, 0.80, 10000), "pass")   # exactly on the 0.02 edge
  expect_identical(sim_status(0.80, 0.78, 0.80, 10000), "pass")
  expect_identical(sim_status(0.8281, 0.8637, 0.80, 10000), "warn")
  expect_identical(sim_status(0.80, 0.75, 0.80, 10000), "fail")
  expect_identical(sim_status(0.80, 0.85, 0.90, 10000), "fail")   # below target - 0.02
  expect_true(is.na(sim_status(0.80, 0.80, 0.80, 9999)))
})

test_that("power and simulate exist for all eight tests", {
  has <- vapply(test_spec, function(s) !is.null(s$simulate) && !is.null(s$power), TRUE)
  expect_identical(names(has)[has], c("t_independent", "t_paired", "anova_oneway", "prop_two", "cor_pearson",
                                      "chisq_indep", "reg_overall", "reg_partial"))
})

test_that("a plain plan prints at 10000 repetitions and a given n is compared with the formula only", {
  skip_on_cran()
  r <- simulate_power(sim_plan(effect = 0.5), reps = 10000, seed = 1)
  expect_identical(r$notes, character())
  expect_match(capture.output(print(r)), msg("sim_pass"), fixed = TRUE, all = FALSE)
  # n = 30 is far below the planned n: power ~.48 is not target power, but the formula still holds.
  r <- simulate_power(sim_plan(effect = 0.5), n = 30, reps = 10000, seed = 1)
  expect_identical(r$status, "pass")
  expect_identical(r$notes, "n")
  expect_match(capture.output(print(r)), msg("sim_note_n"), fixed = TRUE, all = FALSE)
})

test_that("print shows the status line, the n unit and no adjust note for a given n", {
  r <- simulate_power(sim_plan(effect = 0.5), reps = 200, seed = 1)
  r$reps <- 10000; r$notes <- character()
  for (st in c("pass", "warn", "fail")) {
    r$status <- st; r$pass <- st == "pass"
    expect_match(capture.output(print(r)), msg(paste0("sim_", st)), fixed = TRUE, all = FALSE)
  }
  expect_match(capture.output(print(r)), msg_for("sim_n", "t_independent", r$n), fixed = TRUE, all = FALSE)
  pr <- simulate_power(sim_plan(test = "t_paired", effect = 0.5, r = 0.5), reps = 200, seed = 1)
  expect_match(capture.output(print(pr)), msg_for("sim_n", "t_paired", pr$n), fixed = TRUE, all = FALSE)
  expect_false(identical(msg_for("sim_n", "t_paired", 1), msg_for("sim_n", "t_independent", 1)))
  g <- simulate_power(sim_plan(effect = 0.5, dropout = 0.1), n = 30, reps = 200, seed = 1)
  expect_false("adjust" %in% g$notes)
})

test_that("random predictors are compared with DMAR power, without the target rule", {
  skip_on_cran(); skip_if_not(has_dmar())
  p <- reg_plan(0.30, 3)
  r <- simulate_power(p, predictor_type = "random", seed = 11)
  expect_identical(r$reference, "dmar")
  expect_identical(r$predictor_type, "random")
  expect_identical(r$status, "pass")
  expect_true("random" %in% r$notes)
  expect_lte(r$power_analytic, test_spec$reg_overall$power(30, p) - 0.02)
  out <- capture.output(print(r))
  expect_match(out, msg("sim_analytic_dmar", fmt_prob(round(r$power_analytic, 4))), fixed = TRUE, all = FALSE)
  expect_match(out, msg("sim_note_random"), fixed = TRUE, all = FALSE)
  # power is below the target here, so the target-claiming PASS sentence must not appear
  expect_match(out, msg("sim_pass_formula"), fixed = TRUE, all = FALSE)
  expect_false(any(grepl(msg("sim_pass"), out, fixed = TRUE)))
})

test_that("random predictors without DMAR and for reg_partial give no status", {
  skip_on_cran()
  local_mocked_bindings(has_dmar = function() FALSE)
  p <- reg_plan(0.30, 3)
  r <- simulate_power(p, predictor_type = "random", seed = 11)
  expect_true(is.na(r$status)); expect_true(is.na(r$pass))
  expect_identical(r$reference, "pwrss")
  expect_true("random_no_dmar" %in% r$notes)
  expect_equal(r$power_analytic, test_spec$reg_overall$power(30, p))
  expect_match(capture.output(print(r)), msg("sim_note_random_no_dmar"), fixed = TRUE, all = FALSE)
  r <- simulate_power(part_plan(), predictor_type = "random", seed = 11)
  expect_true(is.na(r$status))
  expect_true("random_partial" %in% r$notes)
  expect_match(capture.output(print(r)), msg("sim_note_random_partial"), fixed = TRUE, all = FALSE)
})

test_that("the chi-square pattern has a fixed w_max and refuses larger w", {
  expect_equal(c(w_max(2, 2), w_max(2, 3), w_max(3, 3), w_max(3, 4), w_max(5, 5), w_max(2, 5)),
               c(1, 0.8165, 0.6667, 0.6086, 0.5, 0.7071), tolerance = 1e-4)
  tb <- make_table(3, 4, 0.4)
  e <- outer(rowSums(tb), colSums(tb))
  expect_equal(sum(tb), 1)
  expect_equal(sqrt(sum((tb - e)^2 / e)), 0.4)
  big <- sim_plan(test = "chisq_indep", effect = 0.5, rows = 5, cols = 5)
  for (lang in c("en", "tr")) {
    withr::local_options(plansize.lang = lang)
    expect_error(simulate_power(big, reps = 200),
                 msg("err_sim_table", 5, 5, fmt_num(round(w_max(5, 5), 4)), fmt_num(0.5)), fixed = TRUE)
  }
})

test_that("fixed predictors are centred orthogonal columns with sum(x^2) = n", {
  withr::local_seed(1)
  x <- fixed_x(20, 3)
  expect_equal(colMeans(x), rep(0, 3))
  expect_equal(crossprod(x), diag(20, 3))
})

test_that("regression needs at least predictors + 2 participants", {
  expect_identical(simulate_power(reg_plan(0.05, 10), n = 12, reps = 200, seed = 1)$n, 12)
})

test_that("check_simulation refuses an edited predictor type, reference or note", {
  r <- simulate_power(reg_plan(0.13, 3), reps = 200, seed = 1)
  expect_identical(r$predictor_type, "fixed")
  bad <- function(f) expect_error(print(f(r)), msg("err_sim_obj", "x"), fixed = TRUE)
  bad(function(x) { x$predictor_type <- "mixed"; x })
  bad(function(x) { x$reference <- "gpower"; x })
  bad(function(x) { x$notes <- "other"; x })
  t <- simulate_power(sim_plan(effect = 0.5), reps = 200, seed = 1)
  bad(function(x) { t$predictor_type <- "random"; t })
  bad(function(x) { x$reference <- "dmar"; x })
  bad(function(x) { x$notes <- "random"; x })
})
