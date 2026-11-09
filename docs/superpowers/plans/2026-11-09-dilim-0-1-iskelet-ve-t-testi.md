# Dilim 0 ve 1: paket iskeleti ve bağımsız t testi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kurulabilir bir R paket iskeleti ve bağımsız t testi için n hesabı, duyarlılık çıktısı ile Türkçe/İngilizce mesaj altyapısı.

**Architecture:** Tek S3 plan nesnesi (`plansize_plan`). Hesap yalnız `R/engine.R` üzerinden `pwrss`'e gider. Kullanıcı metinleri `inst/i18n/messages.csv` dosyasından gelir.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3, roxygen2, devtools. Referans: `stats::power.t.test()`, `pwr`.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `PATH`'te değil.
- Paket adı: `plansize`. Kullanıcı başka ad seçerse bu plandaki ad baştan değişir.
- R kodu ve testler ASCII. Türkçe harf testlerde `\u` kaçışıyla yazılır.
- Kullanıcıya görünen her metin `msg()` üzerinden gelir.
- Düzeltme sırası: analitik n, `× deff`, `/ (1 - dropout)`, en sonda tek `ceiling()`. `pwrss` çağrıları `ceil.n = FALSE` kullanır.
- `stats::power.t.test` açıkça ad alanıyla yazılır, çünkü `pwrss` aynı adda fonksiyon dışa aktarır.
- Tolerans: aynı yöntemde grup başına n'de ±1. Aşılırsa dur, kullanıcıya getir.
- Commit yalnız kullanıcı isteyince yapılır. Commit adımları kullanıcının dilim onayından sonra çalışır.
- Bu planda korkuluk yoktur (Dilim 3). `effect_basis = "observed"` şimdilik hata vermez.

## Doğrulanmış gerçekler (pwrss 1.3.3, geçici kurulumla denendi)

- İmza: `power.t.student(d, null.d, margin, req.sign, n2, n.ratio, power, alpha, alternative = c("two.sided","one.sided","two.one.sided"), design = c("independent","paired","one.sample"), claim.basis, ceil.n = TRUE, verbose = 1, utf)`.
- Dönüş: `class = c("pwrss","t","student")`; alanlar `$n` (adlı, uzunluk 2), `$n.total`, `$power`, `$d`.
- d=0.5, güç=.80: `$n = c(64, 64)`, gerçek güç 0.8014596. n2=64, güç=.80, `d = NULL`: `$d = 0.4990692`.
- Referanslar: `stats::power.t.test` 63.76576, `pwr::pwr.t.test` 63.76561, `pwr` ile n=64 için d 0.499072.
- pwrss `power` değerini yalnız 0.01 ile 0.99 arasında kabul eder; n arama aralığı 4 ile `1e10` arasındadır (dışı "not feasible" hatası verir).
- Spec'teki açık soru kapandı: `power.chisq.test` ve `power.f.regression` dışa aktarılıyor. Kullanım testleri Dilim 8 ve 9'da.

## Review Focus

- `effect` 0, negatif, `NA` ya da uzunluğu 2 ise anlaşılır hata (Task 3).
- `alpha` veya `power` 0, 1, aralık dışı ya da metin ise anlaşılır hata (Task 3).
- `dropout = 1`, `dropout < 0` ya da `deff < 1` ise sıfıra bölme yerine anlaşılır hata (Task 3).
- `sensitivity()` içinde kayıp ve DEFF sonrası grup başına etkili n 3'ün altına düşerse `pwrss` hatası yerine anlaşılır hata (Task 4).
- Geçersiz `lang` hata verir; Türkçe harfler Windows'ta bozulmadan yazdırılır (Task 2 ve 5).

---

### Task 1: Paket iskeleti (Dilim 0)

**Files:**
- Create: `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `LICENSE.md`, `.Rbuildignore`, `.gitignore`, `R/plansize-package.R`, `tests/testthat.R`, `tests/testthat/test-smoke.R`
- Modify: `CLAUDE.md` (yalnız 4. adım gerektirirse)

**Interfaces:**
- Produces: `devtools::test()` ve `dev\check.ps1` çalışan paket. Sonraki görevler `Imports` ve `Suggests` ekler.

- [ ] **Step 1: Geliştirme paketlerini kur**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "install.packages(c('devtools','usethis','testthat','withr','pwrss','pwr'), lib='D:/R-4.6.1/library', repos='https://cloud.r-project.org')"`
Expected: Sonraki `requireNamespace` kontrolü hepsi için `TRUE`. Kurulum `D:/R-4.6.1/library` altına yapılır, C sürücüsüne paket kurulmaz. `shiny` ve `pkgdown` ilgili dilimlerde kurulur.

