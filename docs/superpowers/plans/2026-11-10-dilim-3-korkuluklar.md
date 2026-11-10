# Dilim 3: korkuluklar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study()` gözlenen etkiyle planlamayı reddeder, dayanağı bilinmeyen ya da yerleşik ölçüte dayanan etkide uyarır.

**Architecture:** Kontrol `plan_study()` içinde, mevcut `fail()` ve `msg()` ile yapılır. Uyarı kendi sınıfını taşır, böylece testler yalnız bu uyarıyı susturabilir.

**Tech Stack:** R 4.6.1, testthat 3.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (Bölüm 7, "İlk korkuluklar" tablosunun ilk iki satırı)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgül içeren alan tırnaklı.
- Paket kontrolü: `powershell -ExecutionPolicy Bypass -File dev\check.ps1`, `Status: OK`. Test çıktısında `WARN 0`.
- Dal: `slice-3-guardrails`. Commit yalnız kullanıcı onayından sonra.
- Cochran korkuluğu Dilim 10'dadır, bu dilimde yok.

## Review Focus

- `"observed"` hatası `pwrss` çağrılmadan gelir; çok büyük etkide bile önce bu hata görünür.
- Doğrulama hatası veren çağrı uyarı da vermez; uyarı yalnız plan başarıyla hesaplanınca çıkar.
- Testlerdeki susturucu yalnız `plansize_basis_warning` sınıfını susturur; başka bir uyarı yine `WARN` olarak görünür.
- `sensitivity()` ve `write_methods()` aynı plan için yeniden uyarmaz.
- Uyarı ve hata Türkçe seçildiğinde Türkçe gelir.

---

### Task 1: dayanak korkulukları

**Files:**
- Modify: `R/plan.R`, `R/validate.R`, `inst/i18n/messages.csv`, `tests/testthat/test-plan.R`, `tests/testthat/test-methods.R` ve `plan_study()` çağıran diğer test dosyaları
- Create: `tests/testthat/helper-plan.R`

**Interfaces:**
- Consumes: `fail()`, `msg()`, `check_choice()`.
- Produces:
  - `warn_basis(basis)` (iç, `R/validate.R`): `basis` `"unknown"` ya da `"convention"` ise `class = c("plansize_basis_warning", "warning", "condition")` olan, `call = NULL` uyarısı verir, `msg(paste0("warn_", basis))` metniyle.
  - Test yardımcısı `quiet_plan(...)`: `plan_study(...)` çağırır, yalnız `plansize_basis_warning` uyarısını `muffleWarning` ile susturur.

**Davranış**

- `effect_basis` doğrulandıktan hemen sonra `"observed"` ise `fail("err_observed")`.
- Uyarı `structure()` dönmeden hemen önce, `warn_basis(effect_basis)` ile.
- Artık hiçbir plan `"observed"` taşımadığı için `m_basis_observed` ve `val_observed` CSV'den silinir. `"observed"` `effect_basis` seçeneklerinde kalır, yoksa kullanıcı özel hata yerine genel seçim hatası görür.

**CSV'ye eklenecek satırlar (metinler aynen, virgüllü alan tırnaklı)**

| key | en | tr |
|---|---|---|
| err_observed | effect_basis = "observed" is not allowed: an effect observed in the current data cannot justify the sample size of the same data. Use sensitivity() to report the smallest effect your sample can detect. | effect_basis = "observed" kullanılamaz: mevcut veride gözlenen etki aynı verinin örneklem büyüklüğünü gerekçelendiremez. Örneklemin saptayabileceği en küçük etkiyi raporlamak için sensitivity() kullanın. |
| warn_unknown | The basis of the effect size is unknown. State where d comes from with effect_basis; the methods text will say the rationale was not specified. | Etki büyüklüğünün dayanağı bilinmiyor. d değerinin nereden geldiğini effect_basis ile belirtin; yöntem metni seçilme gerekçesinin belirtilmediğini yazacaktır. |
| warn_convention | The effect size rests on a conventional benchmark rather than study-specific evidence. Prefer a prior study, a pilot study or the smallest effect of interest. | Etki büyüklüğü çalışmaya özgü kanıt yerine yerleşik bir ölçüte dayanıyor. Önceki bir çalışma, pilot çalışma ya da ilgilenilen en küçük etki tercih edilmelidir. |

- [ ] **Step 1: Başarısız testleri yaz (`test-plan.R`)**

```r
test_that("observed effect basis is refused before the engine", {
  expect_error(plan_study(effect = 0.5, effect_basis = "observed"), "sensitivity()", fixed = TRUE)
  expect_error(plan_study(effect = 50, effect_basis = "observed"), "sensitivity()", fixed = TRUE)
  withr::with_options(list(plansize.lang = "tr"),
    expect_error(plan_study(effect = 0.5, effect_basis = "observed"), "kullan\u0131lamaz", fixed = TRUE))
})
test_that("unknown and convention warn with their own class", {
  expect_warning(plan_study(effect = 0.5), class = "plansize_basis_warning")
  expect_warning(plan_study(effect = 0.5, effect_basis = "convention"), class = "plansize_basis_warning")
  withr::with_options(list(plansize.lang = "tr"),
    expect_warning(plan_study(effect = 0.5), "dayana\u011f\u0131 bilinmiyor", fixed = TRUE))
})
test_that("justified bases do not warn", {
  for (b in c("prior_study", "pilot", "smallest_of_interest")) {
    expect_no_warning(plan_study(effect = 0.5, effect_basis = b))
  }
})
test_that("a warned plan is still complete", {
  p <- quiet_plan(effect = 0.5)
  expect_identical(p$n_per_group, 64L)
  expect_identical(p$effect_basis, "unknown")
})
test_that("an invalid call errors without the basis warning", {
  expect_no_warning(try(plan_study(effect = 0), silent = TRUE))
  expect_no_warning(try(plan_study(effect = 3), silent = TRUE))
})
test_that("later steps do not warn again", {
  p <- quiet_plan(effect = 0.5)
  expect_no_warning(sensitivity(p))
  expect_no_warning(write_methods(p))
})
test_that("the muffler leaves other warnings visible", {
  expect_warning(quiet_plan_with(function() warning("other")), "other")
})
```

`quiet_plan_with(f)` `helper-plan.R` içinde yalnız bu test için: `f()` çağrısını `quiet_plan` ile aynı işleyiciyle sarar.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'plan')"`
Expected: FAIL.

- [ ] **Step 3: Kodu ve CSV'yi değiştir**

`warn_basis()` ekle, `plan_study()` içine iki satır ekle, üç CSV satırını ekle, iki eski satırı sil. `test-methods.R` içindeki her dayanak döngüsünden `"observed"` çıkar.

- [ ] **Step 4: Diğer testleri sustur**

`plan_study()` çağıran ve dayanağı `"unknown"` ya da `"convention"` olan, uyarıyı sınamayan her test çağrısını `quiet_plan()` yap. Hata bekleyen `expect_error(plan_study(...))` çağrıları olduğu gibi kalır.

- [ ] **Step 5: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 6: Dilim sonu**

Bağlamsız Claude incelemesi, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: add effect basis guardrails`).
