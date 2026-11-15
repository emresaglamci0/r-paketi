# Per-test differences live here. plan_study, sensitivity, print, write_methods and
# check_plan call these functions and never branch on the test name themselves.
#
# Each entry has:
#   directional                  FALSE if the test has no one/two-sided choice
#   groups(a)                    number of groups; `a` holds the prepared fields (k)
#   min_n                        smallest effective n per group sensitivity() accepts
#   method                       name stored in plan$method
#   prepare(a, given)            validate test-specific arguments in the documented order;
#                                `a` = plan_study() arguments (`effect` only when given, so read
#                                it with a[["effect"]]), `given` = names of arguments the user
#                                set explicitly (effect, effect_type, alternative, p1, p2, rows, cols). Returns list(effect, effect_test,
#                                extra) where `extra` are fields stored in the plan
#   n(p)                         analytic n per group; `p` = extra + effect_test, alpha,
#                                power, alternative
#   mde(n, plan, power)          smallest detectable effect, in the unit the user entered
#   effect_lines(plan)           effect lines for print(), in order
#   info_lines(plan)             optional extra print() lines (character or NULL)
#   effect_sentence(plan, src, lang)  effect sentence of the methods text
#   variant(plan)                msg_for() suffixes, most specific first
#   check(plan)                  test-specific validity of a plan, TRUE or FALSE
#   power(n, plan)               analytic power at n (n per group, or total for one-sample tests)
#   simulate(n, plan)            function() that draws one study and returns its p value;
#                                regressions read plan$predictor_type ("fixed" or "random")

# Shared by the two t tests: k and effect_type belong to the ANOVA only.
reject_anova_args <- function(a, given) {
  reject_partial_args(a)
  if (!is.null(a[["k"]])) fail("err_k_unused")
  if ("effect_type" %in% given) fail("err_effect_type_unused")
  reject_predictors(a)
  reject_table_args(given)
}

# predictors belongs to reg_overall and reg_partial only.
reject_predictors <- function(a) {
  if (!is.null(a[["predictors"]])) fail("err_predictors_unused")
}

# tested and r2_covariates belong to reg_partial only.
reject_partial_args <- function(a) {
  if (!is.null(a[["tested"]]) || !is.null(a[["r2_covariates"]])) fail("err_partial_unused")
}

# rows and cols belong to chisq_indep only.
reject_table_args <- function(given) {
  if (any(c("rows", "cols") %in% given)) fail("err_table_unused")
}

# Shared by every test except prop_two.
reject_p_args <- function(a) {
  if (!is.null(a[["p1"]]) || !is.null(a[["p2"]])) fail("err_p_unused")
}

t_extra <- function(a) {
  list(effect_type = NA_character_, k = NA_integer_, r = a[["r"]])
}

# Direction of a one-sided simulated test: "greater" when the planned effect `sign` is positive.
sim_alt <- function(plan, sign) {
  if (plan$alternative == "one.sided") (if (sign > 0) "greater" else "less") else "two.sided"
}

# Chi-square cells: equal margins plus an outer-product pattern give Cohen's w exactly.
# The cells stay positive only below w_max, a limit of this pattern, not of the table.
chisq_pattern <- function(rows, cols) {
  m <- outer(seq_len(rows) - (rows + 1) / 2, seq_len(cols) - (cols + 1) / 2)
  m / sqrt(sum(m^2))
}
w_max <- function(rows, cols) 1 / (sqrt(rows * cols) * max(abs(chisq_pattern(rows, cols))))
make_table <- function(rows, cols, w) 1 / (rows * cols) + w / sqrt(rows * cols) * chisq_pattern(rows, cols)

# Centred orthogonal columns with sum(x^2) = n: the F test's ncp is then f2 * n, as in pwrss.
fixed_x <- function(n, k) qr.Q(qr(scale(matrix(stats::rnorm(n * k), n), scale = FALSE))) * sqrt(n)

