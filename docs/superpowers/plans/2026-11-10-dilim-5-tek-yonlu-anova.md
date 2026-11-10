# Dilim 5: tek yönlü ANOVA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study(test = "anova_oneway", effect = , k = , effect_type = "f" | "eta2")` eşit büyüklükte k grup için genel F testinin gerekli n'sini, duyarlılığı, çıktıyı ve yöntem metnini verir; post hoc karşılaştırmaların gerekli olduğunu söyler.

**Architecture:** `test_spec`'e `anova_oneway` satırı eklenir. Motor tasarıma göre `pwrss::power.f.ancova` çağırır. Metin anahtarları önce `<anahtar>_<varyant>`, sonra `<anahtar>_<test>`, sonra `<anahtar>` sırasıyla aranır.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: `pwr::pwr.anova.test`, `stats::power.anova.test` (`between.var = f^2 * k / (k - 1)`, `within.var = 1`).

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde grup başına n'de ±1; aşılırsa dur.
- Düzeltme sırası: grup başına analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`; toplam = `k ×` grup başına n.
- t testlerinin sayıları ve metinleri aynı kalır.
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-5-anova`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- `power.f.ancova(eta.squared, factor.levels, n.total, power, alpha, ceil.n, verbose)`. Dönüşte `$n.total` toplam, `$eta.squared`.
- f = .25, güç = .80: k=2 → toplam 127.5312 (grup başı 63.77, t testiyle aynı); k=3 → 157.19 (52.3966); k=4 → 178.40 (44.599); k=6 → 210.85 (35.14). `pwr` ve `stats` aynı.
- η² = .06 → f = 0.2526456 → `pwr` grup başı 51.32635.
- Toplam 159, k=3 için saptanabilir η² 0.05818 → f 0.24854; `pwr` 0.24854.
- `n.total` tam sayı olmalı. Küçük toplamlarda saptanabilir etki "Design is not feasible." (k=3 için toplam 14'ün altı).
- f = 3 için toplam 5.29; büyük etki hesaplanabiliyor.

## Kararlar (kullanıcı)

- Etki f ya da η² olarak girilir: `effect_type = c("f", "eta2")`. Paket η²'yi `f = sqrt(eta2 / (1 - eta2))` ile çevirir; çıktı ve metin ikisini de yazar.
- Gruplar eşit büyüklüktedir; eşit olmayan gruplar kapsam dışı.
- Çıktı ve metin, n'nin yalnız genel F testi için geçerli olduğunu ve hangi grupların farklı olduğunu bulmak için post hoc karşılaştırma gerektiğini söyler.
- Türkçe ad: "tek yönlü varyans analizi (ANOVA)".

## Kararlar (oluşturucu)

- Test adı `anova_oneway`. Grup sayısı argümanı `k`: tek tam sayı, en az 2.
- `k` yalnız ANOVA'da, `effect_type` yalnız ANOVA'da kullanılır; başka testte verilirse hata.
- ANOVA'da `alternative` kullanılmaz; kullanıcı açıkça verirse hata. Plan `alternative = NA_character_` taşır, yazdırma o satırı atlar.
- Plan alanları: `effect` (girilen sayı), `effect_type` (ANOVA dışında `NA_character_`), `effect_test` (f), `k`, `groups = k`.
- Duyarlılık sonucu girilen birimde verilir: `effect_type = "eta2"` ise f, `eta2 = f^2 / (1 + f^2)` ile geri çevrilir.
- η² açık (0, 1) aralığında; f pozitif.
- ANOVA'da `min_n = 2`; daha küçük toplamlarda `pwrss`'in "not feasible" hatası mevcut `err_infeasible` mesajına çevrilir.

## Review Focus

- k = 2 ANOVA ile bağımsız t testi aynı grup başı n'yi verir (64).
- η² ile f girişi aynı etkide aynı n'yi verir.
- `sprintf` fazla argüman uyarısı yok: her test, varyant, kayıp ve tasarım etkisi bileşiminde `print()`, `sensitivity()`, `write_methods()` sessiz.
- ANOVA'da küçük n ve çok küçük etki okunur hata verir, ham `pwrss` hatası değil.
- Elle bozulmuş ANOVA planı (`k` silinmiş, `effect_type` geçersiz) her fonksiyonda `err_plan` verir.

---

### Task 1: test tablosu, motor, plan, duyarlılık

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `R/sensitivity.R`, `R/validate.R`, `inst/i18n/messages.csv`
- Create: `tests/testthat/test-anova.R`

**Interfaces:**
- `test_spec$anova_oneway = list(design = "anova", groups = NULL, min_n = 2)`.
- `engine_n(effect, alpha, power, alternative, design, k = NULL)`; ANOVA'da `n` grup başı (`$n.total / k`), `method = "f_oneway_anova"`.
- `engine_mde(n, alpha, power, alternative, design, k = NULL)`; ANOVA'da `n.total = n * k`, f döner.
- `plan_study(test, effect, r = NULL, k = NULL, effect_type = c("f", "eta2"), effect_basis, effect_source, alpha, power, alternative, dropout, deff)`. `alternative` ve `effect_type`'ın açıkça verilip verilmediği `missing()` ile anlaşılır.
- `check_plan()`: ANOVA planında `k` en az 2 olan tek tam sayı, `groups == k`, `effect_type` `"f"` ya da `"eta2"`, `effect_test` sonlu pozitif.
- `sensitivity()` sonucu `attr(, "test")` yanında `attr(, "effect_type")` taşır.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| err_k | Argument 'k' must be a single whole number of at least 2. | Argüman 'k' en az 2 olan tek bir tam sayı olmalı. |
| err_k_unused | Argument 'k' is used only with test = "anova_oneway". | Argüman 'k' yalnız test = "anova_oneway" ile kullanılır. |
| err_effect_type_unused | Argument 'effect_type' is used only with test = "anova_oneway". | Argüman 'effect_type' yalnız test = "anova_oneway" ile kullanılır. |
| err_eta2 | With effect_type = "eta2", 'effect' must be a single number strictly between 0 and 1. | effect_type = "eta2" ise 'effect' 0 ile 1 arasında (uç değerler hariç) tek bir sayı olmalı. |
| err_alt_anova | The F test of a one-way ANOVA has no direction; do not set 'alternative'. | Tek yönlü ANOVA'nın F testinin yönü yoktur; 'alternative' belirtmeyin. |
| err_infeasible_plan_anova_oneway | pwrss cannot solve this design: the effect is too small or too large for a computable sample size. Check effect, k, alpha and power. | pwrss bu tasarımı çözemiyor: etki, hesaplanabilir bir örneklem büyüklüğü için çok küçük ya da çok büyük. effect, k, alpha ve power değerlerini kontrol edin. |

- [ ] **Step 1: Başarısız testleri yaz (`test-anova.R`)**

```r
test_that("anova n matches pwr and stats", {
  for (k in c(2, 3, 4, 6)) {
    n <- engine_n(0.25, 0.05, 0.8, NULL, "anova", k)$n
    expect_lte(abs(n - pwr::pwr.anova.test(k = k, f = 0.25, power = 0.8)$n), 1)
    expect_lte(abs(n - stats::power.anova.test(groups = k, between.var = 0.25^2 * k / (k - 1),
      within.var = 1, power = 0.8)$n), 1)
  }
  expect_equal(engine_mde(53, 0.05, 0.8, NULL, "anova", 3),
    pwr::pwr.anova.test(k = 3, n = 53, power = 0.8)$f, tolerance = 0.001)
})
test_that("anova plan counts groups", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(53L, 159L, 3L))
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3, dropout = 0.1)$n_per_group, 59L)
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 4)$n_total, 180L)
  expect_true(is.na(p$alternative))
})
test_that("k = 2 matches the independent t test", {
  expect_identical(quiet_plan(test = "anova_oneway", effect = 0.25, k = 2)$n_per_group, 64L)
  expect_identical(quiet_plan(effect = 0.5)$n_per_group, 64L)
})
test_that("eta squared converts to f", {
  e <- quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")
  expect_equal(e$effect_test, sqrt(0.06 / 0.94))
  expect_identical(e$n_per_group, 52L)
  f <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  g <- quiet_plan(test = "anova_oneway", effect = 0.0625 / 1.0625, k = 3, effect_type = "eta2")
  expect_identical(f$n_per_group, g$n_per_group)
})
test_that("anova arguments are validated", {
  for (bad in list(NULL, 1, 2.5, NA_real_, "a", c(2, 3))) {
    expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = bad), "'k'", fixed = TRUE)
  }
  expect_error(plan_study(effect = 0.5, k = 3), "anova_oneway", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, effect_type = "eta2"), "anova_oneway", fixed = TRUE)
  for (bad in c(0, 1, 1.2)) {
    expect_error(plan_study(test = "anova_oneway", effect = bad, k = 3, effect_type = "eta2"), "eta2", fixed = TRUE)
  }
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, alternative = "two.sided"), "alternative", fixed = TRUE)
})
test_that("anova limits give readable errors", {
  expect_identical(tryCatch(plan_study(test = "anova_oneway", effect = 1e-5, k = 3), error = conditionMessage),
    msg("err_infeasible_plan_anova_oneway"))
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_identical(tryCatch(sensitivity(p, n = 3), error = conditionMessage), msg("err_infeasible"))
  expect_error(sensitivity(p, n = 1), "n = 1", fixed = TRUE)
})
test_that("anova sensitivity reports the entered unit", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  f <- pwr::pwr.anova.test(k = 3, n = 53, power = 0.8)$f
  expect_equal(sensitivity(p, n = 53, power = 0.8)$mde, f, tolerance = 0.001)
  e <- quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")
  expect_equal(sensitivity(e, n = 53, power = 0.8)$mde, f^2 / (1 + f^2), tolerance = 0.001)
  expect_identical(attr(sensitivity(e), "effect_type"), "eta2")
})
test_that("tampered anova plans are refused in sensitivity", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  for (bad in list(list(k = NULL), list(k = 2.5), list(effect_type = "d"), list(groups = 4L))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
  }
})
```

Beklenen sayılar: 52.3966 → 53, toplam 159; 52.3966 / .9 = 58.2 → 59; k=4 44.599 → 45, toplam 180; η² .06 → 51.33 → 52.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'anova')"`
Expected: FAIL.

