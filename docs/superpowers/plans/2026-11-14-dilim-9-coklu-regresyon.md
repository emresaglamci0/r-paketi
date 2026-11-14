# Dilim 9: çoklu regresyon (genel R² F testi) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plan_study(test = "reg_overall", effect = , effect_type = "r2" | "f2", predictors = )` çoklu doğrusal regresyonda modelin genel R² F testi (H0: R² = 0) için gerekli toplam katılımcı sayısını, duyarlılığı, çıktıyı ve yöntem metnini verir.

**Architecture:** `test_spec`'e `reg_overall` satırı eklenir; motor `pwrss::power.f.reg` çağırır (`r.squared.change = R²`, `k.total = k.tested = predictors`). Başka dosyaya teste özgü dal eklenmez.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referans: `pwr::pwr.f2.test` (aynı yöntem, aşağıya bak).

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde n'de ±1; aşılırsa dur, toleransı genişletme.
- Düzeltme sırası: analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`.
- Eski altı testin çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-9-regression`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

- Fonksiyon `pwrss::power.f.reg(r.squared.change, margin = 0, k.total, k.tested = k.total, n, power, alpha, ceil.n, verbose)`. Genel R² testi için `r.squared.change = R²` ve `k.tested = k.total`. (`pwrss.f.reg` eski adlandırmadır, kullanılmaz.) `$n` ondalıklı **toplam** n (`df1 = k`, `df2 = n - k - 1`, ncp = f² × n, yani sabit-yordayıcı F modeli).
- Güç .80, α .05, `pwr::pwr.f2.test(u = k, f2 = R²/(1-R²))` ile toplam n = `v + k + 1` birebir aynı:

| R² | k | pwrss `$n` | pwr n | plan n |
|---|---|---|---|---|
| .02 | 1 | 386.5243 | 386.5243 | 387 |
| .13 | 3 | 76.98496 | 76.98495 | 77 |
| .26 | 5 | 42.40064 | 42.40064 | 43 |
| .02 | 10 | 805.0096 | 805.0095 | 806 |

  Ayrıca α .01 → 109.2074 (pwr 109.2074); güç .95 → 118.9001 (pwr 118.9001), R² .13 k 3. R² .5 k 2 → 13.1443 (pwr 13.1443).
