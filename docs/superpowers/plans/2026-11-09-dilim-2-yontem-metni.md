# Dilim 2: Türkçe ve İngilizce yöntem metni Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `write_methods()` bir `plansize_plan` nesnesinden kopyalanabilir Türkçe veya İngilizce yöntem paragrafı üretir.

**Architecture:** Cümleler `inst/i18n/messages.csv` dosyasındaki anahtarlardan gelir. Fonksiyon yalnız sayıları biçimlendirir ve cümleleri birleştirir. Yeni hesap yapmaz.

**Tech Stack:** R 4.6.1, testthat 3, roxygen2.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `PATH`'te değil. R çalıştırmadan önce `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Türkçe harf testlerde `\u` kaçışıyla yazılır.
- Kullanıcıya görünen her metin `msg()` üzerinden gelir. Her anahtar `en` ve `tr` içerir. CSV UTF-8, BOM yok.
- Kullanıcıdan gelen metin (`effect_source`) `sprintf` biçim dizgesine değil, argümanına geçer.
- Paket kontrolü: `powershell -ExecutionPolicy Bypass -File dev\check.ps1`, `Status: OK`.
- Dal: `slice-2-methods`. Commit yalnız kullanıcı onayından sonra.
- Korkuluk yok (Dilim 3). `effect_basis = "observed"` bu dilimde hata vermez.

## Review Focus

- `effect_source` içinde `%` varsa metin bozulmaz, hata çıkmaz.
- `effect_source = NULL` ise metinde boş parantez kalmaz.
- `alpha = 0.0001` bilimsel gösterimle yazılmaz (`1e-04` değil, `.0001`).
- `dropout = 0.125` metinde `12.5%` görünür.
- Yazdırılan metinde `[1]` ve tırnak olmaz, Türkçe harfler bozulmaz.

---

### Task 1: `write_methods()`

**Files:**
- Create: `R/methods.R`, `tests/testthat/test-methods.R`
- Modify: `inst/i18n/messages.csv`, `NAMESPACE`, `man/` (roxygen)

**Interfaces:**
- Consumes: `msg(key, ..., lang)`, `resolve_lang(lang)`, `check_required()`, `fail()`, `plansize_plan` alanları `test, effect, effect_basis, effect_source, alpha, power, alternative, dropout, deff, n_analytic, n_per_group, n_total, engine_version`.
- Produces:
  - `write_methods(plan, lang = NULL)` (dışa aktarılır). Dönüş: `c("plansize_methods", "character")` sınıflı tek metin.
  - `print.plansize_methods(x, ...)`: `writeLines(unclass(x))`, `invisible(x)`.
  - Sonraki dilimler için: `fmt_prob(x)` ve `fmt_num(x)` iç yardımcıları.

**Biçim kuralları**

- `fmt_num(x)` = `format(x, nsmall = 2, scientific = FALSE, trim = TRUE)`. Örnek: 0.5 için `0.50`, 0.125 için `0.125`.
- `fmt_prob(x)` = `fmt_num(x)` sonucunun başındaki `0` silinir (APA). Örnek: `.05`, `.80`, `.0001`.
- Kayıp yüzdesi: `format(100 * dropout, trim = TRUE)`. Tasarım etkisi: `format(deff, trim = TRUE)`.
- Ondalık ayırıcı iki dilde de nokta.
- `n_required = ceiling(n_analytic)`, toplam `2 * n_required`. Hedef sayılar plandaki `n_per_group` ve `n_total`.

**Paragraf sırası (tek boşlukla birleşir)**

`m_intro`, `m_effect`, `m_basis_<effect_basis>`, `m_result`, sonra yalnız gerekiyorsa tek bir düzeltme cümlesi: `dropout > 0` ve `deff > 1` ise `m_adjust_both`; yalnız `dropout > 0` ise `m_adjust_dropout`; yalnız `deff > 1` ise `m_adjust_deff`; ikisi de yoksa düzeltme cümlesi yok.

`m_effect` içindeki ikinci `%s`, `effect_source` varsa ` (kaynak metni)`, yoksa boş metindir.