- [ ] **Step 2: İskeleti oluştur**

`Package: plansize`, `Version: 0.0.0.9000`, `License: MIT + file LICENSE`, `Encoding: UTF-8`, `Config/testthat/edition: 3`, `Roxygen: list(markdown = TRUE)`. `Suggests: testthat (>= 3.0.0), withr`. `.Rbuildignore` içine `^docs$`, `^CLAUDE\.md$`, `^LICENSE\.md$`, `^\.claude$`. `.gitignore` içine `.Rhistory`, `.RData`, `.Rproj.user`, `*.Rcheck`, `*.tar.gz`. Lisans sahibi `git config user.name` değeri.

- [ ] **Step 3: Duman testini yaz ve çalıştır**

```r
test_that("package namespace loads", {
  expect_true(requireNamespace("plansize", quietly = TRUE))
})
```

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"`
Expected: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1`

- [ ] **Step 4: Bu yolda `R CMD check` çalıştır**

Run: `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: 0 errors, 0 warnings (script exits 0). Rtools yok; `devtools::check()` çalışmaz, script `R CMD build` + `R CMD check --no-manual` çalıştırır. Yol boşluk ve `ş` içerdiği için hata çıkarsa dur, kullanıcıya depo taşınmasını sor.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`chore: scaffold package`).

---

### Task 2: Dil altyapısı (Dilim 1a)

**Files:**
- Create: `R/i18n.R`, `inst/i18n/messages.csv`, `tests/testthat/test-i18n.R`

**Interfaces:**
- Produces: `resolve_lang(lang = NULL) -> "en" | "tr"`; `msg(key, ..., lang = NULL) -> character(1)`. İkisi de iç fonksiyon.
- `messages.csv` UTF-8, sütunlar: `key,en,tr`. Yer tutucular `sprintf` biçiminde.

- [ ] **Step 1: Başarısız testleri yaz**

```r
test_that("default language is en", {
  withr::with_options(list(plansize.lang = NULL), expect_identical(resolve_lang(), "en"))
})
test_that("option selects tr and argument overrides option", {
  withr::with_options(list(plansize.lang = "tr"), {
    expect_identical(resolve_lang(), "tr")
    expect_identical(resolve_lang("en"), "en")
  })
})
test_that("invalid language errors", {
  expect_error(resolve_lang("de"), "de")
})
test_that("Turkish characters survive", {
  expect_identical(msg("probe", lang = "tr"), "\u00d6rneklem \u015f\u0131\u011f")
})
test_that("placeholders are filled", {
  expect_identical(msg("probe_n", 64, lang = "en"), "n = 64")
})
test_that("unknown key errors", {
  expect_error(msg("no_such_key"), "no_such_key")
})
test_that("every row has both languages", {
  x <- read_messages()
  expect_true(all(nzchar(x$en) & nzchar(x$tr)))
  expect_false(anyDuplicated(x$key) > 0)
})
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'i18n')"`
Expected: FAIL, `could not find function "resolve_lang"`.

- [ ] **Step 3: `resolve_lang()`, `read_messages()`, `msg()` yaz**

`system.file("i18n", "messages.csv", package = "plansize")` ile oku; `read.csv(..., fileEncoding = "UTF-8", stringsAsFactors = FALSE, na.strings = character())`. Dil önceliği: argüman, `getOption("plansize.lang")`, `"en"`. CSV'ye `probe` (tr: `Örneklem şığ`), `probe_n` (`n = %s`) satırlarını ekle. Geçersiz dil ve bilinmeyen anahtar hataları `msg()` döngüsüne girmeyen sabit İngilizce metindir.

- [ ] **Step 4: Testi çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'i18n')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, `dev\check.ps1` 0/0, kullanıcı okuması ve denemesi, devlog. Kullanıcı isterse commit (`feat: add bilingual message lookup`).

---

### Task 3: `plan_study()` ve hesap sarmalayıcısı (Dilim 1b)

**Files:**
- Create: `R/engine.R`, `R/validate.R`, `R/plan.R`, `tests/testthat/test-engine.R`, `tests/testthat/test-plan.R`
- Modify: `DESCRIPTION` (`Imports: pwrss (>= 1.3.3)`, `Suggests` içine `pwr`), `inst/i18n/messages.csv`

