# Dilim 7: Pearson korelasyonu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study(test = "cor_pearson", effect = r)` H0: ρ = 0 testi için gerekli katılımcı sayısını, duyarlılığı, çıktıyı ve yöntem metnini verir. Önce altın dosya güncel `main`'den yenilenir.

**Architecture:** `test_spec`'e `cor_pearson` satırı eklenir; motor `pwrss::power.z.onecor` çağırır. Başka dosyaya teste özgü dal eklenmez.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: Fisher z formülü `((qnorm(1 - alpha/2) + qnorm(power)) / atanh(r))^2 + 3` (tek yönlüde `qnorm(1 - alpha)`), `pwr::pwr.r.test`.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde n'de ±1; aşılırsa dur.
- Düzeltme sırası: analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`.
- Eski dört testin çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-7-correlation`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- `power.z.onecor(rho, req.sign = "+", null.rho = 0, n, power, alpha, alternative, ceil.n, verbose)`; `$n` ondalıklı.
- Güç .80, iki yönlü: r = .10 → 782.65; .30 → 84.928; .50 → 29.012; .80 → 9.503; -.30 → 84.928. Fisher z formülüyle birebir aynı. `pwr` küçük bir düzeltmeyle 781.75, 84.07, 28.25, 8.99 verir (±1 içinde).
- Tek yönlü .30 → 67.534 (`pwr` 66.55).
- n = 85 için saptanabilir r 0.29988 (`pwr` 0.29842). n = 4 → .9927; n = 10 → .785.

## Kararlar (kullanıcı)

- Yöntem: Fisher z yaklaşımı.
- Etki `effect` ile girilir: beklenen Pearson r.
- `r` argümanının yalnız eşli t testinde kullanıldığı belgede ayrıca açıklanır.
- Türkçe ad: "Pearson korelasyon katsayısının anlamlılık testi (Fisher z)".

## Kararlar (oluşturucu)

- Test adı `cor_pearson`. `effect` açık (-1, 1) aralığında ve 0'dan farklı; negatif değer kabul edilir.
- Motor her zaman `abs(effect)` ve `req.sign = "+"` ile çalışır: `pwrss` 1.3.3'te n işaretten bağımsızdır, duyarlılıkta `req.sign = "-"` ise bozuktur (n = 85 için ~1e-8 döner; kontrol ajanı denedi). `engine_mde_cor` pozitif r'yi bulup `sign * r` döndürür; duyarlılık sonucu `effect` ile aynı işareti taşır.
- Sıfır hipotezi ρ = 0; başka bir ρ ile karşılaştırma kapsam dışı.
- Tek grup: `groups` 1, `n_total = n`, `min_n = 4`.
- `r`, `k`, `effect_type`, `p1`, `p2` bu testte verilirse hata.
- İngilizce giriş cümlesi, iç içe parantez olmasın diye `prop_two` gibi ", a %1$s." kalıbını kullanır.
- Altın test, `err_choice` mesajındaki desteklenen test listesini karşılaştırmadan önce genel olarak çıkarır; `", prop_two"` için yapılan tek seferlik kesme kaldırılır.

## Review Focus

- Negatif r ile iki yönlü n pozitif r ile aynıdır; tek yönlüde ve duyarlılıkta yön doğru gelir.
- `effect = 0`, `1`, `-1` okunur hata verir.
- Eşli testte `r` hâlâ zorunlu; korelasyon testinde `r` verilirse hata ve mesaj `effect`'e yönlendirir.
- Kaynak verildiğinde metinde iç içe ya da art arda parantez yok.
- Elle bozulmuş `cor_pearson` planı her fonksiyonda `err_plan` verir.

---

### Task 1: altın dosyayı yenile

**Files:**
- Modify: `tests/testthat/helper-golden.R`, `tests/testthat/test-golden.R`, `tests/testthat/fixtures/golden.rds`

- [ ] **Step 1: Altın kapsamını genişlet**