**CSV'ye eklenecek satırlar (metinler aynen)**

| key | en | tr |
|---|---|---|
| m_intro | An a priori power analysis for an %s was conducted in R with the plansize package (version %s), using pwrss (version %s). | Örneklem büyüklüğü, %s için R ortamında plansize paketi (sürüm %s) ve pwrss (sürüm %s) kullanılarak yapılan a priori güç analiziyle belirlenmiştir. |
| m_effect | The expected effect size was Cohen's d = %s%s. | Beklenen etki büyüklüğü Cohen d = %s olarak alınmıştır%s. |
| m_basis_unknown | The basis of this effect size was not specified. | Bu etki büyüklüğünün dayanağı belirtilmemiştir. |
| m_basis_prior_study | This value was taken from a prior study. | Bu değer önceki bir çalışmadan alınmıştır. |
| m_basis_pilot | This value was estimated from a pilot study. | Bu değer bir pilot çalışmadan tahmin edilmiştir. |
| m_basis_smallest_of_interest | This value is the smallest effect size of interest. | Bu değer ilgilenilen en küçük etki büyüklüğüdür. |
| m_basis_convention | This value follows a conventional benchmark rather than study-specific evidence. | Bu değer çalışmaya özgü kanıt yerine yerleşik bir ölçüte dayanmaktadır. |
| m_basis_observed | This value was observed in the current data. | Bu değer mevcut veride gözlenmiştir. |
| m_result | With a %s test, alpha = %s and power = %s, the required sample size was %s participants per group (%s in total). | Alfa = %2$s, güç = %3$s ve %1$s test için gerekli örneklem büyüklüğü grup başına %4$s, toplamda %5$s katılımcıdır. |
| m_adjust_dropout | Allowing for an expected dropout rate of %s%%, the recruitment target was %s participants per group (%s in total). | Beklenen kayıp oranı %%%s varsayıldığında hedeflenen katılımcı sayısı grup başına %s, toplamda %s olarak belirlenmiştir. |
| m_adjust_deff | Allowing for a design effect of %s, the recruitment target was %s participants per group (%s in total). | Tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı grup başına %s, toplamda %s olarak belirlenmiştir. |
| m_adjust_both | Allowing for an expected dropout rate of %s%% and a design effect of %s, the recruitment target was %s participants per group (%s in total). | Beklenen kayıp oranı %%%s ve tasarım etkisi %s varsayıldığında hedeflenen katılımcı sayısı grup başına %s, toplamda %s olarak belirlenmiştir. |

CSV'de virgül içeren alanlar tırnaklanır.

- [ ] **Step 1: Başarısız testleri yaz**