**Interfaces:**
- Consumes: `msg()`.
- Produces:
  - `engine_n(effect, alpha, power, alternative) -> list(n = <double>, method = <character(1)>)`
  - `engine_mde(n, alpha, power, alternative) -> <double>`
  - `plan_study(test = "t_independent", effect, effect_basis = c("unknown","prior_study","pilot","smallest_of_interest","convention","observed"), effect_source = NULL, alpha = 0.05, power = 0.80, alternative = c("two.sided","one.sided"), dropout = 0, deff = 1)` (dışa aktarılır)
  - Dönüş `plansize_plan` listesi, alanlar: `test, effect, effect_basis, effect_source, alpha, power, alternative, dropout, deff, n_analytic, n_per_group, n_total, method, engine_version`. `n_per_group` ve `n_total` tam sayıdır.

- [ ] **Step 1: Başarısız testleri yaz**

`test-engine.R`:

```r
test_that("pwrss output contract holds", {
  r <- pwrss::power.t.student(d = 0.5, power = 0.8, alpha = 0.05,
    alternative = "two.sided", design = "independent", ceil.n = FALSE, verbose = 0)
  expect_true(all(c("n", "power", "d") %in% names(r)))
  expect_length(r$n, 2)
})
test_that("engine_n matches independent references", {
  grid <- expand.grid(d = c(0.2, 0.5, 0.8), power = c(0.8, 0.9), alpha = c(0.05, 0.01))
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    n <- engine_n(g$d, g$alpha, g$power, "two.sided")$n
    ref <- stats::power.t.test(delta = g$d, sd = 1, sig.level = g$alpha, power = g$power)$n
    expect_lte(abs(n - ref), 1)
  }
  skip_if_not_installed("pwr")
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "two.sided")$n -
    pwr::pwr.t.test(d = 0.5, power = 0.8)$n), 1)
})
test_that("one sided matches reference", {
  ref <- stats::power.t.test(delta = 0.5, sd = 1, power = 0.8, alternative = "one.sided")$n
  expect_lte(abs(engine_n(0.5, 0.05, 0.8, "one.sided")$n - ref), 1)
})
test_that("engine_mde matches pwr", {
  skip_if_not_installed("pwr")
  expect_equal(engine_mde(64, 0.05, 0.8, "two.sided"),
    pwr::pwr.t.test(n = 64, power = 0.8)$d, tolerance = 0.001)
})
```

`test-plan.R`:

```r
test_that("basic plan gives 64 per group", {
  p <- plan_study(effect = 0.5)
  expect_s3_class(p, "plansize_plan")
  expect_identical(p$n_per_group, 64L)
  expect_identical(p$n_total, 128L)
  expect_identical(p$effect_basis, "unknown")
})
test_that("corrections apply in spec order with one final ceiling", {
  expect_identical(plan_study(effect = 0.5, dropout = 0.1)$n_per_group, 71L)
  expect_identical(plan_study(effect = 0.5, deff = 1.5, dropout = 0.1)$n_per_group, 107L)
})
test_that("invalid inputs give readable errors", {
  for (e in list(0, -0.5, NA_real_, c(0.2, 0.5), "a")) {
    expect_error(plan_study(effect = e), "effect")
  }
  for (a in list(0, 1, 1.5, -0.1, "a")) {
    expect_error(plan_study(effect = 0.5, alpha = a), "alpha")
    expect_error(plan_study(effect = 0.5, power = a), "power")
  }
  expect_error(plan_study(effect = 0.5, dropout = 1), "dropout")
  expect_error(plan_study(effect = 0.5, dropout = -0.1), "dropout")
  expect_error(plan_study(effect = 0.5, deff = 0.9), "deff")
  expect_error(plan_study(test = "anova", effect = 0.5), "anova")
})
test_that("engine prints nothing", {
  expect_output(plan_study(effect = 0.5), NA)
})
```

Beklenen sayılar: 63.77/.9 = 70.85, sonuç 71; 63.77×1.5/.9 = 106.3, sonuç 107.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'engine|plan')"`
Expected: FAIL, `could not find function`.

- [ ] **Step 3: `R/engine.R` yaz**

`pwrss::power.t.student(design = "independent", ceil.n = FALSE, verbose = 0, ...)` çağırır. `engine_n` `$n[[2]]` döner. `engine_mde` `d = NULL`, `n2 = n` ile `$d` döner. `method` metni testin adını taşır (`"student_t_independent"`).

- [ ] **Step 4: `R/validate.R` ve `R/plan.R` yaz**

`check_positive_number()`, `check_probability()` iç yardımcılar. `alpha` ve `power` açık (0, 1); `dropout` [0, 1); `deff >= 1`; `effect` sonlu, pozitif, tek sayı. Hata metinleri argüman adını içerir. Yeni anahtarları CSV'ye iki dilde ekle. Hatalar `stop(msg(...), call. = FALSE)`. `engine_version` = `as.character(utils::packageVersion("pwrss"))`. `n_per_group` = `as.integer(ceiling(n_analytic * deff / (1 - dropout)))`. roxygen ile dışa aktar, `devtools::document()` çalıştır.

