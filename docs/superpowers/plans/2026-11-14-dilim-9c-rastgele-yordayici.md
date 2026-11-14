# Dilim 9c: rastgele yordayıcı bilgi satırı (DMAR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşul:** Dilim 9 (`reg_overall`) `main`'e birleşmiş olmalı. Bu plan onun arayüzüne dayanır (`effect_test` = R², `predictors`, `test_spec$reg_overall`, `print.plansize_plan` içindeki `spec$effect_lines`). Dilim 9 dosyası değiştirilmedi. 9b'ye bağımlı değil (açık soru 2).

**Goal:** `reg_overall` planı yazdırıldığında, `DMAR` kuruluysa bir bilgi satırı eklenir: "Rastgele yordayıcılarda önerilen n: X". Plan n'si (pwrss, sabit yordayıcı) **değişmez**; satır yalnız bilgidir. Neden: pwrss/G*Power "fixed model" F testidir, ama sosyal bilimlerde yordayıcılar çoğunlukla rastgele ölçülür ve gerçek güç biraz düşük kalır (Dilim 9: n = 77'de simülasyon .782, hedef .80). Satır öğrenciye bu farkı sayıyla gösterir.

**Architecture:** Yeni küçük dosya `R/random_predictors.R`: iç işlev `random_predictor_n(plan)` (DMAR çağrısı, korkuluklar, düzeltme sırası). `test_spec`'e isteğe bağlı `info_lines` alanı (yalnız `reg_overall` doldurur; öteki testlerde `NULL`), `print.plansize_plan` bu alan varsa satırları plan notundan önce yazar. Plan nesnesine **alan eklenmez** (açık soru 3'te gerekçe). Hesap yapılmaz, `DMAR` çağrılır.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, **DMAR 1.0.0** (CRAN, GPL >= 3; `Suggests`), testthat 3. Referanslar: G*Power yayımlanmış örneği (Faul ve ark. 2009), rastgele-normal-yordayıcı simülasyonu, DMAR'ın kendi `actual_power` değeri.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§5 `Suggests`, §6 doğruluk, §8 madde 9c)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- **DMAR bu geliştirme makinesinde yalnız `D:/rtmp/lib` içinde kurulu.** Ana kütüphaneye (`D:/R-4.6.1/library`) **kurulması gerek** (kullanıcı onayıyla: `install.packages("DMAR", lib = "D:/R-4.6.1/library")`; bağımlılıkları `MASS`, `generics`, `withr` vb.). Kurulana kadar `devtools::test()` ve `dev\check.ps1` DMAR testlerini `skip_if_not_installed("DMAR")` ile atlar ve satırın yokluğunu sınar; kurulduktan sonra tam set çalıştırılır. Kurulum yapılmadan dilim kapatılmaz (referans testler atlanmış olurdu).
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı.
- `DMAR` yalnız `Suggests`'te; çağrı `requireNamespace("DMAR", quietly = TRUE)` ile korunur, `library(DMAR)` yok. `Imports` değişmez (yalnız `pwrss`).
- Eski testlerin ve plan nesnelerinin çıktıları değişmez (altın test); `reg_overall` dışındaki testlerin `print` çıktısı birebir aynı.
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-9c-random-predictors`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (DMAR 1.0.0, pwrss 1.3.3, R'da denendi)

**Çağrı ve çıktı.** `DMAR::ss_power_R2(population_R2 = R2, p = k, alpha_level = alpha, desired_power = power, random_predictors = TRUE)` sınıfı `dmar_ss_power`/`dmar_tbl`/`data.frame` olan, iki sütunlu (`term`, `value`) 4 satırlık bir tablo döner: `necessary_N`, `actual_power`, `noncentral_f_parm` (rastgele modda `NA`), `effect_size`. n'yi `value[1]` ile değil **`value[term == "necessary_N"]`** ile almak daha güvenli (şu an ikisi aynı; sütun sırası değişirse `[1]` sessizce yanlışlaşır). `value` sayısal. Varsayılan `random_predictors = TRUE`, yine de açıkça yazılır. `null_R2 ≠ 0` **kullanılmaz** (doğrulanmadı).

**Yayımlanmış referans (G*Power, Faul ve ark. 2009, Örnek 1: ρ² .10, N 95, m 5, α .05, rastgele model):** G*Power gücü .662627. `DMAR::ss_power_R2(population_R2 = .10, p = 5, specified_N = 95, alpha_level = .05, random_predictors = TRUE)` `actual_power` = **.6626115** (fark 1.6e-5). Sabit model (`random_predictors = FALSE`) aynı girdide .674 (bu da pwrss'in modeli). Yani DMAR rastgele modeli G*Power'ın rastgele modeliyle 4 hanede uyuşuyor.

**Plan n (pwrss, sabit) ve DMAR n (rastgele), güç .80, α .05:**

| R² | k | pwrss plan n | DMAR n | DMAR `actual_power` | rastgele-X simülasyon, DMAR n'de (10.000) | simülasyon, pwrss n'de |
|---|---|---|---|---|---|---|
| .13 | 3 | 77 | 80 | .80226 | .8107 | .7818 |
| .02 | 1 | 387 | 390 | .80082 | .8020 | .7975 |
| .26 | 5 | 43 | 45 | .80222 | .8001 | .7860 |
| .50 | 3 | 16 | 18 | .81999 | .8209 | .7482 |

Bu sayılar kullanıcının ölçümleriyle (77/80, 387/390, 43/45, 16/18) birebir aynı; R'da yeniden üretildi. DMAR n'sinde simülasyonun DMAR'ın `actual_power`'ından sapması ≤ .009 (tolerans .02); pwrss n'sinde güç .75-.79'a düşüyor (özellikle küçük n'de: R² .50 k 3 n 16 → .748). Fark hep pozitif (DMAR n ≥ pwrss n): 3, 3, 2, 2 kişi.

Geniş ızgarada da DMAR ≥ pwrss: (.9, 3) 7/8, (.98, 3) 6/6, (.5, 10) 27/29, (.05, 50) 609/612, (.3, 100) 171/172, (1e-4, 3) 109019/109022.

**Hata ve uyarı durumları** (DMAR `ss_power_R2`, güç .8, α .05, k 3 aksi belirtilmedikçe):

| Girdi | DMAR davranışı | Korkuluk gerekir mi |
|---|---|---|
| R² 1 | hata: "TRUE/FALSE gereken yerde eksik değer" (ham R hatası) | Dilim 9'da `effect` ≤ .99 kontrolü zaten engeller; yine de `tryCatch` |
| R² 0, < 0, `NA` | okunur hata ya da ham hata | Dilim 9 engeller; `tryCatch` |
| R² 1e-6, 1e-7 | hata: "Failed to reach 'desired_power' within a reasonable sample size." | **Evet**: `tryCatch` |
| R² 1e-8 | **uyarı** "NaNs üretimi" (sonuç boş) | **Evet**: uyarıyı da yakala |
| R² 1e-5 | çalışır, n = 1.090.249, **20.8 sn** | **Evet**: n büyükse çağırma (aşağıda) |
| R² 1e-4 | çalışır, n = 109.022 (süre ölçülmedi) | eşik 1e5 üstünde, atlanır |
| k 1000 (R² .13) | çalışır, n = 1467, hızlı | hayır |
| k 0 | uyarı "NaNs produced" | Dilim 9 engeller (`predictors` ≥ 1) |
| k 1.5 | **sessizce kabul eder** (n = 64.5) | Dilim 9 tamsayı kontrolü yapıyor |
| güç .99 / α .001 | çalışır (169 / 156) | hayır |
| R² .99, k 1 | çalışır (n = 4); pwrss aynı girdide "not feasible" verir (Dilim 9: `err_infeasible_plan_reg_overall`) | plan zaten kurulamaz |

Karar: **korkuluk gerekir**, sessiz olmalı (satır bilgi, hata değil):

1. `requireNamespace("DMAR", quietly = TRUE)` yoksa `NULL`.
2. Plandaki `n_analytic` (pwrss, sabit) **100.000'i aşarsa DMAR çağrılmaz** (`NULL`): DMAR n'si neredeyse pwrss'e eşit olur ve çağrı çok yavaşlar (1.09 milyonda 21 sn). Eşik tek sabit (`RANDOM_N_MAX = 1e5`).
3. `tryCatch(error = ..., warning = ...)` ikisini de `NULL`'a çevirir.
4. Sonuç sonlu ve ≥ 1 değilse `NULL`.

DMAR yan etkileri: çağrı `print_progress = FALSE` varsayılanıyla sessiz; ek `cat` çıktısı görülmedi.

## Düzeltme sırası: kayıp ve DEFF bu satıra da uygulanır (karar, onaylandı)

**Öneri: evet, aynı sıra** (`× deff`, `/ (1 - dropout)`, tek `ceiling()`), çünkü satırın okunuşu "plandaki toplam katılımcı sayısıyla yan yana karşılaştır". Plan n'si `n_per_group` (kayıp ve DEFF dahil, alınması gereken sayı); aynı bakış için satır da alınması gereken sayıyı verirse öğrenci iki sayıyı doğrudan kıyaslar (77 → 80, kayıp %10 ile 86 → 89). Düzeltmesiz bir sayı yan yana yanıltır: öğrenci 80'i "ek 3 kişi" diye değil "gerçek n" diye okur ve kayıpla çarpmayı unutur.

Sınır: DMAR yalnız yukarı yuvarlanmış tamsayı `necessary_N` verir; tek yuvarlama ilkesinden **en çok 1 kişi** sapma olur (DMAR yuvarlar, sonra çarpılır, sonra yine yuvarlanır). `shortcut:` kod yorumunda yazılır; metinde "yaklaşık" denmez, çünkü bilgi satırının yanlış okunma riski ~ 1 kişidir ve satır zaten "öneri"dir. Örnek: R² .13, k 3, kayıp %10 → `ceiling(80 / 0.9)` = 89; pwrss tarafı `ceiling(76.985 / 0.9)` = 86 (3 fark).

Satır metni bunu söyler: "(kayıp ve tasarım etkisi dahil)", plandaki `plan_n_group_reg_overall` ile aynı kalıp.

## Kararlar (kullanıcı onayladı, 2026-11-14)

- **Yalnız `print`:** `print.plansize_plan` `reg_overall` planı için satırı ekler; `sensitivity()`, plan alanları, `write_methods()` **değişmez**. Satır yalnız etkileşimli bilgidir (açık soru 1: yöntem metnine cümle eklensin mi).
- **`test_spec` kancası:** `info_lines = function(x)` (karakter vektörü ya da `NULL`), tabloya isteğe bağlı alan. `print.plansize_plan` `spec$info_lines` varsa çağırır; `NULL` dönerse hiç satır yok. Diğer tüm testlerde alan yok (`NULL`), çıktı birebir aynı kalır.
- **İç işlev:** `random_predictor_n(r2, k, alpha, power, dropout, deff)` → tamsayı ya da `NULL`; `dmar_required_n(r2, k, alpha, power)` DMAR çağrısını saran en küçük işlev (testte taklit edilebilsin diye ayrı; `has_dmar()` yalnız `requireNamespace`).
- **CSV anahtarı** (tek): `plan_random_n`.

| key | en | tr |
|---|---|---|
| plan_random_n | Participants if the predictors are random (information only, includes dropout and design effect; the plan above treats predictors as fixed): %s | Yordayıcılar rastgeleyse katılımcı sayısı (yalnız bilgi, kayıp ve tasarım etkisi dahil; yukarıdaki plan yordayıcıları sabit varsayar): %s |

## Review Focus

- `reg_overall` planında DMAR kuruluyken satır var; `D:/rtmp/lib` olmayan oturumda yok ve `print` hata vermez.
- Plan n'si (77, 387, 43, 806 vb. Dilim 9 değerleri) değişmedi; `print` dışındaki hiçbir çıktı değişmedi.
- Satır sayısı: `dropout = 0.1` ve `deff = 1.5` ile `ceiling(DMAR_n * 1.5 / 0.9)`.
- DMAR hata/uyarı (taklit edilmiş) ve R² 1e-6 (`n_analytic` > 1e5) satırı **sessizce** atlar; `expect_silent`.
- Diğer testlerde (`t_independent`, `anova_oneway`, ...) `print` çıktısı birebir aynı (altın).
- `DESCRIPTION` `Suggests`'e `DMAR` eklendi, `Imports` değişmedi; `R CMD check` "'::' or ':::' import not declared" ya da "Suggests not available" bildirmiyor (DMAR kuruluyken).
- Satır "öneri/yalnız bilgi" dilinde; "yanlış plan" ya da "plan n'ine ekle" iddiası yok.

---

### Task 1: rastgele yordayıcı bilgi satırı

**Files:**
- Create: `R/random_predictors.R`, `tests/testthat/test-random-predictors.R`
- Modify: `R/tests.R` (`reg_overall` satırına `info_lines`), `R/print.R` (3 satır), `inst/i18n/messages.csv` (`plan_random_n`), `DESCRIPTION` (`Suggests: DMAR`), `docs/devlog.md` (dilim sonu)

**Interfaces:**
- `has_dmar()` → `requireNamespace("DMAR", quietly = TRUE)`.
- `dmar_required_n(r2, k, alpha, power)` → `DMAR::ss_power_R2(population_R2 = r2, p = k, alpha_level = alpha, desired_power = power, random_predictors = TRUE)`, sonuçtan `value[term == "necessary_N"]` (tek sayı).
- `random_predictor_n(plan)` → tamsayı ya da `NULL`: `has_dmar()` değilse `NULL`; `plan$n_analytic > RANDOM_N_MAX` ise `NULL`; `tryCatch(dmar_required_n(...), error = , warning = )` hata ya da uyarıda `NULL`; sonuç sonlu ve ≥ 1 değilse `NULL`; aksi hâlde `as.integer(ceiling(n * plan$deff / (1 - plan$dropout)))`.
- `test_spec$reg_overall$info_lines(x)` → `n <- random_predictor_n(x); if (is.null(n)) NULL else msg("plan_random_n", n)`.
- `print.plansize_plan`: `for (line in if (!is.null(spec$info_lines)) spec$info_lines(x)) cat(line, "\n")` (`plan_method` satırından sonra, `plan_note`'tan önce).

- [ ] **Step 1: Başarısız testleri yaz (`test-random-predictors.R`)**

Beklenen sayılar yalnız G*Power yayımlanmış değerinden ve DMAR/simülasyon ölçümlerinden; "kendi hesabın" yok.

```r
test_that("DMAR random-predictor power matches the published G*Power example", {
  skip_if_not_installed("DMAR")
  r <- DMAR::ss_power_R2(population_R2 = 0.10, p = 5, specified_N = 95, alpha_level = 0.05,
                         random_predictors = TRUE)
  expect_equal(r$value[r$term == "actual_power"], 0.662627, tolerance = 1e-4)  # Faul et al. 2009, ex. 1
})
test_that("random-predictor n for the measured cases", {
  skip_if_not_installed("DMAR")
  q <- function(r2, k, ...) plansize:::random_predictor_n(
    quiet_plan(test = "reg_overall", effect = r2, effect_type = "r2", predictors = k, ...))
  expect_identical(q(0.13, 3), 80L); expect_identical(q(0.02, 1), 390L)
  expect_identical(q(0.26, 5), 45L); expect_identical(q(0.50, 3), 18L)
  # plan n (pwrss, fixed) is unchanged and not larger than the random-predictor n
  expect_identical(quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)$n_total, 77L)
})
test_that("dropout and design effect use the plan's correction order", {
  skip_if_not_installed("DMAR")
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3,
                  dropout = 0.1, deff = 1.5)
  expect_identical(plansize:::random_predictor_n(p), as.integer(ceiling(80 * 1.5 / 0.9)))  # 134
})
test_that("random-predictor power at the DMAR n matches simulation (10,000 runs)", {
  skip_on_cran(); skip_if_not_installed("DMAR")
  sim <- function(r2, k, n, reps = 10000) {
    set.seed(1); b <- sqrt(r2 / k)
    mean(replicate(reps, {
      X <- matrix(rnorm(n * k), n, k); y <- drop(X %*% rep(b, k)) + rnorm(n, sd = sqrt(1 - r2))
      summary(lm(y ~ X))$fstatistic -> f; pf(f[1], f[2], f[3], lower.tail = FALSE) < 0.05 }))
  }
  for (z in list(c(0.13, 3), c(0.26, 5), c(0.50, 3))) {
    n <- plansize:::dmar_required_n(z[1], z[2], 0.05, 0.8)
    ap <- DMAR::ss_power_R2(population_R2 = z[1], p = z[2], alpha_level = 0.05, desired_power = 0.8)
    expect_lte(abs(sim(z[1], z[2], n) - ap$value[ap$term == "actual_power"]), 0.02)
  }
})
```

(`sim` bütün satırlarda `lm` ile yavaş olabilir (süre ölçülmedi); hızlandırmak için `.lm.fit` kullanılabilir, uygulayıcı karar verir.)

Korkuluk ve çıktı testleri:

```r
test_that("the info line is optional and silent on trouble", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  testthat::local_mocked_bindings(has_dmar = function() FALSE, .package = "plansize")
  expect_null(plansize:::random_predictor_n(p))
  expect_false(any(grepl("random", capture.output(print(p)), ignore.case = TRUE)))
  testthat::local_mocked_bindings(has_dmar = function() TRUE, .package = "plansize")
  for (f in list(function(...) stop("boom"), function(...) warning("NaNs"), function(...) NA_real_))
    { testthat::local_mocked_bindings(dmar_required_n = f, .package = "plansize")
      expect_silent(expect_null(plansize:::random_predictor_n(p))) }
  # very small R-squared: n_analytic > 1e5, DMAR is not called (slow, 21 s at 1e-5)
  testthat::local_mocked_bindings(dmar_required_n = function(...) stop("must not be called"), .package = "plansize")
  small <- quiet_plan(test = "reg_overall", effect = 1e-4, effect_type = "r2", predictors = 3)
  expect_null(plansize:::random_predictor_n(small))
})
test_that("print shows the line for reg_overall only", {
  skip_if_not_installed("DMAR")
  out <- capture.output(print(quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)))
  expect_true(any(grepl(msg("plan_random_n", 80), out, fixed = TRUE)))
  out2 <- capture.output(print(quiet_plan(effect = 0.5)))   # t test, unchanged
  expect_false(any(grepl(msg("plan_random_n", 80), out2, fixed = TRUE)))
})
```

`quiet_plan` Dilim 8-9'daki mevcut test yardımcısıdır (uyarıyı susturur); `local_mocked_bindings` testthat 3.2+ gerektirir (pwrss `Imports`, testthat `>= 3.0.0`: sürüm kontrolü yapılır, gerekirse `>= 3.2.0` yükseltilir).

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e ".libPaths(c('D:/rtmp/lib', .libPaths())); devtools::test(filter = 'random-predictors')"`
Expected: FAIL (`random_predictor_n` yok).

