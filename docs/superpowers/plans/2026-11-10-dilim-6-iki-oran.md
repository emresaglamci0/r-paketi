# Dilim 6: test arayüzü düzenlemesi ve iki bağımsız oran Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Önce teste özgü dalları tek bir test arayüzünde topla (davranış değişmez); sonra `plan_study(test = "prop_two", p1 = , p2 = )` ile iki bağımsız oranın karşılaştırmasını ekle.

**Architecture:** `test_spec`'in her satırı teste özgü fonksiyonları taşır. `plan_study()`, `sensitivity()`, yazdırma ve yöntem metni yalnız bu fonksiyonları çağırır; `if (design == ...)` dalları ortadan kalkar. `pwrss` çağrıları `R/engine.R`'de kalır.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: `stats::power.prop.test`.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir. Tolerans aynı yöntemde grup başına n'de ±1; aşılırsa dur.
- Görev 1 sonrası bağımsız t, bağımlı t ve ANOVA çıktıları bayt bayt aynı kalır.
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-6-two-props`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- `power.z.twoprops(prob1, prob2, req.sign, n2, power, alpha, alternative, arcsine = FALSE, correct = FALSE, std.error = c("pooled", "unpooled"), ceil.n, verbose)`. Varsayılan havuzlanmış standart hata.
- `ceil.n = FALSE` yok sayılıyor: `$n` yukarı yuvarlanmış tam sayı (n1, n2).
- p1 = .45, p2 = .30, güç .80: 163 (`stats` 162.3344); tek yönlü 128 (`stats` 127.7527). .10/.05 → 435 (434.43); .50/.60 → 388 (387.34). Yani `pwrss` = `ceiling(stats)`.
- p1 = p2 hata verir. .01/.02 → 2319; .20/.90 → 7.
- Saptanabilir etki: `prob1 = NULL`, `prob2`, `n2`; artış için `req.sign = "+"`, azalış için `"-"`. p2 = .30, n = 163 → p1 0.4497; p2 = .45, azalış → 0.3003.
- Küçük n'de (2, 3, 5) saptanabilir p1 hata yerine sınır değer 0.9998 döner.

## Kararlar (kullanıcı)

- Oranlar ayrı girilir: `p1` (1. grup) ve `p2` (2. grup).
- Yöntem: havuzlanmış standart hatalı z testi; metin yöntemin adını yazar.
- Önce davranışı değiştirmeyen test arayüzü düzenlemesi yapılır.
- Türkçe ad: "bağımsız iki oran karşılaştırması (z testi)".

## Kararlar (oluşturucu)

- `prop_two` testinde `effect` verilmez; verilirse hata. `r`, `k`, `effect_type` de kullanılmaz.
- `p1` ve `p2` açık (0, 1) aralığında, birbirinden farklı.
- `pwrss`'in önceden yuvarlaması nedeniyle kayıp ve tasarım etkisi düzeltmesi zaten yuvarlanmış n üzerinden yapılır; birkaç kişi fazla çıkabilir; fark kayıp ve tasarım etkisiyle artar (kullanıcı 2026-11-13'te kabul etti). Kodda `shortcut:` notuyla belirtilir.
- Duyarlılık, p2 sabitken saptanabilecek en küçük ya da en büyük p1'i verir (yön planla aynı). Sonuç 0.001'in altında ya da 0.999'un üstündeyse `err_infeasible`.
- Metinde oranlar APA biçiminde baştaki sıfırsız yazılır (`.45`), fark işaretiyle (`.15` ya da `-.15`).

## Review Focus

- Görev 1'den sonra eski üç testin tüm çıktıları bayt bayt aynıdır (altın dosya testi).
- Oran azalışı (p1 < p2) n'de artışla aynı sonucu, duyarlılıkta doğru yönü verir.
- Küçük n'de duyarlılık 0.9998 gibi anlamsız değer değil, okunur hata verir.
- Kaynak verildiğinde metinde çift parantez yok.
- Elle bozulmuş `prop_two` planı (`p1` silinmiş, `p1 == p2`) her fonksiyonda `err_plan` verir.

---

### Task 1: test arayüzü (davranış değişmez)

**Files:**
- Create: `tests/testthat/fixtures/golden.rds`, `tests/testthat/test-golden.R`, `dev/make-golden.R`
- Modify: `R/tests.R`, `R/plan.R`, `R/sensitivity.R`, `R/print.R`, `R/methods.R`, `R/validate.R`, `R/engine.R`

**Interfaces:**
- Her `test_spec[[test]]` şu alanları taşır:
  - `groups(a)` → tam sayı grup sayısı.
  - `min_n` → sayı.
  - `prepare(a, given)` → teste özgü argümanları doğrular, `effect_test` ve plana girecek ek alanları (ör. `r`, `k`, `effect_type`) içeren liste döndürür. `a`: `plan_study()` argümanlarının listesi; `given`: kullanıcının açıkça verdiği argüman adları (`missing()` ile).
  - `n(p)` → grup başına analitik n. `p`: hazırlanmış alanlar ile `alpha`, `power`, `alternative`.
  - `mde(n, plan, power)` → girilen birimde saptanabilir etki.
  - `effect_lines(plan)` → yazdırmada etki satırları (karakter vektörü, sırayla); eski `plan_effect`, `plan_r`, `plan_dz`, `plan_k`, `plan_f` satırları buraya taşınır.
  - `effect_sentence(plan, src, lang)` → yöntem metnindeki etki cümlesi.
  - `variant(plan)` → `msg_for()` için sonek vektörü (ör. `c("anova_oneway_eta2", "anova_oneway")`).
  - `check(plan)` → `check_plan()` içindeki teste özgü kontrol, mantıksal değer.
- `plan_study()`, `sensitivity()`, `print.plansize_plan()`, `print.plansize_sensitivity()`, `write_methods()`, `check_plan()` içinde teste göre `if` dalı kalmaz; yalnız `test_spec` fonksiyonları çağrılır.
- `R/engine.R` `pwrss` sarmalayıcılarını tutar; `test_spec` fonksiyonları onları çağırır.

- [ ] **Step 1: Altın çıktıları mevcut koddan üret**

`dev/make-golden.R`: aşağıdaki planların her biri için `capture.output(print(plan))`, `capture.output(print(sensitivity(plan)))`, `write_methods(plan, lang = "en")`, `write_methods(plan, lang = "tr")` ve plan alanlarını (`unclass(plan)`) bir listede toplayıp `tests/testthat/fixtures/golden.rds` dosyasına `saveRDS` ile yazar. Ayrıca şu hatalı çağrıların mesajlarını (en ve tr) aynı listeye ekler: `effect = 0`, `test = "anova"`, `t_paired` için `r` yok, ANOVA için `k = 1`, `effect_basis = "observed"`.

Planlar (hepsi `effect_basis = "pilot"`): bağımsız `effect = 0.5`; bağımsız `effect = 0.3, dropout = 0.1, deff = 1.5, effect_source = "Yilmaz, 2021"`; bağımsız `effect = 0.5, alternative = "one.sided"`; bağımlı `effect = 0.5, r = 0.5`; bağımlı `effect = 0.5, r = -0.3, dropout = 0.1`; ANOVA `effect = 0.25, k = 3`; ANOVA `effect = 0.06, k = 4, effect_type = "eta2", dropout = 0.1, deff = 1.3`.

Run: `& "D:\R-4.6.1\bin\Rscript.exe" dev\make-golden.R` (değişiklikten önce, mevcut kodla)
Expected: `golden.rds` oluşur. `.Rbuildignore` zaten `^dev$` içerir.

- [ ] **Step 2: Altın testini yaz ve geçtiğini gör**

`test-golden.R`, aynı planları yeniden kurup her parçanın `golden.rds` içindekiyle `expect_identical` olduğunu sınar.

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'golden')"`
Expected: PASS (henüz kod değişmedi).