# F test of the first u of k predictors. Signal variances: `sig` for the tested slopes, `cov` for
# the others; error variance 1. Fixed X is built once per call, random X in every study.
sim_reg <- function(n, plan, k, u, sig, cov) {
  b <- c(rep(sqrt(sig / u), u), rep(sqrt(cov / (k - u)), k - u))
  random <- identical(plan$predictor_type, "random")
  x0 <- if (!random) fixed_x(n, k)
  function() {
    x <- cbind(1, if (random) matrix(stats::rnorm(n * k), n) else x0)
    y <- drop(x[, -1, drop = FALSE] %*% b) + stats::rnorm(n)
    rss <- sum(qr.resid(qr(x), y)^2)
    rss0 <- sum(qr.resid(qr(x[, -(seq_len(u) + 1), drop = FALSE]), y)^2)  # without the tested columns
    stats::pf((rss0 - rss) / u / (rss / (n - k - 1)), u, n - k - 1, lower.tail = FALSE)
  }
}

variant_plain <- function(plan) plan$test

variant_reg <- function(plan) {
  if (identical(plan$effect_type, "f2")) c(paste0(plan$test, "_f2"), plan$test) else plan$test
}

variant_anova <- function(plan) {
  if (identical(plan$effect_type, "eta2")) c(paste0(plan$test, "_eta2"), plan$test) else plan$test
}