`helper-golden.R` içindeki planlara ekle: `prop_two` `p1 = 0.45, p2 = 0.30`; `prop_two` `p1 = 0.30, p2 = 0.45, dropout = 0.1, effect_source = "Yilmaz, 2021"`; `prop_two` `p1 = 0.10, p2 = 0.05, alternative = "one.sided"`; ANOVA `effect = 0.25, k = 3, dropout = 0.15, deff = 1.3, effect_source = "Yilmaz, 2021"`; bağımlı `effect = 0.5, r = 0.5, effect_source = "Yilmaz, 2021"`. Her plan için ek olarak `sensitivity(plan, n = c(30, 60), power = c(0.8, 0.9))` çıktısı. Hata listesine ekle: bağımsız testte `k = 3`, `effect_type = "eta2"`, `r = 0.5`; ANOVA'da `alternative = "one.sided"`, `effect_type = "eta2", effect = 1.2`; bağımlı testte `r = 1`; `sensitivity()`'de `n = 1`; elle bozulmuş plan (`effect_basis = "observed"`) ile `print()`.

- [ ] **Step 2: Test listesini genel olarak çıkar**

`test-golden.R`: `err_choice` mesajlarında "must be one of: ..." / "şunlardan biri olmalı: ..." kısmındaki listeyi karşılaştırmadan önce sabit bir yer tutucuyla değiştir; `", prop_two"` kesmesini kaldır.

- [ ] **Step 3: Altını mevcut koddan yeniden üret**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" dev\make-golden.R` (kod değişmeden önce)
Expected: yeni `golden.rds`; `devtools::test(filter = 'golden')` PASS.

---

### Task 2: Pearson korelasyonu

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `inst/i18n/messages.csv`, `tests/testthat/test-anova.R` (uyarı taraması)
- Create: `tests/testthat/test-cor.R`

**Interfaces:**
- `engine_n_cor(rho, alpha, power, alternative)` → ondalıklı n.
- `engine_mde_cor(n, sign, alpha, power, alternative)` → işaretli saptanabilir r.
- `test_spec$cor_pearson`: `groups` 1, `min_n` 4, plan alanı `effect_test = effect`, `method = "fisher_z_cor"`.
- `@param r`: `Only for "t_paired": the correlation between the two repeated measurements. For "cor_pearson", give the expected correlation as effect, not as r.` `@param effect`'e korelasyon eklenir.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| val_cor_pearson | test of a Pearson correlation coefficient (Fisher z) | Pearson korelasyon katsayısının anlamlılık testi (Fisher z) |
| err_cor_effect | For test = "cor_pearson", 'effect' must be a single number strictly between -1 and 1 and not 0. | test = "cor_pearson" için 'effect' -1 ile 1 arasında (uç değerler hariç), 0'dan farklı tek bir sayı olmalı. |
| err_r_cor | Argument 'r' is not used with test = "cor_pearson"; give the expected correlation as 'effect'. | Argüman 'r' test = "cor_pearson" ile kullanılmaz; beklenen korelasyonu 'effect' olarak verin. |
| m_intro_cor_pearson | An a priori power analysis was conducted in R with the plansize package (version %2$s), using pwrss (version %3$s), to determine the sample size required for the planned analysis, a %1$s. | Örneklem büyüklüğü, %s için R ortamında plansize (sürüm %s) ve pwrss (sürüm %s) paketleri kullanılarak yapılan a priori güç analiziyle belirlenmiştir. |
| plan_effect_cor_pearson | Expected correlation (r): %s | Beklenen korelasyon (r): %s |
| plan_n_group_cor_pearson | Participants to recruit (includes dropout and design effect): %s | Alınması gereken katılımcı sayısı (kayıp ve tasarım etkisi dahil): %s |
| sens_title_cor_pearson | Smallest detectable correlation (r) | Saptanabilir en küçük korelasyon (r) |
| col_n_recruited_cor_pearson | Recruited participants | Alınan katılımcı |
| col_n_effective_cor_pearson | Effective participants | Etkin katılımcı |
| m_effect_cor_pearson | The correlation used for planning was r = %s%s. | Planlamada korelasyon r = %s olarak alınmıştır%s. |
| m_result_cor_pearson | For a %s test of H0: ρ = 0 based on the Fisher z transformation, with alpha = %s and power = %s, the required sample size was %s participants. | Fisher z dönüşümüne dayalı H0: ρ = 0 testi (%1$s), alfa = %2$s ve güç = %3$s için gerekli örneklem büyüklüğü %4$s katılımcıdır. |
| m_adjust_dropout_cor_pearson | Allowing for an expected dropout rate of %s%%, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_deff_cor_pearson | Allowing for a design effect of %s, the recruitment target was %s participants. | Tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |
| m_adjust_both_cor_pearson | Allowing for an expected dropout rate of %s%% and a design effect of %s, the recruitment target was %s participants. | Beklenen kayıp oranı %%%s ve tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı %s olarak belirlenmiştir. |