- [ ] **Step 3: Arayüze geç**

Dalları `test_spec` fonksiyonlarına taşı. Doğrulama hata metinleri ve sıraları aynı kalır.

- [ ] **Step 4: Tüm testleri çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`; altın testi dahil eski 512 testin hepsi geçer; `Status: OK`. Mevcut testler değiştirilmez.

---

### Task 2: iki bağımsız oran

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `inst/i18n/messages.csv`
- Create: `tests/testthat/test-props.R`

**Interfaces:**
- `plan_study()` imzasına `p1 = NULL, p2 = NULL` eklenir.
- `engine_n_props(p1, p2, alpha, power, alternative)` → `$n[[2]]`; `# shortcut: pwrss twoprops ignores ceil.n and returns a rounded n, so dropout and deff are applied to a rounded n; the result can be a few participants per group higher (more with larger dropout or deff); compute an unrounded n if pwrss adds support`.
- `engine_mde_props(n, p2, increase, alpha, power, alternative)` → `prob1`; `req.sign` artışta `"+"`, azalışta `"-"`.
- `test_spec$prop_two`: `groups` 2, `min_n` 2, plan alanları `p1`, `p2`, `effect_test = p1 - p2`, `method = "z_two_props_pooled"`.

**CSV (metinler aynen)**

