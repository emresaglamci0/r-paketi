# Dilim 4: eşli t testi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study(test = "t_paired", effect = d, r = r)` tekrarlı ölçüm (ön test - son test) için gerekli katılımcı sayısını, duyarlılığı, çıktıyı ve yöntem metnini verir.

**Architecture:** Testlere özgü farklar tek bir tabloda durur (`test_spec`). Motor, plan, duyarlılık ve metin bu tabloya bakar. Metinde teste özgü cümle varsa `<anahtar>_<test>` kullanılır, yoksa genel anahtar.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: `stats::power.t.test(type = "paired")`, `pwr::pwr.t.test(type = "paired")`.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde n'de ±1; aşılırsa dur.
- Düzeltme sırası değişmez: analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`.
- Bağımsız t testinin tüm sayıları ve davranışı aynı kalır.
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-4-paired`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- `design = "paired"` için `$n` tek sayı: dz=.5, güç=.80 → 33.36713. `stats` 33.3672, `pwr` 33.36713.
- Tek yönlü: 26.13751, `stats` ile aynı.
- n=34 için saptanabilir dz 0.4950281, `pwr` 0.4950459.
- Saptanabilir etki n=2 ve n=3'te "Design is not feasible.", n=4'te çalışıyor. dz=3 için n "not feasible".
- d = .5 için: r=.2 → dz 0.395, n 52.19; r=.5 → dz 0.500, n 33.37; r=.8 → dz 0.791, n 14.59 (`stats`).

## Kararlar (kullanıcı)

- Eşli tasarım yalnız tekrarlı ölçümdür: n = katılımcı sayısı, her katılımcı iki kez ölçülür. Eşleştirilmiş farklı kişiler kapsam dışı.
- Kullanıcı eşli testte d ve ön-son test korelasyonu `r` girer. Paket `dz = d / sqrt(2 * (1 - r))` ile dönüştürür. `r` eşli testte zorunlu, bağımsız testte verilirse hata.
- Türkçe ad: "bağımlı örneklemler t testi". Bağımsız testin adı değişmez.
- İngilizce giriş cümlesi test adını sona, paranteze alır.

## Kararlar (oluşturucu)

- `r` açık (-1, 1) aralığında. Sıfır ve negatif kabul edilir; dz küçülür, n büyür.
- Plan alanları: `effect` (girilen d), `r`, `effect_test` (motora giden değer; bağımsız testte `effect`, eşli testte dz), `groups`. `n_per_group` adını korur; eşli testte katılımcı sayısıdır. `n_total = groups × n_per_group`.
- Eşli duyarlılık sonucu d biriminde verilir, aynı `r` varsayılarak: `d = dz × sqrt(2 × (1 - r))`.
- Metinde ve yazdırmada dz iki ondalığa yuvarlanır. `fmt_prob()` negatif değeri de işler: `-.50`.

## Review Focus

- Bağımsız t testinin eski testleri yalnız `m_intro` cümlesi değişerek geçer.
- `sprintf` fazla argüman uyarısı vermez: eşli cümlelere toplam sayı geçirilmez.
- Eşli duyarlılıkta etkin n 4'ün altındaysa okunur hata, `pwrss` hatası değil.
- Elle değiştirilmiş plan (`effect_basis = "observed"`, `NULL`, bilinmeyen `test`) `print()`, `write_methods()` ve `sensitivity()` içinde `err_plan` verir.
- `r = 0` ve `r = -0.3` çalışır; `r = 1`, `r = NA`, eksik `r` okunur hata verir.

---

### Task 1: test tablosu, motor, plan, duyarlılık

**Files:**
- Create: `R/tests.R`, `tests/testthat/test-paired.R`
- Modify: `R/engine.R`, `R/plan.R`, `R/sensitivity.R`, `R/validate.R`, `inst/i18n/messages.csv`, ilgili testler