test_spec <- list(
  t_independent = list(
    directional = TRUE, min_n = 3, method = "student_t_independent",
    groups = function(a) 2L,
    prepare = function(a, given) {
      check_required(!"effect" %in% given, "effect")
      reject_anova_args(a, given)
      reject_p_args(a)
      check_positive_number(a[["effect"]], "effect")
      if (!is.null(a[["r"]])) fail("err_r_unused")
      list(effect = a[["effect"]], effect_test = a[["effect"]], extra = t_extra(a))
    },
    n = function(p) engine_n(p$effect_test, p$alpha, p$power, p$alternative, "independent")$n,
    power = function(n, plan) engine_power_t(n, plan$effect_test, plan$alpha, plan$alternative, "independent"),
    simulate = function(n, plan) {
      d <- plan$effect_test; alt <- sim_alt(plan, 1)
      function() stats::t.test(stats::rnorm(n, d), stats::rnorm(n), var.equal = TRUE, alternative = alt)$p.value
    },
    mde = function(n, plan, power) {
      engine_mde(n, plan$alpha, power, plan$alternative, "independent")
    },
    effect_lines = function(plan) msg_for("plan_effect", plan$test, format(plan$effect)),
    effect_sentence = function(plan, src, lang) {
      msg_for("m_effect", plan$test, fmt_num(plan$effect), src, lang = lang)
    },
    variant = variant_plain,
    check = function(plan) TRUE
  ),
  t_paired = list(
    directional = TRUE, min_n = 4, method = "student_t_paired",
    groups = function(a) 1L,
    prepare = function(a, given) {
      check_required(!"effect" %in% given, "effect")
      reject_anova_args(a, given)
      reject_p_args(a)
      check_positive_number(a[["effect"]], "effect")
      r <- a[["r"]]
      check_required(is.null(r), "r")
      if (!is_num1(r) || r <= -1 || r >= 1) fail("err_r")
      list(effect = a[["effect"]], effect_test = a[["effect"]] / sqrt(2 * (1 - r)), extra = t_extra(a))
    },
    n = function(p) engine_n(p$effect_test, p$alpha, p$power, p$alternative, "paired")$n,
    power = function(n, plan) engine_power_t(n, plan$effect_test, plan$alpha, plan$alternative, "paired"),
    # d is the mean change over the SD of one measurement; y - x then has SD sqrt(2 * (1 - r)).
    simulate = function(n, plan) {
      d <- plan$effect; r <- plan$r; alt <- sim_alt(plan, 1)
      function() {
        x <- stats::rnorm(n)
        y <- d + r * x + sqrt(1 - r^2) * stats::rnorm(n)
        stats::t.test(y, x, paired = TRUE, alternative = alt)$p.value
      }
    },
    # Paired engine returns dz; report d under the plan's r.
    mde = function(n, plan, power) {
      engine_mde(n, plan$alpha, power, plan$alternative, "paired") * sqrt(2 * (1 - plan$r))
    },
    effect_lines = function(plan) c(
      msg_for("plan_effect", plan$test, format(plan$effect)),
      msg("plan_r", format(plan$r)),
      msg("plan_dz", fmt_num(round(plan$effect_test, 2)))),
    effect_sentence = function(plan, src, lang) {
      msg_for("m_effect", plan$test, fmt_num(plan$effect), src, fmt_prob(plan$r),
              fmt_num(round(plan$effect_test, 2)), lang = lang)
    },
    variant = variant_plain,
    check = function(plan) is_num1(plan$r) && plan$r > -1 && plan$r < 1 && is_num1(plan$effect_test)
  ),
  anova_oneway = list(
    directional = FALSE, min_n = 2, method = "f_oneway_anova",
    groups = function(a) a[["k"]],
    prepare = function(a, given) {
      reject_partial_args(a)
      check_required(!"effect" %in% given, "effect")
      reject_p_args(a)
      reject_predictors(a)
      reject_table_args(given)
      k <- a[["k"]]
      if (!is_num1(k) || k < 2 || k != round(k) || k > .Machine$integer.max) fail("err_k")
      k <- as.integer(k)
      effect_type <- check_choice(a$effect_type, c("f", "eta2"), "effect_type")
      effect <- a[["effect"]]
      if (effect_type == "eta2") {
        if (!is_num1(effect) || effect <= 0 || effect >= 1) fail("err_eta2")
      } else {
        check_positive_number(effect, "effect")
      }
      if ("alternative" %in% given) fail("err_alt_anova")
      if (!is.null(a[["r"]])) fail("err_r_unused")
      list(effect = effect,
           effect_test = if (effect_type == "eta2") sqrt(effect / (1 - effect)) else effect,
           extra = list(effect_type = effect_type, k = k, r = a[["r"]]))
    },
    n = function(p) engine_n(p$effect_test, p$alpha, p$power, NULL, "anova", p[["k"]])$n,
    power = function(n, plan) engine_power_anova(n, plan$k, plan$effect_test, plan$alpha),
    # Equally spaced group means scaled so that their SD (denominator k) equals f.
    simulate = function(n, plan) {
      k <- plan$k; mu <- seq(-1, 1, length.out = k)
      mu <- rep(mu / sqrt(mean(mu^2)) * plan$effect_test, each = n); g <- gl(k, n)
      function() stats::oneway.test(mu + stats::rnorm(k * n) ~ g, var.equal = TRUE)$p.value
    },
    # ANOVA engine returns f; report in the unit the user entered.
    mde = function(n, plan, power) {
      f <- engine_mde(n, plan$alpha, power, NULL, "anova", plan[["k"]])
      if (plan$effect_type == "eta2") f^2 / (1 + f^2) else f
    },
    effect_lines = function(plan) {
      eta2 <- identical(plan$effect_type, "eta2")
      c(msg("plan_k", plan$k),
        msg_for("plan_effect", variant_anova(plan), fmt_num(plan$effect)),
        if (eta2) msg("plan_f", fmt_num(round(plan$effect_test, 2))))
    },
    effect_sentence = function(plan, src, lang) {
      v <- variant_anova(plan)
      args <- c(list("m_effect", v, fmt_num(plan$effect), src, plan$k),
                if (v[1] != plan$test) list(fmt_num(round(plan$effect_test, 2))),
                list(lang = lang))
      do.call(msg_for, args)
    },
    variant = variant_anova,
    check = function(plan) {
      k <- plan[["k"]]
      is_num1(k) && k >= 2 && k == round(k) && k <= .Machine$integer.max &&
        identical(as.numeric(plan$groups), as.numeric(k)) &&
        is.character(plan$effect_type) && length(plan$effect_type) == 1L &&
        plan$effect_type %in% c("f", "eta2") && is_num1(plan$effect_test) && plan$effect_test > 0
    }
  ),
  prop_two = list(
    directional = TRUE, min_n = 2, method = "z_two_props_pooled",
    groups = function(a) 2L,
    prepare = function(a, given) {
      if ("effect" %in% given) fail("err_effect_unused")
      reject_anova_args(a, given)
      if (!is.null(a[["r"]])) fail("err_r_unused")
      p1 <- a[["p1"]]; p2 <- a[["p2"]]
      check_required(is.null(p1), "p1")
      check_required(is.null(p2), "p2")
      if (!is_prob1(p1) || !is_prob1(p2)) fail("err_p")
      if (p1 == p2) fail("err_p_equal")
      list(effect = NA_real_, effect_test = p1 - p2,
           extra = list(effect_type = NA_character_, k = NA_integer_, p1 = p1, p2 = p2))
    },
    n = function(p) engine_n_props(p$p1, p$p2, p$alpha, p$power, p$alternative),
    power = function(n, plan) engine_power_props(n, plan$p1, plan$p2, plan$alpha, plan$alternative),
    simulate = function(n, plan) {
      p1 <- plan$p1; p2 <- plan$p2; alt <- sim_alt(plan, p1 - p2)
      function() stats::prop.test(c(stats::rbinom(1, n, p1), stats::rbinom(1, n, p2)), c(n, n),
        correct = FALSE, alternative = alt)$p.value
    },
    # Detectable p1 with p2 fixed, searched in the direction of the planned difference.
    mde = function(n, plan, power) {
      engine_mde_props(n, plan$p2, plan$p1 > plan$p2, plan$alpha, power, plan$alternative)
    },
    effect_lines = function(plan) c(
      msg("plan_p1", format(plan$p1)),
      msg("plan_p2", format(plan$p2)),
      msg("plan_pdiff", format(plan$p1 - plan$p2))),
    effect_sentence = function(plan, src, lang) {
      msg_for("m_effect", plan$test, fmt_prob(plan$p1), fmt_prob(plan$p2), src,
              fmt_prob(plan$p1 - plan$p2), lang = lang)
    },
    variant = variant_plain,
    check = function(plan) {
      is_prob1(plan[["p1"]]) && is_prob1(plan[["p2"]]) && plan$p1 != plan$p2 &&
        isTRUE(all.equal(plan$effect_test, plan$p1 - plan$p2)) && identical(as.numeric(plan$groups), 2)
    }
  ),
  cor_pearson = list(
    directional = TRUE, min_n = 4, method = "fisher_z_cor",
    groups = function(a) 1L,
    prepare = function(a, given) {
      if (!is.null(a[["r"]])) fail("err_r_cor")
      check_required(!"effect" %in% given, "effect")
      effect <- a[["effect"]]
      if (!is_num1(effect) || abs(effect) >= 1 || effect == 0) fail("err_cor_effect")
      reject_anova_args(a, given)
      reject_p_args(a)
      list(effect = effect, effect_test = effect,
           extra = list(effect_type = NA_character_, k = NA_integer_, r = NULL))
    },
    n = function(p) engine_n_cor(p$effect_test, p$alpha, p$power, p$alternative),
    power = function(n, plan) engine_power_cor(n, plan$effect, plan$alpha, plan$alternative),
    simulate = function(n, plan) {
      rho <- plan$effect; alt <- sim_alt(plan, rho)
      function() {
        x <- stats::rnorm(n)
        stats::cor.test(x, rho * x + sqrt(1 - rho^2) * stats::rnorm(n), alternative = alt)$p.value
      }
    },
    # Detectable r keeps the sign of the planned correlation.
    mde = function(n, plan, power) {
      engine_mde_cor(n, sign(plan$effect), plan$alpha, power, plan$alternative)
    },
    effect_lines = function(plan) msg_for("plan_effect", plan$test, format(plan$effect)),
    effect_sentence = function(plan, src, lang) {
      msg_for("m_effect", plan$test, fmt_prob(plan$effect), src, lang = lang)
    },
    # One-sided text states H1; the sensitivity table passes no alternative or effect.
    variant = function(plan) {
      if (identical(plan$alternative, "one.sided") && is_num1(plan$effect)) {
        c(paste0(plan$test, if (plan$effect > 0) "_pos" else "_neg"), plan$test)
      } else plan$test
    },
    check = function(plan) {
      is_num1(plan$effect_test) && abs(plan$effect_test) < 1 && plan$effect_test != 0 &&
        identical(plan$effect, plan$effect_test) && identical(as.numeric(plan$groups), 1) &&
        is.null(plan[["r"]]) && isTRUE(is.na(plan[["k"]])) && isTRUE(is.na(plan[["effect_type"]]))
    }
  ),
  chisq_indep = list(
    directional = FALSE, min_n = 2, method = "chisq_indep_w",
    groups = function(a) 1L,
    prepare = function(a, given) {
      reject_partial_args(a)
      check_required(!"effect" %in% given, "effect")
      effect <- a[["effect"]]
      if (!is_num1(effect) || effect <= 0 || effect > 1) fail("err_w")
      rows <- a[["rows"]]; cols <- a[["cols"]]
      ok_dim <- function(x) is_num1(x) && x == round(x) && x >= 2 && x <= 1000
      if (!ok_dim(rows) || !ok_dim(cols)) fail("err_table")
      rows <- as.integer(rows); cols <- as.integer(cols)
      if (!is.null(a[["k"]])) fail("err_k_unused")
      if ("effect_type" %in% given) fail("err_effect_type_unused")
      reject_p_args(a)
      reject_predictors(a)
      if ("alternative" %in% given) fail("err_alt_chisq")
      if (!is.null(a[["r"]])) fail("err_r_unused")
      list(effect = effect, effect_test = effect,
           extra = list(effect_type = NA_character_, k = NA_integer_, r = NULL,
                        rows = rows, cols = cols, df = as.integer((rows - 1) * (cols - 1))))
    },
    n = function(p) engine_n_chisq(p$effect_test, p$df, p$alpha, p$power),
    power = function(n, plan) engine_power_chisq(n, plan$effect_test, plan$df, plan$alpha),
    # >= : at w_max the smallest cell can be a tiny negative number in floating point.
    simulate = function(n, plan) {
      r <- plan$rows; cc <- plan$cols; wm <- w_max(r, cc)
      if (plan$effect >= wm) fail("err_sim_table", r, cc, fmt_num(round(wm, 4)), fmt_num(plan$effect))
      p <- make_table(r, cc, plan$effect)
      function() stats::chisq.test(matrix(stats::rmultinom(1, n, p), r), correct = FALSE)$p.value
    },
    mde = function(n, plan, power) engine_mde_chisq(n, plan$df, plan$alpha, power),
    effect_lines = function(plan) c(
      msg_for("plan_effect", plan$test, format(plan$effect)),
      msg("plan_table", plan$rows, plan$cols, plan$df)),
    effect_sentence = function(plan, src, lang) {
      msg_for("m_effect", plan$test, fmt_num(plan$effect), src, plan$rows, plan$cols, plan$df, lang = lang)
    },
    variant = variant_plain,
    check = function(plan) {
      ok_dim <- function(x) is.integer(x) && length(x) == 1L && !is.na(x) && x >= 2L && x <= 1000L
      is_num1(plan$effect_test) && plan$effect_test > 0 && plan$effect_test <= 1 &&
        identical(plan$effect, plan$effect_test) && identical(as.numeric(plan$groups), 1) &&
        ok_dim(plan[["rows"]]) && ok_dim(plan[["cols"]]) &&
        identical(plan[["df"]], as.integer((plan$rows - 1L) * (plan$cols - 1L))) &&
        is.null(plan[["r"]]) && isTRUE(is.na(plan[["k"]])) && isTRUE(is.na(plan[["effect_type"]]))
    }
  ),
  reg_overall = list(
    directional = FALSE, min_n = 3, method = "f_reg_overall_r2",
    groups = function(a) 1L,
    prepare = function(a, given) {
      reject_partial_args(a)
      check_required(!"effect" %in% given, "effect")
      # The signature default is for the ANOVA; here the choice must be explicit and exact.
      if (!"effect_type" %in% given || length(a$effect_type) != 1L) fail("err_effect_type_reg")
      effect_type <- check_choice(a$effect_type, c("r2", "f2"), "effect_type", exact = TRUE)
      effect <- a[["effect"]]
      if (effect_type == "r2") {
        if (!is_num1(effect) || effect <= 0 || effect > 0.99) fail("err_r2")
      } else if (!is_num1(effect) || effect <= 0 || effect > 99) fail("err_f2")
      k <- a[["predictors"]]
      if (!is_num1(k) || k < 1 || k > 1000 || k != round(k)) fail("err_predictors")
      if ("alternative" %in% given) fail("err_alt_reg")
      if (!is.null(a[["k"]])) fail("err_k_unused")
      reject_table_args(given)
      reject_p_args(a)
      if (!is.null(a[["r"]])) fail("err_r_unused")
      list(effect = effect,
           effect_test = if (effect_type == "f2") effect / (1 + effect) else effect,
           extra = list(effect_type = effect_type, k = NA_integer_, r = NULL, predictors = as.integer(k)))
    },
    n = function(p) engine_n_reg(p$effect_test, p$predictors, p$alpha, p$power),
    power = function(n, plan) engine_power_reg(n, plan$effect_test, plan$predictors, plan$alpha),
    simulate = function(n, plan) {
      sim_reg(n, plan, plan$predictors, plan$predictors, plan$effect_test / (1 - plan$effect_test), 0)
    },
    # Engine returns R-squared; report in the unit the user entered.
    mde = function(n, plan, power) {
      r2 <- engine_mde_reg(n, plan$predictors, plan$alpha, power)
      if (plan$effect_type == "f2") r2 / (1 - r2) else r2
    },
    effect_lines = function(plan) c(
      msg_for("plan_effect", variant_reg(plan), fmt_num(plan$effect)),
      if (plan$effect_type == "f2") msg("plan_r2", fmt_num(round(plan$effect_test, 2))),
      msg("plan_predictors", plan$predictors)),
    effect_sentence = function(plan, src, lang) {
      args <- if (plan$effect_type == "f2") list(fmt_num(plan$effect), src, fmt_num(round(plan$effect_test, 2)), plan$predictors)
              else list(fmt_num(plan$effect), src, plan$predictors)
      do.call(msg_for, c(list("m_effect", variant_reg(plan)), args, list(lang = lang)))
    },
    info_lines = function(plan) {
      n <- random_predictor_n(plan)
      if (!is.null(n)) msg("plan_random_n", n)
    },
    variant = variant_reg,
    check = function(plan) {
      k <- plan[["predictors"]]
      is.integer(k) && length(k) == 1L && !is.na(k) && k >= 1L && k <= 1000L &&
        is.character(plan$effect_type) && length(plan$effect_type) == 1L && plan$effect_type %in% c("r2", "f2") &&
        is_num1(plan$effect_test) && plan$effect_test > 0 && plan$effect_test <= 0.99 && is_num1(plan$effect) &&
        (if (plan$effect_type == "r2") identical(plan$effect, plan$effect_test)
         else isTRUE(all.equal(plan$effect_test, plan$effect / (1 + plan$effect)))) &&
        identical(as.numeric(plan$groups), 1) && is.null(plan[["r"]]) && isTRUE(is.na(plan[["k"]]))
    }
  ),
  # F test of the R-squared change from `tested` of `predictors` predictors. pwrss gets the
  # partial R-squared (see ?plan_study), so effect_test is always the partial R-squared.
  reg_partial = list(
    directional = FALSE, min_n = 3, method = "f_reg_partial_r2",
    groups = function(a) 1L,
    prepare = function(a, given) {
      check_required(!"effect" %in% given, "effect")
      if (!"effect_type" %in% given || length(a$effect_type) != 1L) fail("err_effect_type_reg_partial")
      effect_type <- check_choice(a$effect_type, c("r2_change", "f2"), "effect_type", exact = TRUE)
      effect <- a[["effect"]]
      cov <- a[["r2_covariates"]]
      if (effect_type == "f2") {
        if (!is_num1(effect) || effect <= 0 || effect > 99) fail("err_f2")
      } else if (!is_num1(effect) || effect <= 0 || effect > 0.99) fail("err_r2_change")
      k <- a[["predictors"]]
      if (!is_num1(k) || k < 1 || k > 1000 || k != round(k)) fail("err_predictors")
      u <- a[["tested"]]
      if (!is_num1(u) || u < 1 || u != round(u) || u >= k) fail("err_tested")
      if (effect_type == "f2") {
        if (!is.null(cov)) fail("err_r2cov_unused")
      } else if (!is_num1(cov) || cov < 0 || cov >= 1 || effect + cov > 0.99) fail("err_r2cov")
      if ("alternative" %in% given) fail("err_alt_reg")
      if (!is.null(a[["k"]])) fail("err_k_unused")
      reject_table_args(given)
      reject_p_args(a)
      if (!is.null(a[["r"]])) fail("err_r_unused")
      f2 <- effect_type == "f2"
      list(effect = effect, effect_test = if (f2) effect / (1 + effect) else effect / (1 - cov),
           extra = list(effect_type = effect_type, k = NA_integer_, r = NULL, predictors = as.integer(k),
                        tested = as.integer(u), r2_covariates = if (f2) NA_real_ else cov))
    },
    n = function(p) engine_n_reg(p$effect_test, p$predictors, p$alpha, p$power, p$tested),
    power = function(n, plan) engine_power_reg(n, plan$effect_test, plan$predictors, plan$alpha, plan$tested),
    # Built from the R-squared change and the covariate R-squared, not from effect_test, so the
    # partial R-squared conversion is checked independently. With f2 the covariates carry no signal.
    simulate = function(n, plan) {
      k <- plan$predictors; u <- plan$tested
      if (plan$effect_type == "f2") return(sim_reg(n, plan, k, u, plan$effect, 0))
      full <- plan$effect + plan$r2_covariates
      sim_reg(n, plan, k, u, plan$effect / (1 - full), plan$r2_covariates / (1 - full))
    },
    # Engine returns the partial R-squared; report in the unit the user entered.
    mde = function(n, plan, power) {
      r2 <- engine_mde_reg(n, plan$predictors, plan$alpha, power, plan$tested)
      if (plan$effect_type == "f2") r2 / (1 - r2) else r2 * (1 - plan$r2_covariates)
    },
    effect_lines = function(plan) {
      part <- plan$effect_test
      c(msg_for("plan_effect", variant_reg(plan), fmt_num(plan$effect)),
        if (plan$effect_type == "f2") msg("plan_tested_f2", plan$tested, plan$predictors)
        else c(msg("plan_tested", plan$tested, plan$predictors, fmt_num(plan$r2_covariates)),
               msg("plan_partial", fmt_num(round(part, 2)), fmt_num(round(part / (1 - part), 2)))))
    },
    effect_sentence = function(plan, src, lang) {
      eff <- fmt_num(plan$effect)
      args <- if (plan$effect_type == "f2") list(eff, src, fmt_num(round(plan$effect_test, 2)), plan$tested, plan$predictors)
              else list(eff, src, plan$tested, plan$predictors, fmt_num(plan$r2_covariates))
      do.call(msg_for, c(list("m_effect", variant_reg(plan)), args, list(lang = lang)))
    },
    variant = variant_reg,
    check = function(plan) {
      k <- plan[["predictors"]]; u <- plan[["tested"]]; cov <- plan[["r2_covariates"]]
      f2 <- identical(plan$effect_type, "f2")
      is.integer(k) && length(k) == 1L && !is.na(k) && k >= 2L && k <= 1000L &&
        is.integer(u) && length(u) == 1L && !is.na(u) && u >= 1L && u < k &&
        is.character(plan$effect_type) && length(plan$effect_type) == 1L &&
        plan$effect_type %in% c("r2_change", "f2") && is_num1(plan$effect) &&
        is_num1(plan$effect_test) && plan$effect_test > 0 && plan$effect_test <= 0.99 &&
        (if (f2) is.numeric(cov) && length(cov) == 1L && is.na(cov) &&
                 isTRUE(all.equal(plan$effect_test, plan$effect / (1 + plan$effect)))
         else is_num1(cov) && cov >= 0 && cov < 1 &&
              isTRUE(all.equal(plan$effect_test, plan$effect / (1 - cov)))) &&
        identical(as.numeric(plan$groups), 1) && is.null(plan[["r"]]) && isTRUE(is.na(plan[["k"]]))
    }
  )
)