- Güç hesabı: n = 100, R² .13, k 3 → .9037823 (pwr .9037823).
- Duyarlılık: n = 100, k 3, güç .80 için R² 0.10198 (pwr'dan f² 0.11355 → R² 0.10198). pwrss'in kendi araması bu aralıkta düz bölgeye takılmadı: bulunan R² ile güç geri hesaplanınca n = 77 → 0.80000, n = 40 güç .95 → 0.95000. Düz bölge yok, kök aramaya gerek yok. Yine de testte "mde ile güç geri hesabı" kontrolü var (Dilim 6 dersi).
- Uç durumlar: n ≤ k + 1 için "Design is not feasible." (k = 3: n = 4 hata, n = 5 → R² .9953; n = 3 güç hesabında NaN + uyarı). k = 1: n = 3 → .9889, n = 2 hata. R² = .999 "Design is not feasible."; R² = 1 ham hata "must be larger than 0 and smaller than 1". R² = 1e-8, k 3 → n 1.09e9 (hata vermez). R² .99, k 3 → 5.17.
- `k.tested < k.total` (kısmi test) pwr ile uyuşmaz: R² .13, k 3, tested 1 → pwrss 54.594, pwr (u = 1) 56.516. Fark ölçekten değil merkezi olmama parametresinin (ncp) tanımından gelir: pwrss ncp = f² × n, pwr ncp = f² × (u + v + 1) = f² × (n − (k − tested)) kullanır. Genel testte (tested = k) ikisi aynıdır, kısmi testte ayrılır (fark ≈ k − tested = 2 kişi). Bu nedenle **kısmi test bu dilimde kapsam dışı**, Dilim 9b'de ele alınır.
- Simülasyon (10.000 tekrar, n = 77, R² .13, k 3, yordayıcılar rastgele normal): ampirik güç 0.782; analitik güç ≈ 0.800. Fark 0.018, sınırın (0.02) hemen altı. Neden: F modeli yordayıcıları sabit varsayar, rastgele yordayıcılarda güç biraz düşer. Bu paketin kullanıcısının durumu da budur; belgeye ve metne yazılır (aşağıda). Dilim testinde simülasyon yalnız `skip_on_cran()` altında ve 20.000 tekrarla, ya da sabit tasarım matrisiyle (sınır tolerans 0.02 değişmez).

## pwr aynı yöntem mi?

Evet. `pwr.f2.test` de merkezi olmayan F dağılımı kullanır (ncp = f² × (u + v + 1)); 4 bileşimde 7 haneye kadar eşit. Tolerans ±1 geçerlidir. Tek dikkat: pwr'ın `v` değeri `df2`'dir; toplam n = `v + u + 1`. Test bu dönüşümü açıkça yazar. Yöntem farkı yok, çelişki kuralı gerekmez.

## Kararlar (kullanıcı onayladı, 2026-11-14)

Aşağıdakiler kullanıcı tarafından onaylandı; bkz. en alttaki "Kullanıcı kararları".

- Kapsam: yalnız modelin genel R² F testi (H0: R² = 0, tüm yordayıcılar birlikte). Tek yordayıcının t testi, kısmi/artımsal R² (ΔR²), hiyerarşik modeller, etkileşim, lojistik regresyon, düzeltilmiş R² **kapsam dışı**. n = toplam katılımcı, `groups` 1.
- Test adı `reg_overall`; Türkçe ad "çoklu regresyon (genel R² F testi)".
- Etki ölçüsü iki yolla girilir (ANOVA'daki f / η² örneği): `effect_type = "r2"` (R², aralık (0, 0.99]) ya da `"f2"` (Cohen f² = R²/(1-R²); R² karşılığı 0.99'u aşamaz, yani f² ≤ 99). Dönüşüm: `R² = f2 / (1 + f2)`. Öğrencinin ölçüleri karıştırma riski yüksek (f² .02/.15/.35 eşikleri, R² .02/.13/.26 karşılığı; "0.15" R² mi f² mi?). Önlem: **`effect_type` zorunlu**, varsayılanı yok. Verilmezse okunur hata: "effect_type must be r2 or f2". Böylece sessizce yanlış ölçü kullanılamaz.
- `effect_type` seçimi `exact = TRUE` ile tam eşleşir. Kısmi eşleşme tuzağı: imza varsayılanı `c("f", "eta2")` iken `pmatch("f", c("f2", "r2"))` sessizce `f2` seçerdi (ANOVA'nın `"f"`'i regresyonda anlam taşımaz). İmza varsayılanı `c("f", "eta2")` **değişmez** (kontrolcü doğruladı: genişletilirse `check_choice(c("f","eta2","f2","r2"), c("f","eta2"), ...)` hata verir ve `effect_type` verilmeyen her ANOVA çağrısı kırılır). Regresyon dalı sırasıyla: `missing(effect_type)` ise `err_effect_type_reg`; `length(effect_type) != 1` ise `err_effect_type_reg` (çünkü `check_choice`'taki `identical(x, choices)` kısayolu `c("r2","f2")`'yi sessizce `"r2"` yapar); sonra `check_choice(effect_type, c("r2", "f2"), "effect_type", exact = TRUE)`. ANOVA dalı ve kümesi (`f`, `eta2`) değişmez. Test: `effect_type` verilmeyen ANOVA çağrısı eskisi gibi `f` kullanır.
- Yordayıcı sayısı yeni argüman `predictors` (tek tam sayı, 1-1000; `k` ANOVA'nın grup sayısı olduğu için yeniden kullanılmaz, karışır). Belge: ölçülen yordayıcı sayısı, kategorik değişken dummy sayısıyla sayılır (4 düzeyli bir değişken 3). `predictors` başka testte verilirse `err_predictors_unused`.
- Etki tanımı belgede: R² modelin tümünün açıkladığı varyans oranı (kesim hariç), düzeltilmiş R² değil; f² Cohen'in `R²/(1-R²)` ölçüsü, kısmi f² değil. Kaynak makaledeki R² "adjusted" ise doğrudan girilmez; uyarısı belgede.
- `effect` açık aralıkta; `r2` 0'dan büyük 0.99'a kadar (0.99 dahil); `f2` 0'dan büyük, R² karşılığı ≤ 0.99. R² = 1 ya da 1'e yuvarlanan f² ham pwrss hatası verirdi; bu aralık onu önceden keser. 0.99 sınırı "not feasible" durumunu önlemez: pwrss `uniroot` ile n'yi `c(k + 2, 1e10)` aralığında arar. Gereken n `k + 2`'den küçükse (ör. R² .99, k 1, güç .8, α .05; `pwr` de aynı girdide hata verir) ya da 1e10'dan büyükse (ör. R² 1e-8, k 1000) "Design is not feasible." döner, paket bunu `err_infeasible_plan_reg_overall` olarak verir. Duyarlılıkta bulunan R² 0.99'u aşabilir (k 3, n 5 → 0.9953); 0.99 kontrolü yalnız girdiye uygulanır, `sensitivity()` çıktısına uygulanmaz.
- Yön yok (`directional = FALSE`); `alternative` verilirse hata (`err_alt_reg`).
- `k`, `p1`, `p2`, `r`, `rows`, `cols` bu testte verilirse hata (mevcut `reject_*` yardımcıları ve tek `err_r_unused`, `err_k_unused`). Tek karışık yer: `effect_type` ANOVA'da da kullanılıyor; `reject_anova_args` bu testte `effect_type`'ı reddetmemeli, çünkü regresyon dalı kendi `reject_*` çağrılarını yapar; başka testler `effect_type = "r2"` verilirse `check_choice` hatası verir.
- Etkin n alt sınırı: spec'teki `min_n` sabit sayıdır ama regresyonda `predictors`'a bağlıdır (n ≥ k + 2). `min_n = 3` konur (k = 1'in sınırı); k büyükse küçük etkin n'de `sensitivity`'nin `guard_pwrss` hatası (`err_infeasible`) devreye girer. Alternatif: `min_n`'i fonksiyon yapmak, bu başka dosyaları etkiler, önerilmez.

## Review Focus

- `predictors` büyüdükçe n artar (R², α, güç sabitken); R² büyüdükçe n azalır.
- `effect_type` verilmeden, `"f"` ya da `"f2 "` ile çağrı okunur hata verir; `"f2"` ve `"r2"` aynı planı verir (f² = .15 ↔ R² = .15/1.15).
- Metin hangi ölçüyle girildiğini ve karşılığını (f² girdiyse R², R² girdiyse f²) yazar; öğrenci yanlış ölçüyü girdiyse çıktıda görür.
- Metin sabit yordayıcı varsayımını (F modeli, rastgele yordayıcılarda güç biraz düşük) ve genel R² testi olduğunu söyler; "tek yordayıcı anlamlı olacak" gibi bir iddia yok.
- R² = 1, 0, 1e-12, f² = 1e6 ham pwrss hatası vermez.
- Elle bozulmuş `reg_overall` planı (`predictors` silinmiş, `effect_type = "f"`, `effect_test` ≠ R² karşılığı) her fonksiyonda `err_plan` verir.
- Düz bölge: `mde` testi bulunan değerle gücü geri hesaplar.

---

### Task 1: çoklu regresyon genel R² testi

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `inst/i18n/messages.csv`, `tests/testthat/test-anova.R` (uyarı taraması), `tests/testthat/test-chisq.R` yok, dokunma
- Create: `tests/testthat/test-reg.R`

**Interfaces:**
- `plan_study()` imzasına `predictors = NULL` eklenir, `given` ve `args`'a girer; `effect_type` varsayılanı `c("f", "eta2")` olarak kalır (bkz. Kararlar). `@param predictors` ve `effect_type` belgesi güncellenir (R²/f² tanımı, adjusted R² uyarısı, yordayıcı sayma kuralı, sabit-yordayıcı notu `@details`'te).
- `engine_n_reg(r2, k, alpha, power)` → ondalıklı toplam n (`pwrss::power.f.reg(r.squared.change = r2, k.total = k, power, alpha, ceil.n = FALSE, verbose = 0)$n`, `guard_pwrss(..., "err_infeasible_plan_reg_overall")`).
- `engine_mde_reg(n, k, alpha, power)` → R² (`r.squared.change = NULL, n = n`); `mde` kullanıcının girdiği birime çevirir (f2 ise `r2 / (1 - r2)`).
- `test_spec$reg_overall`: `directional = FALSE`, `groups` 1, `min_n = 3`, plan alanları `predictors` (`as.integer`), `effect_type` (`"r2"` / `"f2"`), `effect_test` = R², `method = "f_reg_overall_r2"`. `check`: `effect_type` iki değerden biri, `predictors` 1-1000 tam sayı, `effect_test` (0, 0.99], `effect` ile tutarlı (`effect_type == "r2"` → `effect == effect_test`; `"f2"` → `effect_test == effect / (1 + effect)`, `all.equal`).
- `variant(plan)`: `c("reg_overall_f2", "reg_overall")` ya da `"reg_overall"` (ANOVA'nın `variant_anova` kalıbı; `variant_anova` değiştirilmez, ayrı küçük işlev).
- `reject_*` kullanımı: `reject_p_args`, `reject_table_args`, `k`, `r` kontrolleri `prepare` içinde, ANOVA ile aynı sıra.

**CSV (metinler aynen; `reg_overall` = test adı)**

| key | en | tr |
|---|---|---|
| val_reg_overall | multiple regression (overall R-squared F test) | çoklu regresyon (genel R² F testi) |
| m_intro_reg_overall | `m_intro_cor_pearson` ile aynı kalıp (", a %1$s."), çünkü `m_intro`'nun "(%1$s)" biçimi parantezli test adıyla çift parantez üretir | `m_intro` TR metniyle aynı |
| err_effect_type_unused (değişir) | Argument 'effect_type' is used only with test = "anova_oneway" or "reg_overall". | Argüman 'effect_type' yalnız test = "anova_oneway" ya da "reg_overall" ile kullanılır. |
| err_r2 | For effect_type = "r2", 'effect' must be the model R-squared, a single number greater than 0 and at most 0.99. | effect_type = "r2" için 'effect' modelin R² değeri olmalı: 0'dan büyük, en fazla 0,99 olan tek bir sayı. |
| err_f2 | For effect_type = "f2", 'effect' must be Cohen's f-squared, a single number greater than 0 and at most 99 (R-squared = f2 / (1 + f2) at most 0.99). | effect_type = "f2" için 'effect' Cohen f² olmalı: 0'dan büyük, en fazla 99 olan tek bir sayı (R² = f2 / (1 + f2) en fazla 0,99). |
| err_effect_type_reg | For test = "reg_overall", 'effect_type' is required and must be "r2" or "f2" (R-squared or Cohen's f-squared). | test = "reg_overall" için 'effect_type' zorunlu ve "r2" ya da "f2" olmalı (R² ya da Cohen f²). |
| err_predictors | Argument 'predictors' must be a single whole number from 1 to 1000. | 'predictors' argümanı 1 ile 1000 arasında tek bir tam sayı olmalı. |
| err_predictors_unused | Argument 'predictors' is used only with test = "reg_overall". | 'predictors' argümanı yalnız test = "reg_overall" ile kullanılır. |
| err_alt_reg | The overall F test of a regression has no direction; do not set 'alternative'. | Regresyonun genel F testinin yönü yoktur; 'alternative' belirtmeyin. |
| err_infeasible_plan_reg_overall | pwrss cannot solve this design: the effect is either so large that fewer than predictors + 2 participants would suffice, or so small that more than 10 billion would be needed. Check effect, effect_type, predictors, alpha and power. | pwrss bu tasarımı çözemiyor: etki ya yordayıcı sayısı + 2'den az katılımcının yeteceği kadar büyük ya da 10 milyardan fazla katılımcı gerektirecek kadar küçük. effect, effect_type, predictors, alpha ve power değerlerini kontrol edin. |
| plan_effect_reg_overall | Expected effect size (R-squared): %s | Beklenen etki büyüklüğü (R²): %s |
| plan_effect_reg_overall_f2 | Expected effect size (Cohen's f-squared): %s | Beklenen etki büyüklüğü (Cohen f²): %s |
| plan_r2 | Equivalent R-squared: %s | Karşılık gelen R²: %s |
| plan_predictors | Number of predictors: %s | Yordayıcı sayısı: %s |
| plan_n_group_reg_overall | Participants to recruit (includes dropout and design effect): %s | Alınması gereken katılımcı sayısı (kayıp ve tasarım etkisi dahil): %s |
| sens_title_reg_overall | Smallest detectable effect (R-squared) | Saptanabilir en küçük etki (R²) |
| sens_title_reg_overall_f2 | Smallest detectable effect (Cohen's f-squared) | Saptanabilir en küçük etki (Cohen f²) |
| col_n_recruited_reg_overall | Recruited participants | Alınan katılımcı |
| col_n_effective_reg_overall | Effective participants | Etkin katılımcı |
| m_effect_reg_overall | The effect size used for planning was R-squared = %s%s for a regression model with %s predictors. | Planlamada %3$s yordayıcılı regresyon modeli için etki büyüklüğü R² = %1$s olarak alınmıştır%2$s. |
| m_effect_reg_overall_f2 | The effect size used for planning was Cohen's f-squared = %s%s (R-squared = %s) for a regression model with %s predictors. | Planlamada %4$s yordayıcılı regresyon modeli için etki büyüklüğü Cohen f² = %1$s%2$s (R² = %3$s) olarak alınmıştır. |
| m_result_reg_overall | For the overall F test of the regression model (H0: R-squared = 0) with alpha = %s and power = %s, the required sample size was %s participants in total. Predictors were treated as fixed; with random predictors the power is slightly lower. | Alfa = %s ve güç = %s için regresyon modelinin genel F testinde (H0: R² = 0) gerekli örneklem büyüklüğü toplam %s katılımcıdır. Yordayıcılar sabit varsayılmıştır; rastgele yordayıcılarda güç biraz düşüktür. |
| m_adjust_dropout_reg_overall, m_adjust_deff_reg_overall, m_adjust_both_reg_overall | Dilim 8'deki üç anahtarla aynı kalıp, `chisq_indep` yerine `reg_overall` | aynı |

R² ve f² metinde `fmt_num()` ile (`0.13`). Dönüştürülen değer (f² girdiyse R², R² girdiyse f²) önce `round(., 2)` ile yuvarlanır (ANOVA'nın `round(effect_test, 2)` kalıbı); yoksa f² .15 için R² 0.1304348 yazılır. Kaynak parantezi `%2$s` içinde, çift parantez testle kontrol edilir (`m_result` cümlesindeki parantez `(H0: ...)` kaynak parantezi ile art arda gelmez, çünkü kaynak etki cümlesinde).

- [ ] **Step 1: Başarısız testleri yaz (`test-reg.R`)**

Referans tablo (beklenen değerler yalnız `pwr`'dan; toplam n = `v + u + 1`):

```r
test_that("regression n matches pwr", {
  for (R2 in c(0.02, 0.13, 0.26, 0.5)) for (k in c(1, 3, 5, 10))
    for (a in c(0.05, 0.01)) for (pw in c(0.8, 0.9)) {
      f2 <- R2 / (1 - R2)
      ref <- pwr::pwr.f2.test(u = k, f2 = f2, sig.level = a, power = pw)$v + k + 1
      expect_lte(abs(engine_n_reg(R2, k, a, pw) - ref), 1)
    }
})
```
64 bileşim. Sabit kıyas: `engine_n_reg(0.13, 3, 0.05, 0.8)` ≈ 76.985.

```r
test_that("reg_overall plan", {
  q <- function(...) quiet_plan(test = "reg_overall", ...)
  p <- q(effect = 0.13, effect_type = "r2", predictors = 3)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(77L, 77L, 1L))
  expect_identical(q(effect = 0.02, effect_type = "r2", predictors = 1)$n_total, 387L)
  expect_identical(q(effect = 0.26, effect_type = "r2", predictors = 5)$n_total, 43L)
  expect_identical(q(effect = 0.02, effect_type = "r2", predictors = 10)$n_total, 806L)
  expect_identical(q(effect = 0.13, effect_type = "r2", predictors = 3, dropout = 0.1)$n_total, 86L)
  # f2 and r2 are the same plan
  expect_identical(q(effect = 0.15, effect_type = "f2", predictors = 3)$n_total,
                   q(effect = 0.15 / 1.15, effect_type = "r2", predictors = 3)$n_total)
})
```

Hata girdileri (hepsi `fixed = TRUE` ve `msg()` ile):

```r
test_that("reg_overall arguments are validated", {
  bad_eff <- list(0, 1, 0.995, -0.1, NA_real_, c(0.1, 0.2), "a")
  for (bad in bad_eff) expect_error(plan_study(test = "reg_overall", effect = bad, effect_type = "r2", predictors = 3), "'effect'", fixed = TRUE)
  for (bad in list(0, -1, 100, 1e6, NA_real_, "a"))
    expect_error(plan_study(test = "reg_overall", effect = bad, effect_type = "f2", predictors = 3), "'effect'", fixed = TRUE)
  # effect_type: required, exact match only
  expect_error(plan_study(test = "reg_overall", effect = 0.1, predictors = 3), "'effect_type'", fixed = TRUE)
  for (bad in list("f", "eta2", "r", "f2 ", NA_character_, c("f2", "r2")))
    expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = bad, predictors = 3), "'effect_type'", fixed = TRUE)
  for (bad in list(NULL, 0, 1.5, 1001, NA_real_, "a"))
    expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = bad), "'predictors'", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, alternative = "one.sided"), "alternative", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, k = 3), "'k'", fixed = TRUE)
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3, rows = 2), "'rows'", fixed = TRUE)
  expect_error(plan_study(effect = 0.5, predictors = 3), "reg_overall", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.5, k = 3, effect_type = "r2"), "'effect_type'", fixed = TRUE)
  # near-impossible design returns the readable error, not the raw pwrss one
  for (args in list(list(effect = 0.99, predictors = 1), list(effect = 1e-8, predictors = 1000)))
    expect_identical(tryCatch(do.call(plan_study, c(list(test = "reg_overall", effect_type = "r2"), args)),
      error = conditionMessage), msg("err_infeasible_plan_reg_overall"))
  # neighbour that still works
  expect_identical(quiet_plan(test = "reg_overall", effect = 0.98, effect_type = "r2", predictors = 1)$n_total, 4L)
})
```

İki uç girdi Opus tarafından doğrulandı (pwrss 1.3.3, güç .8, α .05): R² .99 k 1 ve R² 1e-8 k 1000 "Design is not feasible."; R² .98 k 1 → 3.136974.

Duyarlılık:

```r
test_that("reg_overall sensitivity", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  s <- sensitivity(p, n = 100, power = 0.8)
  f2 <- pwr::pwr.f2.test(u = 3, v = 100 - 3 - 1, power = 0.8)$f2
  expect_equal(s$mde, f2 / (1 + f2), tolerance = 0.001)
  # power at the returned mde is the target (no flat-region artifact)
  expect_equal(pwrss::power.f.reg(r.squared.change = s$mde, k.total = 3, n = 100, verbose = 0)$power, 0.8, tolerance = 1e-3)
  pf <- quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3)
  expect_equal(sensitivity(pf, n = 100, power = 0.8)$mde, f2, tolerance = 0.001)
  expect_identical(tryCatch(sensitivity(p, n = 2), error = conditionMessage), msg("err_n_small", 2, 3))  # below min_n
  for (n in 3:4)  # n <= predictors + 1: pwrss "Design is not feasible."
    expect_identical(tryCatch(sensitivity(p, n = n), error = conditionMessage), msg("err_infeasible"))
})
```

`n = 3` ve `n = 4` (k = 3) için pwrss "Design is not feasible." verir (kontrolcü doğruladı); `min_n = 3` olduğundan `err_n_small` yalnız `n = 2` ve altında gelir.

Metin ve çıktı:

```r
test_that("reg_overall methods and print", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3, effect_source = "Yilmaz, 2021")
  x <- unclass(write_methods(p, lang = "en"))
  expect_match(x, "R-squared = 0.13 (Yilmaz, 2021) for a regression model with 3 predictors.", fixed = TRUE)
  expect_match(x, "the required sample size was 77 participants in total.", fixed = TRUE)
  expect_match(x, "Predictors were treated as fixed", fixed = TRUE)
  expect_false(grepl("))", x, fixed = TRUE)); expect_false(grepl(") (", x, fixed = TRUE))
  pf <- quiet_plan(test = "reg_overall", effect = 0.15, effect_type = "f2", predictors = 3)
  expect_match(unclass(write_methods(pf, lang = "en")), "Cohen's f-squared = 0.15", fixed = TRUE)
  expect_match(unclass(write_methods(pf, lang = "en")), "R-squared = 0.13)", fixed = TRUE)
  t <- unclass(write_methods(p, lang = "tr"))
  expect_match(t, "3 yorday\u0131c\u0131l\u0131 regresyon modeli", fixed = TRUE)
  out <- withr::with_options(list(plansize.lang = "en"), capture.output(print(p)))
  expect_true(any(grepl("Number of predictors: 3", out, fixed = TRUE)))
  expect_false(any(grepl("Alternative hypothesis", out, fixed = TRUE)))
})
```

(Türkçe satırdaki harfler `\u00fd` vb. kaçışlarla yazılır; düzenleme aracının `\u` kaçışlarını gerçek harfe çevirdiği Dilim 7'de görüldü, yazdıktan sonra `grep -P "[^\x00-\x7F]"` ile kontrol et.)

Elle bozulmuş plan:

```r
test_that("tampered reg_overall plans are refused", {
  p <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  for (bad in list(list(predictors = NULL), list(predictors = 0L), list(effect_type = "f"),
                   list(effect_type = NA_character_), list(effect_test = 0.5), list(effect = 1.5, effect_test = 1.5)))
  { q <- utils::modifyList(p, bad); class(q) <- class(p)
    expect_error(print(q), "plan_study()", fixed = TRUE)
    expect_error(sensitivity(q), "plan_study()", fixed = TRUE)
    expect_error(write_methods(q), "plan_study()", fixed = TRUE) }
})
```

`test-anova.R` uyarı taramasına `list(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)` eklenir. Altın dosya: eski altı testin çıktısı değişmemeli; `devtools::test()` içinde mevcut altın test yeşil kalmalı, dosyayı yenileme.

Simülasyon testi bu dilimde yazılmaz. Kullanıcı kararıyla yayından önce (Dilim 13 öncesi) tüm testler için birlikte yapılır. Plan metnindeki not (sabit yordayıcı) bu dilimde kalır.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'reg')"`
Expected: FAIL.

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0` (altın dahil), `Status: OK`. `devtools::document()` sonrası `man/` güncel.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi, `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan multiple regression overall F test`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/tests.R` (`reg_overall` satırı, `variant`, `check`, `effect_lines/sentence`) | ~50 |
| `R/engine.R` (`engine_n_reg`, `engine_mde_reg`) | ~14 |
| `R/plan.R` (`predictors`, `given`, `args`, roxygen) | ~14 |
| **Kod toplamı** | **~78** |
| `inst/i18n/messages.csv` | ~22 satır (kod sayılmaz) |
| `tests/testthat/test-reg.R` | ~95 (kod sayılmaz) |

150 satır hedefinin altında; **bölme gerekmez**. Tek dal.

## Kullanıcı kararları (2026-11-14)

1. R² ve f² ikisi de kabul edilir; `effect_type` zorunlu, varsayılanı yok, tam eşleşme.
2. Argüman adı `predictors` (Opus kararı: `k` ANOVA'da grup sayısı). Kategorik değişken dummy sayısıyla sayılır.
3. Üst sınır R² ≤ 0.99, f² ≤ 99.
4. Sabit yordayıcı varsayımı yalnız metin ve belgede not; n'ye güvenlik payı eklenmez.
5. Kısmi/artımsal R² (ΔR²) ve tek yordayıcı t testi ayrı dilim (spec §8, Dilim 9b). Bu dilimde kapsam dışı.
6. Düzeltilmiş R²'nin doğrudan girilmesi belgede yasaklanır; dönüştürme yardımcısı yok.
7. Simülasyon testi bu dilimde yok; yayından önce tüm testler için yapılır.
8. `err_infeasible_plan_reg_overall` kalır. Araştırma ajanı gerçekçi uç girdi buldu (R² .99, k 1; gereken n `k + 2` alt sınırının altında). Metin iki nedeni de söyler: etki çok büyük ya da çok küçük.

## Açık sorular (yanıtlandı, yukarıya bak)

1. **Etki ölçüsü:** R² ve f² ikisi de mi (öneri, `effect_type` zorunlu), yalnız R² mi, yalnız f² mi? İki ölçü kolaylık sağlar ama karışıklık riski taşır; zorunlu `effect_type` ile önlenir. Hangisini öğretmek istersin?
2. **Yordayıcı sayısı argümanı adı:** `predictors` (öneri) mi, `k` mi (ANOVA ile karışır)? Kategorik yordayıcı dummy sayısıyla sayılsın mı?
3. **Üst sınır:** R² ≤ 0.99 ve f² ≤ 99 kabul mü? (pwrss R² = 1'de ham hata veriyor, 0.99 üstü gerçekçi değil.)
4. **Sabit yordayıcı notu:** F modeli yordayıcıları sabit varsayar; rastgele yordayıcılarda simülasyonda güç 0.78 (hedef .80, n = 77). Metne ve belgeye bu cümleyi eklemek yeterli mi, yoksa n'ye küçük bir güvenlik payı mı eklensin (öneri: yalnız not, pwrss yöntemi korunur)?
5. **Kısmi/artımsal R² (ΔR²) ve tek yordayıcı t testi** ayrı dilim ya da kapsam dışı mı? pwrss kısmi testte pwr ile uyuşmuyor (54.59 vs 56.52), yani bir sonraki dilimde yöntem farkı ve çelişki kuralı gerekir.
6. **Düzeltilmiş R²:** makaledeki "adjusted R²"yi doğrudan girmeyi belgede açıkça yasaklayalım mı (öneri), yoksa dönüştürme yardımcısı mı?
7. **Simülasyon:** dilimde isteğe bağlı simülasyon testi mi (n = 77, 20.000 tekrar), yoksa Dilim 11'e mi bırakılsın?
