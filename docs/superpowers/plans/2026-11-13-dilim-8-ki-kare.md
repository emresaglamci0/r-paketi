# Dilim 8: ki-kare bağımsızlık testi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study(test = "chisq_indep", effect = w, rows = , cols = )` iki kategorik değişken arasındaki ilişki için gerekli toplam katılımcı sayısını, duyarlılığı, çıktıyı ve yöntem metnini verir.

**Architecture:** `test_spec`'e `chisq_indep` satırı eklenir; motor `pwrss::power.chisq.gof` çağırır (w ve serbestlik derecesiyle, bağımsızlık testi için aynı hesap). Başka dosyaya teste özgü dal eklenmez.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: `pwr::pwr.chisq.test` (aynı yöntem).

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde n'de ±1; aşılırsa dur.
- Düzeltme sırası: analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`.
- Eski beş testin çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-8-chisq`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- `power.chisq.gof(w, null.w = 0, df, n, power, alpha, ceil.n, verbose)`; `$n` ondalıklı toplam n. `power.chisq.test` başka bir (ncp tabanlı) fonksiyondur, kullanılmaz.
- Güç .80: w .30, sd 1 → 87.2096 (`pwr` 87.2095); sd 2 → 107.0521; sd 4 → 132.6143. w .10 sd 1 → 784.886; w .50 sd 1 → 31.395. `pwr` ile birebir.
- n = 108, sd 2 için saptanabilir w 0.29869 (`pwr` 0.29868). n = 3 ve 5'te "Design is not feasible."; n = 10 → 0.98.
- `pwrss` w > 1 kabul etmez ("does not have a valid proportion value").

## Kararlar (kullanıcı)

- Etki yalnız Cohen w ile girilir.
- Tablo boyutu `rows` ve `cols` ile girilir; serbestlik derecesi paket tarafından hesaplanır: `(rows - 1) * (cols - 1)`.
- Yalnız bağımsızlık testi; uyum iyiliği kapsam dışı. n = toplam katılımcı.
- Türkçe ad: "ki-kare bağımsızlık testi".
- Beklenen hücre sayısı uyarısı eklenmez.

## Kararlar (oluşturucu)

- Test adı `chisq_indep`. `effect` (w) açık-kapalı (0, 1] aralığında.
- `rows`, `cols`: tek tam sayı, en az 2, en çok 1000.
- `r`, `k`, `effect_type`, `p1`, `p2` bu testte verilirse hata; `rows`, `cols` başka testte verilirse hata.
- Test yönsüzdür (`directional = FALSE`); `alternative` açıkça verilirse ANOVA'daki gibi hata.
- Tek grup: `groups` 1, `n_total = n`, `min_n = 2`; küçük n'de `pwrss`'in "not feasible" hatası `err_infeasible`'a çevrilir.

## Review Focus

- `rows`/`cols` değiştirilince n değişir, w aynı kalınca serbestlik derecesi büyüdükçe n artar.
- `effect = 0`, `1.2`, `rows = 1`, `cols = 2.5` okunur hata verir; `effect = 1` kabul edilir.
- Çok küçük w (ör. 1e-5) ham `pwrss` hatası değil okunur hata verir.
- Kaynak verildiğinde metinde iç içe ya da art arda parantez yok.
- Elle bozulmuş `chisq_indep` planı (`rows` silinmiş, `rows = 1`) her fonksiyonda `err_plan` verir.

---

### Task 1: ki-kare bağımsızlık testi

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `inst/i18n/messages.csv`, `tests/testthat/test-anova.R` (uyarı taraması)
- Create: `tests/testthat/test-chisq.R`