Metinde r `fmt_prob()` ile yazılır (`.30`, `-.30`).

- [ ] **Step 1: Başarısız testleri yaz (`test-cor.R`)**

```r
fz <- function(r, alpha = 0.05, power = 0.8, alt = "two.sided") {
  za <- if (alt == "two.sided") stats::qnorm(1 - alpha / 2) else stats::qnorm(1 - alpha)
  ((za + stats::qnorm(power)) / atanh(abs(r)))^2 + 3
}
test_that("correlation n matches the Fisher z formula and pwr", {
  for (r in c(0.1, 0.3, 0.5, 0.8, -0.3)) for (alt in c("two.sided", "one.sided")) {
    n <- engine_n_cor(r, 0.05, 0.8, alt)
    expect_lte(abs(n - fz(r, alt = alt)), 1)
    pa <- if (alt == "two.sided") "two.sided" else "greater"
    expect_lte(abs(n - pwr::pwr.r.test(r = abs(r), power = 0.8, alternative = pa)$n), 1)
  }
})
test_that("cor_pearson plan", {
  p <- quiet_plan(test = "cor_pearson", effect = 0.3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(85L, 85L, 1L))
  expect_identical(quiet_plan(test = "cor_pearson", effect = -0.3)$n_per_group, 85L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = 0.3, dropout = 0.1)$n_per_group, 95L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = 0.3, alternative = "one.sided")$n_per_group, 68L)
  expect_identical(quiet_plan(test = "cor_pearson", effect = -0.3, alternative = "one.sided")$n_per_group, 68L)
})
test_that("cor_pearson arguments are validated", {
  for (bad in list(0, 1, -1, 1.5, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "cor_pearson", effect = bad), "'effect'", fixed = TRUE)
  }
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, r = 0.3), "'effect'", fixed = TRUE)
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, k = 3), "'k'", fixed = TRUE)
  expect_error(plan_study(test = "cor_pearson", effect = 0.3, p1 = 0.3), "'p1'", fixed = TRUE)
  expect_error(plan_study(test = "t_paired", effect = 0.5), "'r'", fixed = TRUE)
})
test_that("cor_pearson sensitivity keeps the sign", {
  skip_if_not_installed("pwr")
  ref <- pwr::pwr.r.test(n = 85, power = 0.8)$r
  expect_lte(abs(sensitivity(quiet_plan(test = "cor_pearson", effect = 0.3), n = 85, power = 0.8)$mde - ref), 0.005)
  expect_lt(sensitivity(quiet_plan(test = "cor_pearson", effect = -0.3), n = 85, power = 0.8)$mde, 0)
  expect_error(sensitivity(quiet_plan(test = "cor_pearson", effect = 0.3), n = 3), "n = 3", fixed = TRUE)
})
test_that("cor_pearson methods and print", {
  p <- quiet_plan(test = "cor_pearson", effect = -0.3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "for the planned analysis, a test of a Pearson correlation coefficient (Fisher z).", fixed = TRUE)
  expect_match(x, "The correlation used for planning was r = -.30 (Yilmaz, 2021).", fixed = TRUE)
  expect_match(x, "the required sample size was 85 participants.", fixed = TRUE)
  expect_false(grepl("))", x, fixed = TRUE)); expect_false(grepl(") (", x, fixed = TRUE))
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "Fisher z d\u00f6n\u00fc\u015f\u00fcm\u00fcne dayal\u0131 H0", fixed = TRUE)
  expect_match(t, "korelasyon r = -.30 olarak al\u0131nm\u0131\u015ft\u0131r (Yilmaz, 2021).", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Expected correlation (r): -0.3", out, fixed = TRUE)))
  expect_false(any(grepl("Total", out, fixed = TRUE)))
})
test_that("tampered cor_pearson plans are refused", {
  p <- quiet_plan(test = "cor_pearson", effect = 0.3)
  for (bad in list(list(effect_test = 1), list(effect_test = NULL), list(groups = 2L))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
```

Beklenen sayılar: 84.928 → 85; 84.928 / .9 = 94.4 → 95; tek yönlü 67.53 → 68.

`test-anova.R` uyarı taramasına `list(test = "cor_pearson", effect = 0.3)` ve `list(test = "cor_pearson", effect = -0.3, alternative = "one.sided")` eklenir.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'cor')"`
Expected: FAIL.

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0` (altın dahil), `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan Pearson correlation`).