- [ ] **Step 3: Kodu, CSV'yi ve `DESCRIPTION`'ı ekle**

`random_predictor_n` kod yorumu: `shortcut: DMAR returns a rounded n, so deff and dropout are applied to a rounded value (at most 1 participant above a single final rounding); switch if DMAR ever returns the unrounded n.` Roxygen gerekmez (iç işlev, `@noRd`); `plan_study` belgesine bir cümle: "For `reg_overall`, print also shows the participants needed if predictors are random when the suggested package DMAR is installed."

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e ".libPaths(c('D:/rtmp/lib', .libPaths())); devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1` (DMAR ana kütüphanede kuruluyken ve kurulu değilken: iki çalıştırma, ikisi de yeşil).
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, kullanıcı okuması ve denemesi (kullanıcıya: `plan_study(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)` yazdır; R² .50 k 3 için 16 ve 18; bilerek hatalı: `predictors = 1.5`), anlama sorusu (neden 77 yetmiyor, F modeli yordayıcıyı ne sayıyor), `docs/devlog.md` girdisi. Commit yalnız istenirse (`feat: show random-predictor sample size`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/random_predictors.R` (`has_dmar`, `dmar_required_n`, `random_predictor_n`, yorumlar) | ~22 |
| `R/tests.R` (`info_lines` + bir satır) | ~5 |
| `R/print.R` | ~3 |
| `DESCRIPTION` | 1 |
| **Kod toplamı** | **~31** (kod+belge+yorum ile ~50-70) |
| `inst/i18n/messages.csv` | 1 satır (kod sayılmaz) |
| `tests/testthat/test-random-predictors.R` | ~75 (kod sayılmaz) |

150'nin çok altında; bölünmez.

## Önceki planlarla çelişki / etkileşim

- **Dilim 9:** plan n'si, `effect_test`, `predictors` ve `plan_note_reg_overall` (sabit yordayıcı notu) değişmez. Not hâlâ "rastgele yordayıcıda güç biraz düşük" der; bilgi satırı bunun sayısıdır. Çelişki yok, tamamlayıcıdır.
- **Dilim 11b** `simulate_power(plan, predictors = "random")` aynı farkı **simülasyonla** raporlar, `pass` hesaplamaz. 9c analitik bir bilgi satırıdır; DMAR n'si ile 11b'nin rastgele simülasyonu aynı olguyu iki yoldan gösterir. 11b'ye dokunulmaz; 11b `DMAR` gerektirmez (bu dilim yalnız bilgi). İsterse 11b çıktısı DMAR'ın `actual_power`'ıyla yan yana verilebilir: sonraya.
- **Spec §5, §8:** `Suggests`'e `DMAR` ve 9c satırı eklendi (bu plan ile birlikte spec güncellendi).
- **Spec §6 "çelişki kuralı":** DMAR n'si ile pwrss n'si **farklı yöntem** (rastgele ve sabit model); aralarındaki 2-3 kişilik fark başarısızlık değildir, satır bunu yöntem notu olarak taşır. ±1 toleransı uygulanmaz; pwrss ≈ `pwr` (aynı yöntem) kıyası Dilim 9'da kalır.
- **Lisans:** DMAR GPL (>= 3); paket MIT ve DMAR yalnız `Suggests`'te, kod DMAR'dan kopyalanmaz, `::` ile çağrılır. Bağlama yok. (CRAN aşamasında yine kontrol edilir.)

## Kullanıcı kararları (2026-11-14)

Kullanıcı aşağıdaki açık soruların hepsinde önerileri onayladı: yöntem metnine cümle yok; `reg_partial` bu dilimde yok; yalnız `print` satırı; n_analytic > 1e5 ise DMAR atlanır; DMAR dilim başında `D:/R-4.6.1/library` içine kurulur; satır her `reg_overall` çıktısında görünür; kayıp ve DEFF bu satıra da uygulanır.

## Açık sorular (yanıtlandı)

1. **Yöntem metni:** `write_methods()` rastgele yordayıcı bilgisine bir cümle eklesin mi? Örnek: "Yordayıcılar sabit varsayılmıştır; rastgele normal yordayıcılarda DMAR ile hesaplanan gerekli örneklem X'tir." Öneri: **hayır** bu dilimde. Gerekçe: metin planın hesabını anlatır; DMAR kurulu değilse paragraf makineye göre değişir (tekrarlanabilirlik). Evet derseniz yalnız DMAR kuruluyken eklenir ve metin makineye bağımlı olur (kötü yan etki).
2. **`reg_partial` (9b) için de geçerli mi?** Öneri: **bu dilimde hayır.** `DMAR::ss_power_R2` genel R² testi içindir (`null_R2 ≠ 0` doğrulanmadı, kullanılmaz). DMAR'ın tek yordayıcı işlevi `ss_power_reg_coef(rho2_Y_X, rho2_Y_X_without_j, p, ...)` mevcut; denendi: ΔR² .06 (R² .26, kovaryat .20), k 4, tested 1 → n = **99** (pwrss 99; yani rastgele-X farkı bu girdide görünmüyor ya da işlev sabit-X ile aynı sonucu veriyor; belgesi okunmadı, **doğrulanmadı**). 9b planındaki rastgele-X simülasyonu (n 55 → güç .771, analitik .80) bu çağrının sonucuyla karşılaştırılmadı. Bu yüzden `tested > 1` için DMAR çağrısı yok ve `tested = 1` için ayrı bir araştırma gerekir: 9c'den sonra ayrı küçük iş (9d) mı?
3. **Plan nesnesinde alan mı, yalnız print mi?** Öneri: yalnız `print`. Gerekçe: plan alanı DMAR kurulu olup olmamasına göre `NULL`/sayı olurdu (nesne makineye bağımlı), `print` her çağrıda 0.15 sn harcar (kabul). Alternatif: yeni dışa aktarılan `random_n(plan)` işlevi (örn. kullanıcı sayıyı koda alsın); ek ~15 satır. İster misiniz?
4. **Eşik 100.000:** DMAR çağrısını `n_analytic > 1e5` iken atlamak (R² ≲ 1e-4 için k 3) makul mu? R² .001, k 3 için DMAR n = 10.899 (hızlı); R² 1e-5 için 20.8 sn.
5. **`DMAR` ana kütüphaneye kurulsun mu?** Şu an yalnız `D:/rtmp/lib` içinde. Kullanıcı onaylarsa `install.packages("DMAR", lib = "D:/R-4.6.1/library")`; aksi hâlde DMAR testleri atlanır ve dilim kapanışı bekler.
6. **Satırın görünürlüğü:** DMAR kuruluyken her `reg_overall` çıktısında mı yoksa `print(x, details = TRUE)` gibi isteğe bağlı mı? Öneri: her çıktıda (bir satır, "yalnız bilgi" etiketli).