```r
ver <- function() as.character(utils::packageVersion("plansize"))

test_that("full English paragraph for a basic plan", {
  p <- plan_study(effect = 0.5)
  expected <- paste0(
    "An a priori power analysis for an independent two-sample t test was conducted in R ",
    "with the plansize package (version ", ver(), "), using pwrss (version ",
    p$engine_version, "). The expected effect size was Cohen's d = 0.50. ",
    "The basis of this effect size was not specified. With a two-sided test, ",
    "alpha = .05 and power = .80, the required sample size was 64 participants ",
    "per group (128 in total).")
  expect_identical(as.character(unclass(write_methods(p, lang = "en"))), expected)
  expect_s3_class(write_methods(p, lang = "en"), "plansize_methods")
})
test_that("Turkish paragraph has the key phrases", {
  x <- unclass(write_methods(plan_study(effect = 0.5), lang = "tr"))
  expect_match(x, "a priori g\u00fc\u00e7 analiziyle", fixed = TRUE)
  expect_match(x, "Cohen d = 0.50", fixed = TRUE)
  expect_match(x, "Alfa = .05, g\u00fc\u00e7 = .80 ve iki y\u00f6nl\u00fc test", fixed = TRUE)
  expect_match(x, "grup ba\u015f\u0131na 64, toplamda 128", fixed = TRUE)
})
test_that("language comes from option and argument overrides", {
  p <- plan_study(effect = 0.5)
  withr::with_options(list(plansize.lang = "tr"), {
    expect_match(unclass(write_methods(p)), "belirlenmi\u015ftir", fixed = TRUE)
    expect_match(unclass(write_methods(p, lang = "en")), "was conducted", fixed = TRUE)
  })
  expect_error(write_methods(p, lang = "de"), "de")
})
test_that("adjustment sentence matches the corrections", {
  no <- unclass(write_methods(plan_study(effect = 0.5), lang = "en"))
  expect_false(grepl("recruitment", no, fixed = TRUE))
  d <- unclass(write_methods(plan_study(effect = 0.5, dropout = 0.1), lang = "en"))
  expect_match(d, "dropout rate of 10%, the recruitment target was 71 participants per group (142 in total)", fixed = TRUE)
  expect_match(d, "required sample size was 64 participants", fixed = TRUE)
  f <- unclass(write_methods(plan_study(effect = 0.5, deff = 1.5), lang = "en"))
  expect_match(f, "design effect of 1.5, the recruitment target was 96 participants per group (192 in total)", fixed = TRUE)
  b <- unclass(write_methods(plan_study(effect = 0.5, dropout = 0.1, deff = 1.5), lang = "en"))
  expect_match(b, "dropout rate of 10% and a design effect of 1.5, the recruitment target was 107", fixed = TRUE)
})
test_that("number formats follow the rules", {
  x <- unclass(write_methods(plan_study(effect = 1.25, alpha = 0.0001, power = 0.85, alternative = "one.sided", dropout = 0.125), lang = "en"))
  expect_match(x, "d = 1.25", fixed = TRUE)
  expect_match(x, "one-sided test", fixed = TRUE)
  expect_match(x, "alpha = .0001 and power = .85", fixed = TRUE)
  expect_match(x, "12.5%", fixed = TRUE)
  expect_match(unclass(write_methods(plan_study(effect = 0.125), lang = "en")), "d = 0.125", fixed = TRUE)
})
test_that("effect source is verbatim and optional", {
  s <- unclass(write_methods(plan_study(effect = 0.5, effect_source = "Yilmaz 100% 2021"), lang = "en"))
  expect_match(s, "d = 0.50 (Yilmaz 100% 2021).", fixed = TRUE)
  n <- unclass(write_methods(plan_study(effect = 0.5), lang = "en"))
  expect_false(grepl("()", n, fixed = TRUE))
})
test_that("every effect basis has a sentence in both languages", {
  for (b in c("unknown", "prior_study", "pilot", "smallest_of_interest", "convention", "observed")) {
    expect_true(nzchar(msg(paste0("m_basis_", b), lang = "en")))
    expect_true(nzchar(msg(paste0("m_basis_", b), lang = "tr")))
  }
  expect_match(unclass(write_methods(plan_study(effect = 0.5, effect_basis = "pilot"), lang = "en")), "pilot study", fixed = TRUE)
})
test_that("invalid plan and missing plan are readable", {
  expect_error(write_methods(list()), "plan")
  expect_error(write_methods(), "plan")
})
test_that("print writes plain text and returns invisibly", {
  x <- write_methods(plan_study(effect = 0.5), lang = "tr")
  out <- capture.output(v <- withVisible(print(x)))
  expect_false(v$visible)
  expect_false(any(grepl("[1]", out, fixed = TRUE)))
  expect_false(any(grepl("\"", out, fixed = TRUE)))
})
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'methods')"`
Expected: FAIL, `could not find function "write_methods"`.

- [ ] **Step 3: CSV satırlarını ekle, `R/methods.R` yaz**

`write_methods` başında `check_required(missing(plan), "plan")`, sonra `err_plan` denetimi, sonra `lang <- resolve_lang(lang)`. `msg()` her çağrıda bu `lang` ile çağrılır. roxygen ile dışa aktar, `devtools::document()` çalıştır.

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme (Türkçe akademik dil dahil), kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: write bilingual methods paragraph`).
