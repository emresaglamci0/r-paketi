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
#                                set explicitly (effect, effect_type, alternative, p1, p2). Returns list(effect, effect_test,
#                                extra) where `extra` are fields stored in the plan
#   n(p)                         analytic n per group; `p` = extra + effect_test, alpha,
#                                power, alternative
#   mde(n, plan, power)          smallest detectable effect, in the unit the user entered
#   effect_lines(plan)           effect lines for print(), in order
#   effect_sentence(plan, src, lang)  effect sentence of the methods text
#   variant(plan)                msg_for() suffixes, most specific first
#   check(plan)                  test-specific validity of a plan, TRUE or FALSE

# Shared by the two t tests: k and effect_type belong to the ANOVA only.
reject_anova_args <- function(a, given) {
  if (!is.null(a[["k"]])) fail("err_k_unused")
  if ("effect_type" %in% given) fail("err_effect_type_unused")
}

# Shared by every test except prop_two.
reject_p_args <- function(a) {
  if (!is.null(a[["p1"]]) || !is.null(a[["p2"]])) fail("err_p_unused")
}

t_extra <- function(a) {
  list(effect_type = NA_character_, k = NA_integer_, r = a[["r"]])
}

variant_plain <- function(plan) plan$test

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
      check_required(!"effect" %in% given, "effect")
      reject_p_args(a)
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
  )
)