**Interfaces:**
- `plan_study()` imzasına `rows = NULL, cols = NULL` eklenir ve `prepare` argümanlarına geçer.
- `engine_n_chisq(w, df, alpha, power)` → ondalıklı toplam n.
- `engine_mde_chisq(n, df, alpha, power)` → w.
- `test_spec$chisq_indep`: `groups` 1, `min_n` 2, `directional = FALSE`, plan alanları `rows`, `cols`, `df` (üçü de `as.integer()` ile tam sayı; `df = as.integer((rows - 1) * (cols - 1))`), `effect_test = effect`, `method = "chisq_indep_w"`.
- `@param rows`, `@param cols` belgelenir; `@param effect`'e w eklenir.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| val_chisq_indep | chi-square test of independence | ki-kare bağımsızlık testi |
| err_w | For test = "chisq_indep", 'effect' must be Cohen's w, a single number greater than 0 and at most 1. | test = "chisq_indep" için 'effect' Cohen w olmalı: 0'dan büyük, en fazla 1 olan tek bir sayı. |
| err_table | Arguments 'rows' and 'cols' must each be a single whole number from 2 to 1000. | 'rows' ve 'cols' argümanlarının her biri 2 ile 1000 arasında tek bir tam sayı olmalı. |
| err_table_unused | Arguments 'rows' and 'cols' are used only with test = "chisq_indep". | 'rows' ve 'cols' argümanları yalnız test = "chisq_indep" ile kullanılır. |
| err_alt_chisq | The chi-square test of independence has no direction; do not set 'alternative'. | Ki-kare bağımsızlık testinin yönü yoktur; 'alternative' belirtmeyin. |
| err_infeasible_plan_chisq_indep | pwrss cannot solve this design: the effect is too small or too large for a computable sample size. Check effect, rows, cols, alpha and power. | pwrss bu tasarımı çözemiyor: etki, hesaplanabilir bir örneklem büyüklüğü için çok küçük ya da çok büyük. effect, rows, cols, alpha ve power değerlerini kontrol edin. |
| plan_effect_chisq_indep | Expected effect size (Cohen's w): %s | Beklenen etki büyüklüğü (Cohen w): %s |
| plan_table | Table size (rows x columns): %s x %s; degrees of freedom: %s | Tablo boyutu (satır x sütun): %s x %s; serbestlik derecesi: %s |
| plan_n_group_chisq_indep | Participants to recruit (includes dropout and design effect): %s | Alınması gereken katılımcı sayısı (kayıp ve tasarım etkisi dahil): %s |
| sens_title_chisq_indep | Smallest detectable effect (Cohen's w) | Saptanabilir en küçük etki (Cohen w) |
| col_n_recruited_chisq_indep | Recruited participants | Alınan katılımcı |
| col_n_effective_chisq_indep | Effective participants | Etkin katılımcı |
| m_effect_chisq_indep | The effect size used for planning was Cohen's w = %s%s for a %s x %s contingency table with %s degrees of freedom. | Planlamada %3$s x %4$s çapraz tablo için (serbestlik derecesi %5$s) etki büyüklüğü Cohen w = %1$s olarak alınmıştır%2$s. |
| m_result_chisq_indep | For the chi-square test of independence with alpha = %s and power = %s, the required sample size was %s participants in total. | Alfa = %s ve güç = %s için ki-kare bağımsızlık testinde gerekli örneklem büyüklüğü toplam %s katılımcıdır. |
| m_adjust_dropout_chisq_indep | Allowing for an expected dropout rate of %s%%, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_deff_chisq_indep | Allowing for a design effect of %s, the recruitment target was %s participants. | Tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_both_chisq_indep | Allowing for an expected dropout rate of %s%% and a design effect of %s, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s ve tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |

Metinde w `fmt_num()` ile (`0.30`).

- [ ] **Step 1: Başarısız testleri yaz (`test-chisq.R`)**

```r
test_that("chi-square n matches pwr", {
  for (w in c(0.1, 0.3, 0.5)) for (df in c(1, 2, 4)) {
    n <- engine_n_chisq(w, df, 0.05, 0.8)
    expect_lte(abs(n - pwr::pwr.chisq.test(w = w, df = df, power = 0.8)$N), 1)
  }
  expect_lte(abs(engine_n_chisq(0.3, 2, 0.01, 0.9) - pwr::pwr.chisq.test(w = 0.3, df = 2, sig.level = 0.01, power = 0.9)$N), 1)
})
test_that("chisq_indep plan", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2)
  expect_identical(c(p$n_per_group, p$n_total, p$groups, p$df), c(88L, 88L, 1L, 1L))
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)$n_total, 108L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 3, cols = 3)$n_total, 133L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, dropout = 0.1)$n_total, 97L)
  expect_identical(quiet_plan(test = "chisq_indep", effect = 1, rows = 2, cols = 2)$groups, 1L)
})
test_that("chisq_indep arguments are validated", {
  for (bad in list(0, 1.2, -0.3, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "chisq_indep", effect = bad, rows = 2, cols = 2), "'effect'", fixed = TRUE)
  }
  for (bad in list(NULL, 1, 2.5, 1001, NA_real_, "a")) {
    expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = bad, cols = 2), "'rows'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, rows = 2, cols = 2), "chisq_indep", fixed = TRUE)
  expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2, k = 3), "'k'", fixed = TRUE)
  expect_identical(tryCatch(plan_study(test = "chisq_indep", effect = 1e-5, rows = 2, cols = 2), error = conditionMessage),
    msg("err_infeasible_plan_chisq_indep"))
})
test_that("chisq_indep sensitivity", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)
  expect_equal(sensitivity(p, n = 108, power = 0.8)$mde,
    pwr::pwr.chisq.test(N = 108, df = 2, power = 0.8)$w, tolerance = 0.001)
  expect_identical(tryCatch(sensitivity(p, n = 3), error = conditionMessage), msg("err_infeasible"))
})
test_that("chisq_indep methods and print", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "(chi-square test of independence).", fixed = TRUE)
  expect_match(x, "Cohen's w = 0.30 (Yilmaz, 2021) for a 2 x 3 contingency table with 2 degrees of freedom.", fixed = TRUE)
  expect_match(x, "the required sample size was 108 participants in total.", fixed = TRUE)
  expect_false(grepl("))", x, fixed = TRUE)); expect_false(grepl(") (", x, fixed = TRUE))
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "2 x 3 \u00e7apraz tablo i\u00e7in (serbestlik derecesi 2)", fixed = TRUE)
  expect_match(t, "ki-kare ba\u011f\u0131ms\u0131zl\u0131k testinde gerekli", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Table size (rows x columns): 2 x 3; degrees of freedom: 2", out, fixed = TRUE)))
  expect_true(any(grepl("(Cohen's w): 0.3", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
})
test_that("tampered chisq_indep plans are refused", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)
  for (bad in list(list(rows = NULL), list(rows = 1), list(df = 5), list(effect_test = 1.5))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
```

Beklenen sayılar: 87.21 → 88; 107.05 → 108; sd 4 (3 × 3) 132.61 → 133; 87.21 / .9 = 96.9 → 97.

`test-anova.R` uyarı taramasına `list(test = "chisq_indep", effect = 0.3, rows = 2, cols = 3)` eklenir.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'chisq')"`
Expected: FAIL.

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0` (altın dahil), `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan chi-square test of independence`).