| key | en | tr |
|---|---|---|
| val_prop_two | comparison of two independent proportions (z test) | bağımsız iki oran karşılaştırması (z testi) |
| err_p | Arguments 'p1' and 'p2' must each be a single number strictly between 0 and 1. | Argüman 'p1' ve 'p2' 0 ile 1 arasında (uç değerler hariç) tek birer sayı olmalı. |
| err_p_equal | Arguments 'p1' and 'p2' must differ; equal proportions have no difference to detect. | Argüman 'p1' ve 'p2' farklı olmalı; eşit oranlarda saptanacak bir fark yoktur. |
| err_p_unused | Arguments 'p1' and 'p2' are used only with test = "prop_two". | Argüman 'p1' ve 'p2' yalnız test = "prop_two" ile kullanılır. |
| err_effect_unused | Argument 'effect' is not used with test = "prop_two"; give the proportions as p1 and p2. | Argüman 'effect' test = "prop_two" ile kullanılmaz; oranları p1 ve p2 olarak verin. |
| plan_p1 | Expected proportion in group 1 (p1): %s | 1. gruptaki beklenen oran (p1): %s |
| plan_p2 | Expected proportion in group 2 (p2): %s | 2. gruptaki beklenen oran (p2): %s |
| plan_pdiff | Difference (p1 - p2): %s | Fark (p1 - p2): %s |
| sens_title_prop_two | Detectable proportion in group 1 (group 2 at its planned value) | 1. grupta saptanabilir oran (2. grup planlanan değerinde) |
| col_mde_prop_two | Detectable p1 | Saptanabilir p1 |
| m_effect_prop_two | The proportions used for planning were %s in group 1 and %s in group 2%s; the difference between them is %s. | Planlamada oranlar 1. grupta %1$s ve 2. grupta %2$s olarak alınmıştır%3$s; iki oran arasındaki fark %4$s düzeyindedir. |
| m_result_prop_two | For a %s z test for two independent proportions with a pooled standard error, alpha = %s and power = %s, the required sample size was %s participants per group (%s in total). | Havuzlanmış standart hatalı bağımsız iki oran z testi (%1$s), alfa = %2$s ve güç = %3$s için gerekli örneklem büyüklüğü grup başına %4$s, toplamda %5$s katılımcıdır. |

- [ ] **Step 1: Başarısız testleri yaz (`test-props.R`)**