- [ ] **Step 3: Kodu yaz**

- [ ] **Step 4: Testleri çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"`
Expected: `FAIL 0 | WARN 0`.

---

### Task 2: çıktı ve yöntem metni

**Files:**
- Modify: `R/i18n.R`, `R/print.R`, `R/methods.R`, `inst/i18n/messages.csv`, `tests/testthat/test-anova.R`, `tests/testthat/test-paired.R` (yalnız gerekirse)

**Interfaces:**
- `msg_for(base, test, ..., lang = NULL)`: `test` bir vektör olabilir; anahtarlar `paste0(base, "_", test)` sırasıyla, en sonda `base` denenir. Tek değerli eski çağrılar aynı çalışır.
- ANOVA'da varyant: `effect_type == "eta2"` ise `c("anova_oneway_eta2", "anova_oneway")`, değilse `"anova_oneway"`.

**Davranış**

- Yazdırma: ANOVA'da `plan_k` satırı, etki satırı varyanta göre; `effect_type = "eta2"` ise ayrıca `plan_f` satırı; `alternative` satırı atlanır; en sonda `plan_note_anova_oneway`.
- Yöntem metni: ANOVA'da `m_effect` ve `m_result` varyant anahtarlarından gelir; `m_result_anova_oneway` yön almaz; düzeltme cümleleri genel (grup başına) anahtarlardır; paragrafın sonuna `m_posthoc_anova_oneway` eklenir.
- Duyarlılık yazdırması başlığı `sens_title` varyantıyla seçer.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| val_anova_oneway | one-way ANOVA | tek yönlü varyans analizi (ANOVA) |
| plan_k | Number of groups (k): %s | Grup sayısı (k): %s |
| plan_effect_anova_oneway | Expected effect size (Cohen's f): %s | Beklenen etki büyüklüğü (Cohen f): %s |
| plan_effect_anova_oneway_eta2 | Expected effect size (eta squared): %s | Beklenen etki büyüklüğü (eta kare): %s |
| plan_f | Effect size used in the test (Cohen's f): %s | Testte kullanılan etki büyüklüğü (Cohen f): %s |
| plan_note_anova_oneway | Note: this n covers the overall F test only. Post hoc comparisons are needed to find which groups differ, and they usually need a larger sample. | Not: bu n yalnız genel F testi içindir. Hangi grupların farklı olduğunu bulmak için post hoc karşılaştırmalar gerekir ve bunlar genellikle daha büyük bir örneklem ister. |
| sens_title_anova_oneway | Smallest detectable effect (Cohen's f) | Saptanabilir en küçük etki (Cohen f) |
| sens_title_anova_oneway_eta2 | Smallest detectable effect (eta squared) | Saptanabilir en küçük etki (eta kare) |
| m_effect_anova_oneway | The effect size used for planning was Cohen's f = %s%s for %s groups. | Planlamada %3$s grup için etki büyüklüğü Cohen f = %1$s olarak alınmıştır%2$s. |
| m_effect_anova_oneway_eta2 | The effect size used for planning was eta squared = %s%s for %s groups, which corresponds to Cohen's f = %s. | Planlamada %3$s grup için etki büyüklüğü eta kare = %1$s olarak alınmıştır%2$s; bu değer Cohen f = %4$s değerine karşılık gelmektedir. |
| m_result_anova_oneway | For the overall F test with alpha = %s and power = %s, the required sample size was %s participants per group (%s in total). | Alfa = %s ve güç = %s için genel F testinde gerekli örneklem büyüklüğü grup başına %s, toplamda %s katılımcıdır. |
| m_posthoc_anova_oneway | This sample size applies to the overall F test only; a significant result shows that at least one group mean differs, but not which one. Post hoc comparisons are needed to identify the differing groups, and they usually require a larger sample than the overall test. | Bu örneklem büyüklüğü yalnız genel F testi için geçerlidir; anlamlı bir sonuç en az bir grup ortalamasının farklı olduğunu gösterir, ancak hangisinin farklı olduğunu göstermez. Farklı grupları belirlemek için post hoc karşılaştırmalar gerekir ve bunlar genellikle genel testten daha büyük bir örneklem gerektirir. |

Biçim: f ve η² `fmt_num()` ile yazılır, η²'den çevrilen f `fmt_num(round(f, 2))`; alpha ve güç `fmt_prob()`.

- [ ] **Step 1: Başarısız testleri yaz (`test-anova.R`)**

```r
test_that("anova methods paragraph in English", {
  p <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expected <- paste0(
    "An a priori power analysis was conducted in R with the plansize package (version ",
    as.character(utils::packageVersion("plansize")), "), using pwrss (version ",
    p$engine_version, "), to determine the sample size required for the planned analysis ",
    "(one-way ANOVA). The effect size used for planning was Cohen's f = 0.25 for 3 groups. ",
    "The rationale for choosing this effect size was not specified. For the overall F test ",
    "with alpha = .05 and power = .80, the required sample size was 53 participants per group ",
    "(159 in total). This sample size applies to the overall F test only; a significant result ",
    "shows that at least one group mean differs, but not which one. Post hoc comparisons are ",
    "needed to identify the differing groups, and they usually require a larger sample than ",
    "the overall test.")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  e <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"), lang = "en"))
  expect_match(e, "eta squared = 0.06 for 3 groups, which corresponds to Cohen's f = 0.25.", fixed = TRUE)
  d <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.25, k = 3, dropout = 0.1), lang = "en"))
  expect_match(d, "the recruitment target was 59 participants per group (177 in total).", fixed = TRUE)
})
test_that("anova Turkish text and print", {
  x <- unclass(write_methods(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"), lang = "tr"))
  expect_match(x, "tek y\u00f6nl\u00fc varyans analizi (ANOVA) i\u00e7in", fixed = TRUE)
  expect_match(x, "Planlamada 3 grup i\u00e7in etki b\u00fcy\u00fckl\u00fc\u011f\u00fc eta kare = 0.06", fixed = TRUE)
  expect_match(x, "post hoc kar\u015f\u0131la\u015ft\u0131rmalar gerekir", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"))))
  expect_true(any(grepl("Number of groups (k): 3", out, fixed = TRUE)))
  expect_true(any(grepl("(eta squared): 0.06", out, fixed = TRUE)))
  expect_true(any(grepl("(Cohen's f): 0.25", out, fixed = TRUE)))
  expect_true(any(grepl("Post hoc", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
  s <- withr::with_options(list(plansize.lang = "en"),
    capture.output(print(sensitivity(quiet_plan(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2")))))
  expect_true(any(grepl("(eta squared)", s, fixed = TRUE)))
})
test_that("no sprintf warnings across tests and variants", {
  plans <- list(
    list(effect = 0.5), list(test = "t_paired", effect = 0.5, r = 0.5),
    list(test = "anova_oneway", effect = 0.25, k = 3),
    list(test = "anova_oneway", effect = 0.06, k = 3, effect_type = "eta2"))
  for (a in plans) for (dr in c(0, 0.1)) for (de in c(1, 1.5)) for (lg in c("en", "tr")) {
    p <- do.call(plan_study, c(a, list(effect_basis = "pilot", dropout = dr, deff = de)))
    withr::with_options(list(plansize.lang = lg), {
      expect_no_warning(capture.output(print(p)))
      expect_no_warning(capture.output(print(sensitivity(p))))
      expect_no_warning(write_methods(p))
    })
  }
})
test_that("tampered anova plans are refused in print and methods", {
  q <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3); q$k <- NULL
  expect_error(print(q), "plan_study()", fixed = TRUE)
  expect_error(write_methods(q), "plan_study()", fixed = TRUE)
})
```

Beklenen sayılar: 177 = 59 × 3. η² .06'dan f = 0.2526 → `0.25`.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'anova')"`
Expected: FAIL.

- [ ] **Step 3: `msg_for()` vektör desteği, yazdırma ve metin değişikliklerini yap**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan one-way ANOVA`).