**Interfaces:**
- Produces:
  - `test_spec` (iç liste): `t_independent = list(design = "independent", groups = 2L, min_n = 3)`, `t_paired = list(design = "paired", groups = 1L, min_n = 4)`.
  - `engine_n(effect, alpha, power, alternative, design)` → `list(n, method)`; `n` tek sayı (`r$n[[length(r$n)]]`), `method = paste0("student_t_", design)`.
  - `engine_mde(n, alpha, power, alternative, design)` → motorun etki birimi (bağımsızda d, eşlide dz).
  - `plan_study(test, effect, r = NULL, effect_basis, effect_source, alpha, power, alternative, dropout, deff)`; dönüşe `r`, `effect_test`, `groups` eklenir.
  - `check_plan(x)` (iç, `R/validate.R`): `plansize_plan` değilse, `x$test` `test_spec` adlarında değilse ya da `x$effect_basis` `"observed"` dışındaki geçerli dayanaklardan değilse `fail("err_plan", "plan")`.
  - `sensitivity()` sonucu `attr(, "test")` taşır; `mde` girilen etkinin biriminde.

**Davranış**

- `test` `check_choice(test, names(test_spec), "test")` ile; `err_test` anahtarı silinir.
- `r`: eşli testte `check_required(is.null(r), "r")` ve açık (-1, 1) kontrolü; bağımsız testte `r` verilmişse `fail("err_r_unused")`.
- Taşma kontrolü `groups * n_raw` ile.
- `sensitivity()` `check_plan()` kullanır; eşik `test_spec[[plan$test]]$min_n`.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| err_n_small (değişir) | Effective n is below %2$s for n = %1$s after dropout and design effect. | n = %1$s için kayıp ve tasarım etkisi sonrası etkin n %2$s'ten küçük. |
| err_r | Argument 'r' must be a single number strictly between -1 and 1. | Argüman 'r' -1 ile 1 arasında (uç değerler hariç) tek bir sayı olmalı. |
| err_r_unused | Argument 'r' is used only with test = "t_paired". | Argüman 'r' yalnız test = "t_paired" ile kullanılır. |

- [ ] **Step 1: Başarısız testleri yaz (`test-paired.R`)**

```r
test_that("paired n matches independent references", {
  grid <- expand.grid(d = c(0.2, 0.5, 0.8), power = c(0.8, 0.9), alpha = c(0.05, 0.01))
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    n <- engine_n(g$d, g$alpha, g$power, "two.sided", "paired")$n
    ref <- stats::power.t.test(delta = g$d, sd = 1, sig.level = g$alpha, power = g$power, type = "paired")$n
    expect_lte(abs(n - ref), 1)
  }
  ref1 <- stats::power.t.test(delta = 0.5, sd = 1, power = 0.8, type = "paired", alternative = "one.sided")$n
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "one.sided", "paired")$n - ref1), 1)
  skip_if_not_installed("pwr")
  expect_equal(engine_mde(34, 0.05, 0.8, "two.sided", "paired"),
    pwr::pwr.t.test(n = 34, power = 0.8, type = "paired")$d, tolerance = 0.001)
})
test_that("d and r convert to dz and drive n", {
  for (r in c(0.2, 0.5, 0.8)) {
    p <- quiet_plan(test = "t_paired", effect = 0.5, r = r)
    dz <- 0.5 / sqrt(2 * (1 - r))
    expect_equal(p$effect_test, dz)
    ref <- stats::power.t.test(delta = dz, sd = 1, power = 0.8, type = "paired")$n
    expect_lte(abs(p$n_analytic - ref), 1)
  }
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.2)$n_per_group, 53L)
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.8)$n_per_group, 15L)
})
test_that("paired plan counts participants once", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(34L, 34L, 1L))
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1)$n_per_group, 38L)
  expect_identical(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, deff = 1.5, dropout = 0.1)$n_per_group, 56L)
})
test_that("independent plan is unchanged", {
  p <- quiet_plan(effect = 0.5)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(64L, 128L, 2L))
  expect_equal(p$effect_test, 0.5)
})
test_that("r is validated", {
  expect_error(plan_study(test = "t_paired", effect = 0.5), "'r'", fixed = TRUE)
  for (bad in list(1, -1, NA_real_, c(0.2, 0.5), "a")) {
    expect_error(plan_study(test = "t_paired", effect = 0.5, r = bad), "'r'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, r = 0.5), "t_paired", fixed = TRUE)
  expect_s3_class(quiet_plan(test = "t_paired", effect = 0.5, r = 0), "plansize_plan")
  expect_s3_class(quiet_plan(test = "t_paired", effect = 0.5, r = -0.3), "plansize_plan")
})
test_that("unknown test lists the supported tests", {
  expect_error(plan_study(test = "anova", effect = 0.5), "t_paired", fixed = TRUE)
})
test_that("paired limits give readable errors", {
  expect_identical(tryCatch(plan_study(test = "t_paired", effect = 3, r = 0.5), error = conditionMessage),
    msg("err_infeasible_plan"))
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expect_error(sensitivity(p, n = 3), "n = 3", fixed = TRUE)
  expect_true(is.numeric(sensitivity(p, n = 4)$mde))
})
test_that("paired sensitivity reports d under the same r", {
  skip_if_not_installed("pwr")
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.8)
  dz <- pwr::pwr.t.test(n = 34, power = 0.8, type = "paired")$d
  expect_equal(sensitivity(p, n = 34, power = 0.8)$mde, dz * sqrt(2 * (1 - 0.8)), tolerance = 0.001)
})
test_that("tampered plans are refused in sensitivity", {
  p <- quiet_plan(effect = 0.5)
  for (bad in list(list(effect_basis = "observed"), list(effect_basis = NULL), list(test = "anova"))) {
    q <- utils::modifyList(p, bad)
    class(q) <- class(p)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  }
})
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'paired')"`
Expected: FAIL.

