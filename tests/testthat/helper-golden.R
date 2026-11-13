# Plans and bad calls behind tests/testthat/fixtures/golden.rds (built by dev/make-golden.R).
golden_plans <- function() {
  b <- function(...) quiet_plan(effect_basis = "pilot", ...)
  list(
    ind_basic = b(effect = 0.5),
    ind_adjusted = b(effect = 0.3, dropout = 0.1, deff = 1.5, effect_source = "Yilmaz, 2021"),
    ind_one_sided = b(effect = 0.5, alternative = "one.sided"),
    paired_basic = b(test = "t_paired", effect = 0.5, r = 0.5),
    paired_neg_r = b(test = "t_paired", effect = 0.5, r = -0.3, dropout = 0.1),
    anova_f = b(test = "anova_oneway", effect = 0.25, k = 3),
    anova_eta2 = b(test = "anova_oneway", effect = 0.06, k = 4, effect_type = "eta2",
                   dropout = 0.1, deff = 1.3)
  )
}

golden_errors <- function() {
  calls <- list(
    effect_zero = function() plan_study(effect = 0, effect_basis = "pilot"),
    bad_test = function() plan_study(test = "anova", effect = 0.5, effect_basis = "pilot"),
    paired_no_r = function() plan_study(test = "t_paired", effect = 0.5, effect_basis = "pilot"),
    anova_k1 = function() plan_study(test = "anova_oneway", effect = 0.25, k = 1,
                                     effect_basis = "pilot"),
    observed = function() plan_study(effect = 0.5, effect_basis = "observed")
  )
  out <- list()
  for (lang in c("en", "tr")) {
    old <- options(plansize.lang = lang)
    for (nm in names(calls)) {
      out[[paste(nm, lang, sep = "_")]] <- tryCatch(calls[[nm]](), error = conditionMessage)
    }
    options(old)
  }
  out
}

golden_build <- function() {
  plans <- golden_plans()
  parts <- lapply(plans, function(p) {
    sens <- sensitivity(p)
    old <- options(plansize.lang = "en"); on.exit(options(old))
    en <- capture.output(print(p)); sen <- capture.output(print(sens))
    options(plansize.lang = "tr")
    list(fields = unclass(p), print_en = en, print_tr = capture.output(print(p)),
         sens = unclass(sens), sens_print_en = sen, sens_print_tr = capture.output(print(sens)),
         methods_en = unclass(write_methods(p, lang = "en")),
         methods_tr = unclass(write_methods(p, lang = "tr")))
  })
  list(plans = parts, errors = golden_errors())
}