- [ ] **Step 5: Testi çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'engine|plan')"`
Expected: `FAIL 0`. Kıyas ±1'i aşarsa dur, kullanıcıya getir.

---

### Task 4: `sensitivity()` (Dilim 1b)

**Files:**
- Create: `R/sensitivity.R`, `tests/testthat/test-sensitivity.R`
- Modify: `inst/i18n/messages.csv`

**Interfaces:**
- Consumes: `engine_mde()`, `plansize_plan`.
- Produces: `sensitivity(plan, n = NULL, power = c(0.80, 0.90, 0.95))` (dışa aktarılır). Dönüş `c("plansize_sensitivity", "data.frame")`, sütunlar `n_recruited, n_effective, power, mde`. `n` işe alınan grup başı sayıdır, `NULL` ise `plan$n_per_group`. `n_effective = floor(n * (1 - dropout) / deff + 1e-9)`.

- [ ] **Step 1: Başarısız testleri yaz**

```r
test_that("sensitivity matches pwr without corrections", {
  skip_if_not_installed("pwr")
  s <- sensitivity(plan_study(effect = 0.5), n = 64, power = 0.8)
  expect_s3_class(s, "plansize_sensitivity")
  expect_equal(s$mde, pwr::pwr.t.test(n = 64, power = 0.8)$d, tolerance = 0.001)
})
test_that("default n comes from plan and grid expands", {
  p <- plan_study(effect = 0.5)
  expect_identical(nrow(sensitivity(p)), 3L)
  expect_true(all(sensitivity(p)$n_recruited == 64L))
  expect_identical(nrow(sensitivity(p, n = c(50, 100))), 6L)
})
test_that("corrections reduce effective n", {
  s <- sensitivity(plan_study(effect = 0.5, dropout = 0.1, deff = 1.5), n = 100, power = 0.8)
  expect_identical(s$n_effective, 60)
})
test_that("too small n errors before reaching the engine", {
  p <- plan_study(effect = 0.5, dropout = 0.5)
  expect_error(sensitivity(p, n = 3), "n")
  expect_error(sensitivity(p, n = 0), "n")
  expect_error(sensitivity(list(), n = 10), "plan")
})
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'sensitivity')"`
Expected: FAIL.

- [ ] **Step 3: `sensitivity()` yaz**

`expand.grid(n, power)` üzerinden `engine_mde()`. `n_effective < 3` ise hata. `power` da `check_probability()` ile denetlenir.

- [ ] **Step 4: Testi çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'sensitivity')"`
Expected: `FAIL 0`.

---

### Task 5: İki dilli yazdırma ve dilim kapanışı (Dilim 1b)

**Files:**
- Create: `R/print.R`, `tests/testthat/test-print.R`, `docs/devlog.md`
- Modify: `inst/i18n/messages.csv`

**Interfaces:**
- Consumes: `msg()`, `plansize_plan`, `plansize_sensitivity`.
- Produces: `print.plansize_plan(x, ...)`, `print.plansize_sensitivity(x, ...)`. İkisi de `invisible(x)` döner.

- [ ] **Step 1: Başarısız testleri yaz**

```r
test_that("plan prints the group size in both languages", {
  p <- plan_study(effect = 0.5)
  withr::with_options(list(plansize.lang = "en"), expect_output(print(p), "64"))
  withr::with_options(list(plansize.lang = "tr"),
    expect_output(print(p), "\u00d6rneklem"))
})
test_that("print returns invisibly", {
  p <- plan_study(effect = 0.5)
  expect_invisible(print(p))
})
test_that("sensitivity prints a table", {
  expect_output(print(sensitivity(plan_study(effect = 0.5))), "0\\.[0-9]+")
})
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'print')"`
Expected: FAIL.

- [ ] **Step 3: Yazdırma yöntemlerini yaz**

Etiketler `msg()` ile gelir. Türkçe etiket "Örneklem" kelimesini içerir. `devtools::document()` ile S3 kayıtlarını üret.

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` sonra `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0`; 0 errors, 0 warnings.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi (yalnız spec, plan, diff). Kullanıcıya Türkçe anlatım, deneme örnekleri ve bilerek hatalı girdi: `plan_study(effect = 0.5)`, `plan_study(effect = 0.3, dropout = 0.1)`, `sensitivity(plan_study(effect = 0.5), n = 50)`, hatalı `plan_study(effect = 0)`. Anlama sorusu. `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan independent t test sample size`).