```r
test_that("two proportions match stats", {
  pairs <- list(c(0.45, 0.30), c(0.30, 0.45), c(0.10, 0.05), c(0.50, 0.60))
  for (p in pairs) for (alt in c("two.sided", "one.sided")) {
    n <- engine_n_props(p[1], p[2], 0.05, 0.8, alt)
    ref <- stats::power.prop.test(p1 = p[1], p2 = p[2], power = 0.8, alternative = alt)$n
    expect_lte(abs(n - ref), 1)
  }
})
test_that("prop_two plan", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(163L, 326L, 2L))
  expect_equal(p$effect_test, 0.15)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45)$n_per_group, 163L)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, alternative = "one.sided")$n_per_group, 128L)
  expect_identical(quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, dropout = 0.1)$n_per_group, 182L)
})
test_that("prop_two arguments are validated", {
  expect_error(plan_study(test = "prop_two", p2 = 0.3), "'p1'", fixed = TRUE)
  for (bad in list(0, 1, 1.2, NA_real_, c(0.2, 0.3), "a")) {
    expect_error(plan_study(test = "prop_two", p1 = bad, p2 = 0.3), "'p1'", fixed = TRUE)
  }
  expect_error(plan_study(test = "prop_two", p1 = 0.3, p2 = 0.3), "differ", fixed = TRUE)
  expect_error(plan_study(test = "prop_two", effect = 0.5, p1 = 0.45, p2 = 0.3), "'effect'", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, p1 = 0.45, p2 = 0.3), "prop_two", fixed = TRUE)
  expect_error(plan_study(test = "prop_two", p1 = 0.45, p2 = 0.3, k = 3), "'k'", fixed = TRUE)
})
test_that("prop_two sensitivity has the right direction and power", {
  up <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  m <- sensitivity(up, n = 163, power = 0.8)$mde
  expect_gt(m, 0.30)
  expect_equal(stats::power.prop.test(n = 163, p1 = m, p2 = 0.30)$power, 0.8, tolerance = 0.01)
  down <- quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45)
  d <- sensitivity(down, n = 163, power = 0.8)$mde
  expect_lt(d, 0.45)
  expect_equal(stats::power.prop.test(n = 163, p1 = d, p2 = 0.45)$power, 0.8, tolerance = 0.01)
  expect_identical(tryCatch(sensitivity(up, n = 3), error = conditionMessage), msg("err_infeasible"))
})
test_that("prop_two methods and print", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "(comparison of two independent proportions (z test))", fixed = TRUE)
  expect_match(x, "were .45 in group 1 and .30 in group 2 (Yilmaz, 2021); the difference between them is .15.", fixed = TRUE)
  expect_match(x, "For a two-sided z test for two independent proportions with a pooled standard error", fixed = TRUE)
  expect_match(x, "163 participants per group (326 in total)", fixed = TRUE)
  expect_false(grepl(") (", x, fixed = TRUE))
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "Havuzlanm\u0131\u015f standart hatal\u0131 ba\u011f\u0131ms\u0131z iki oran z testi (iki y\u00f6nl\u00fc)", fixed = TRUE)
  expect_false(grepl(") (", t, fixed = TRUE))
  d <- unclass(write_methods(quiet_plan(test = "prop_two", p1 = 0.30, p2 = 0.45), lang = "en"))
  expect_match(d, "the difference between them is -.15.", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("(p1): 0.45", out, fixed = TRUE)))
  expect_true(any(grepl("Difference (p1 - p2): 0.15", out, fixed = TRUE)))
  expect_false(any(grepl("Cohen", out, fixed = TRUE)))
})
test_that("tampered prop_two plans are refused", {
  p <- quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30)
  for (bad in list(list(p1 = NULL), list(p1 = 0.30), list(p2 = 2))) {
    q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE)
  }
})
```

Beklenen sayılar: 163 × 2 = 326; 163 / .9 = 181.1 → 182 (`pwrss` önceden yuvarladığı için; `stats` ile 162.33 / .9 → 181); yazdırmada fark `format(0.45 - 0.30)` = `0.15`.

Ayrıca `test-anova.R` içindeki uyarı taraması döngüsüne `list(test = "prop_two", p1 = 0.45, p2 = 0.30)` eklenir.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'props')"`
Expected: FAIL.

- [ ] **Step 3: Kodu ve CSV'yi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0` (altın testi dahil), `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan two independent proportions`).