- [ ] **Step 3: Kodu yaz, eski çağrıları ve testleri uyarla**

- [ ] **Step 4: Testleri çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"`
Expected: `FAIL 0 | WARN 0`.

---

### Task 2: çıktı ve yöntem metni

**Files:**
- Modify: `R/i18n.R`, `R/print.R`, `R/methods.R`, `inst/i18n/messages.csv`, `tests/testthat/test-print.R`, `tests/testthat/test-methods.R`, `tests/testthat/test-paired.R`

**Interfaces:**
- Consumes: `test_spec`, `check_plan()`, plan alanları `r`, `effect_test`, `groups`; sensitivity `attr(, "test")`.
- Produces: `msg_for(base, test, ..., lang = NULL)` (iç, `R/i18n.R`): `paste0(base, "_", test)` CSV'de varsa onu, yoksa `base` anahtarını kullanır.

**Davranış**

- `print.plansize_plan()` ve `write_methods()` başta `check_plan()` çağırır.
- Yazdırmada `groups == 1` ise toplam satırı yazılmaz; eşli testte `plan_r` ve `plan_dz` satırları etki satırından sonra yazılır.
- n satırı, duyarlılık başlığı ve sütun adları `msg_for()` ile.
- `write_methods()` eşli testte `m_result` ve `m_adjust_*` cümlelerine toplam sayıyı geçirmez. `m_effect_t_paired` sırasıyla d, kaynak, r, dz alır.
- `fmt_prob()` negatif değerde `-.30` verir. dz `fmt_num(round(dz, 2))` ile yazılır.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| m_intro (değişir) | An a priori power analysis was conducted in R with the plansize package (version %2$s), using pwrss (version %3$s), to determine the sample size required for the planned analysis (%1$s). | aynı kalır |
| val_t_paired | paired t test | bağımlı örneklemler t testi |
| plan_r | Correlation between the two measurements (r): %s | İki ölçüm arasındaki korelasyon (r): %s |
| plan_dz | Effect size used in the test (Cohen's dz): %s | Testte kullanılan etki büyüklüğü (Cohen dz): %s |
| plan_n_group_t_paired | Participants to recruit (each measured twice; includes dropout and design effect): %s | Alınması gereken katılımcı (her biri iki kez ölçülür; kayıp ve tasarım etkisi dahil): %s |
| sens_title_t_paired | Smallest detectable effect (Cohen's d, assuming the same r) | Saptanabilir en küçük etki (Cohen d, aynı r varsayılarak) |
| col_n_recruited_t_paired | Recruited participants | Alınan katılımcı |
| col_n_effective_t_paired | Effective participants | Etkin katılımcı |
| m_effect_t_paired | The effect size used for planning was Cohen's d = %s%s; with an assumed correlation of r = %s between the two measurements, this corresponds to dz = %s. | Planlamada etki büyüklüğü Cohen d = %s olarak alınmıştır%s; iki ölçüm arasındaki korelasyon r = %s varsayıldığında bu değer dz = %s olarak hesaplanmıştır. |
| m_result_t_paired | For a %s test with alpha = %s and power = %s, the required sample size was %s participants, each measured twice. | Alfa = %2$s, güç = %3$s ve %1$s test için gerekli örneklem büyüklüğü, her biri iki kez ölçülecek %4$s katılımcıdır. |
| m_adjust_dropout_t_paired | Allowing for an expected dropout rate of %s%%, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_deff_t_paired | Allowing for a design effect of %s, the recruitment target was %s participants. | Tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_both_t_paired | Allowing for an expected dropout rate of %s%% and a design effect of %s, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s ve tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |

- [ ] **Step 1: Başarısız testleri yaz**

`test-methods.R` içindeki tam İngilizce paragraf testinin ilk cümlesini şöyle yap: `"An a priori power analysis was conducted in R with the plansize package (version <ver>), using pwrss (version <pwrss>), to determine the sample size required for the planned analysis (independent two-sample t test). "`. `test-paired.R`'ye ekle:

```r
test_that("paired methods paragraph in English", {
  p <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expected <- paste0(
    "An a priori power analysis was conducted in R with the plansize package (version ",
    as.character(utils::packageVersion("plansize")), "), using pwrss (version ",
    p$engine_version, "), to determine the sample size required for the planned analysis ",
    "(paired t test). The effect size used for planning was Cohen's d = 0.50; with an ",
    "assumed correlation of r = .50 between the two measurements, this corresponds to ",
    "dz = 0.50. The rationale for choosing this effect size was not specified. For a ",
    "two-sided test with alpha = .05 and power = .80, the required sample size was ",
    "34 participants, each measured twice.")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  d <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1), lang = "en"))
  expect_match(d, "dropout rate of 10%, the recruitment target was 38 participants.", fixed = TRUE)
  n <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = -0.3), lang = "en"))
  expect_match(n, "r = -.30", fixed = TRUE)
  expect_match(n, "dz = 0.31", fixed = TRUE)
})
test_that("paired Turkish text and print", {
  x <- unclass(write_methods(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5, dropout = 0.1), lang = "tr"))
  expect_match(x, "ba\u011f\u0131ml\u0131 \u00f6rneklemler t testi i\u00e7in", fixed = TRUE)
  expect_match(x, "korelasyon r = .50", fixed = TRUE)
  expect_match(x, "her biri iki kez \u00f6l\u00e7\u00fclecek 34 kat\u0131l\u0131mc\u0131d\u0131r", fixed = TRUE)
  expect_match(x, "kat\u0131l\u0131mc\u0131 say\u0131s\u0131 38 olarak", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5))))
  expect_true(any(grepl("(r): 0.5", out, fixed = TRUE)))
  expect_true(any(grepl("dz", out, fixed = TRUE)))
  expect_false(any(grepl("Total", out, fixed = TRUE)))
  s <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(sensitivity(quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)))))
  expect_true(any(grepl("Recruited participants", s, fixed = TRUE)))
  expect_true(any(grepl("assuming the same r", s, fixed = TRUE)))
})
test_that("tampered plans are refused in print and methods", {
  q <- quiet_plan(effect = 0.5); q$effect_basis <- "observed"
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
```

`dz = 0.31`: d = .5, r = -.3 için dz = 0.5 / sqrt(2.6) = 0.3101.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'paired|methods|print')"`
Expected: FAIL.

- [ ] **Step 3: `msg_for()`, yazdırma ve metin değişikliklerini yap**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan paired t test`).
