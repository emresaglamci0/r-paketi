# Dilim 9b: kısmi / artımsal R² (ΔR²) ve tek yordayıcı testi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşul:** Dilim 9 (`reg_overall`) `main`'e birleşmiş olmalı. Bu plan onun arayüzüne dayanır (`predictors`, `effect_type`, `engine_n_reg`, `test_spec$reg_overall`). Dilim 9 dosyası değiştirilmedi; çelişkiler en altta.

**Goal:** `plan_study(test = "reg_partial", effect = , effect_type = "r2_change" | "f2", predictors = , tested = , r2_covariates = )` regresyonda `tested` yordayıcıdan oluşan kümenin katkısı için (H0: ΔR² = 0; `tested = 1` ise tek yordayıcının iki yönlü t testi) gerekli toplam katılımcı sayısını, duyarlılığı, çıktıyı ve yöntem metnini verir.

**Architecture:** `test_spec`'e `reg_partial` satırı eklenir. Motor Dilim 9'daki `engine_n_reg`/`engine_mde_reg` işlevlerini `tested` argümanıyla genişletir ve `pwrss::power.f.reg(r.squared.change = KISMI R², k.total = predictors, k.tested = tested)` çağırır. Önemli: `pwrss`'e verilen değer ΔR² değil **kısmi R²** = `ΔR² / (1 - r2_covariates)` (aşağıdaki "Neden" bölümüne bak). Başka dosyaya teste özgü dal eklenmez.

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referanslar: sabit-tasarım simülasyonu (aynı yöntem), `power.t.reg` (tek yordayıcı, aynı yöntem), `pwr::pwr.f2.test` yalnız dönüştürülmüş biçimde (aynı yöntem) ve düz biçimde (**farklı yöntem**, aşağıya bak).

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§8 madde 9b)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Hesap `pwrss`'ten gelir, `ceil.n = FALSE`. Tolerans aynı yöntemde n'de ±1; aşılırsa dur, toleransı genişletme. Farklı yöntemde fark başarısızlık değildir, testin yöntem notuna yazılır (çelişki kuralı).
- Düzeltme sırası: analitik n, `× deff`, `/ (1 - dropout)`, tek `ceiling()`.
- Eski testlerin (Dilim 1-9) çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-9b-regression-partial`. Commit yalnız kullanıcı onayından sonra.

## Neden pwrss ile pwr uyuşmuyor (kaynak koddan, denendi)

`power.f.reg` kaynağı (pwrss 1.3.3):

- `df1 = k.tested`, `df2 = n - k.total - 1`, `f2 = r.squared.change / (1 - r.squared.change)`, **`lambda = f2 * n`**.
- `pwr::pwr.f2.test`: Cohen (1988) tanımı, **`lambda = f2 * (u + v + 1)`** ve `v = n - k.total - 1`; yani `lambda = f2 * (n - (k.total - k.tested))`.

Genel testte (`tested = k.total`) iki ifade aynıdır, bu yüzden Dilim 9'da birebir uyuşur. Kısmi testte pwr'nin `lambda`'sı `k.total - k.tested` kovaryat kadar küçülür; sonuç n daha büyük çıkar. Fark ΔR² ölçeğinden değil **ncp tanımından** gelir. Ölçülen fark (R² .13, k 3, tested 1: pwrss 54.594, pwr 56.516; fark 1.92 < k - tested = 2). Altı bileşimde fark hep `0 < fark < k.total - k.tested`.

**Hangisi doğru?** Sabit tasarım matrisinde gerçek ncp `f2 * n`'dir (sütunları dik, varyansı 1 olacak biçimde kurulmuş X, 40.000 tekrar, yordayıcılar sabit):

| Durum (ΔR² / kovaryat R² / k / tested / n) | pwrss analitik | pwr (Cohen) analitik | simülasyon |
|---|---|---|---|
| .13 / 0 / 3 / 1 / 55 | .8030 | .7884 | .8058 |
| .10 / .20 / 5 / 2 / 71 | .8021 | .7837 | .8028 |
| .05 / .10 / 10 / 1 / 120 | .7497 | .7166 | .7471 |
| .26 / 0 / 6 / 3 / 40 | .8553 | .8243 | .8576 |

`pwrss` sabit-yordayıcı (fixed model) F testinin doğrusudur (G*Power "R² increase, fixed model" ile aynı `lambda = f2 * N`). `pwr` Cohen'in yaklaşık formülüdür; kısmi testte biraz büyük n verir (muhafazakâr). **Aynı yöntem referansı:** sabit-tasarım simülasyonu ve `pwr` işlevinin `f2`'si `f2 * n / (n - k + tested)` ile ölçeklenmiş hâli (aynı noncentral F dağılımı, `lambda = f2 * n` yapılır). Düz `pwr.f2.test` **farklı yöntemdir**.

## Etki ölçüsü: pwrss'in `r.squared.change` adı yanıltıcı

`pwrss` `f2 = ΔR² / (1 - ΔR²)` hesaplar. Cohen'in küme f²'si `f2 = ΔR² / (1 - R²_tam)`'tır (R²_tam = kovaryat R² + ΔR²). İkisi yalnız kovaryatlar hiç varyans açıklamıyorsa eşittir. Doğru f², `pwrss`'e **kısmi R²** (= `f2 / (1 + f2)` = `ΔR² / (1 - R²_kovaryat)`) verilerek elde edilir. Doğrulandı: ΔR² .10, kovaryat R² .20, k 5, tested 2 → f² .1429, kısmi R² .125, pwrss n 70.667 (sabit-tasarım simülasyonu n = 71'de .8028). Naif `r.squared.change = .10` verilseydi n 89.885 çıkardı (gereksiz büyük). Bu paket her zaman kısmi R²'yi `pwrss`'e verir.

## Doğrulanmış gerçekler (pwrss 1.3.3, denendi)

Güç .80, α .05, toplam n:

| ΔR² | kovaryat R² | k | tested | f² | kısmi R² | pwrss `$n` | plan n | pwr düz (farklı yöntem) |
|---|---|---|---|---|---|---|---|---|
| .06 | .20 | 4 | 1 | .0811 | .0750 | 98.8231 | 99 | 101.761 |
| .10 | .20 | 5 | 2 | .1429 | .1250 | 70.6673 | 71 | 73.527 |
| .13 | 0 | 3 | 1 | .1494 | .1300 | 54.5943 | 55 | 56.516 |
| .05 | .10 | 10 | 1 | .0588 | .0556 | 135.5190 | 136 | 144.378 |
| .26 | 0 | 6 | 3 | .3514 | .2600 | 35.6005 | 36 | 38.194 |
| .02 | .30 | 8 | 2 | .0294 | .0286 | 330.6497 | 331 | 336.594 |

- Dönüştürülmüş pwr (`f2 * n / (n - k + tested)`) ile plan n'de güç ≥ .80 ve n - 1'de < .80 (aynı yöntem, tam tamsayı ölçütü): (99: .8007 / .7966), (71: .8021 / .7958), (55: .8030 / .7955), (136: .8014 / .7985), (36: .8057 / .7912), (331: .8004 / .7992).
- α .01, güç .80 (ΔR² .10, kovaryat .20, k 5, tested 2) → 101.9848; güç .90, α .05 → 91.7533. f² .15, k 5, tested 2 → 67.4674 (plan 68).
- `tested = k.total` → `pwrss` Dilim 9 ile aynı (R² .13, k 3 → 76.98495).
- **Tek yordayıcı:** `power.t.reg(beta = sqrt(.06), k.total = 4, r.squared = .26, power = .8)` iki yönlü n = 98.82305; `power.f.reg(.06/.8, k.total = 4, k.tested = 1)` n = 98.82305 (birebir). Yani `tested = 1` iki yönlü t testidir. Tek yönlü t testi aynı tasarım için 77.698 (bu dilimde **kapsam dışı**, açık soru 4).
- Duyarlılık: n = 100, k 5, tested 2, güç .80 → kısmi R² 0.09048 (f² 0.0995; ΔR² = .09048 × (1 - kovaryat R²), kovaryat .20 için 0.07239). Geri hesap: güç .80000. n 10-1000 ve güç .5/.8/.95 ızgarasında düz bölge yok (hepsinde geri hesaplanan güç hedefe eşit).
- Uç durumlar: `k.tested > k.total` → "`k.tested` can not be greater than `k.total`."; `k.tested = 0` ham hata; `k.tested = 1.5` **sessizce kabul edilir** (`power.f.reg(r.squared.change = .13, k.total = 3, k.tested = 1.5, power = .8, ceil.n = FALSE)` n = 61.82 verir; tested = 1 için 54.59), yani tamsayı kontrolü pakette yapılmalı. Kısmi R² .99, güç .99, k 3, tested 1 → n 5.17 (hata yok).
- Rastgele yordayıcı (random-X) simülasyonu (10.000 tekrar): ΔR² .13, k 3, tested 1, n 55 → .771; ΔR² .10, kovaryat .20, k 5, tested 2, n 71 → .771. Analitik .80. Fark ≈ .03 (> .02). Bkz. Dilim 9 çelişkileri.

## Kararlar (öneri; kullanıcı onayı gerekir, açık sorulara bak)

- Ayrı test adı `reg_partial` (Dilim 9'daki `reg_overall` genişletilmez): metin, `effect` anlamı ve `check` farklı. Türkçe ad "çoklu regresyon (kısmi R² / ΔR² F testi)". `groups` 1, `directional = FALSE`, `alternative` verilirse hata (`err_alt_reg` Dilim 9'dan yeniden kullanılır).
- Argümanlar: `predictors` (modeldeki **toplam** yordayıcı, test edilenler dahil; Dilim 9 ile aynı sayma kuralı), `tested` (tek tam sayı, 1 ile `predictors - 1` arası; `tested = predictors` genel test olduğundan `reg_overall` önerisiyle hata: `err_tested`), `effect_type` zorunlu (varsayılan yok, tam eşleşme): `"r2_change"` (ΔR²) ya da `"f2"` (küme f²).
- `r2_covariates`: yalnız `effect_type = "r2_change"` ile **zorunlu** (0 dahil, 1 hariç; tam model R² = `r2_covariates + effect` en çok .99). `"f2"` ile verilirse hata (`err_r2cov_unused`): f² zaten kovaryatı içerir. Böylece ΔR²'yi kovaryatları söylemeden girip yanlış (naif) n alma yolu kapanır.
- Dönüşüm: `r2_change` için kısmi R² = `effect / (1 - r2_covariates)`; `f2` için kısmi R² = `effect / (1 + effect)`. `effect_test` = kısmi R² (engine'e giden değer). `effect` hep kullanıcının girdisi. `f2` aralığı (0, 99] ve ΔR² karşılığı kısmi R² ≤ .99.
- Plan alanları: `predictors`, `tested`, `effect_type`, `r2_covariates` (f2'de `NA_real_`), `effect_test`, `method = "f_reg_partial_r2"`.
- `mde`: `engine_mde_reg(n, k, alpha, power, tested)` kısmi R² döner; kullanıcı birimine çevirir (`r2_change`: `kısmi × (1 - r2_covariates)`; `f2`: `kısmi / (1 - kısmi)`). Çıktı metni hangi ölçünün ve karşılığının (ΔR², f², kısmi R²) kullanıldığını yazar.
- `min_n = 3` (Dilim 9 ile aynı); küçük n'de `guard_pwrss` hatası `err_infeasible`.
- Metin: küme testi (H0: ΔR² = 0); sabit yordayıcı varsayımı ve rastgele yordayıcıda gücün biraz düşük olabileceği (Dilim 9'daki cümle; fark bu testte daha büyük olabilir); `tested = 1` ise "tek yordayıcı, iki yönlü t testi"; kovaryatların ölçüldüğü ve n'nin onlara dayandığı.

## Review Focus

- Kovaryat R² büyüdükçe (ΔR² sabit) gerekli n küçülür mü (f² büyür): .10/0 → 89.9, .10/.20 → 70.7. Elle kontrol.
- `r2_change` ile ve `f2` ile girilen eşdeğer plan aynı n'yi verir (ΔR² .10, kovaryat .20 ↔ f² .10/.70).
- `tested`, `predictors`, `r2_covariates` her hatalı girişte (0, 1.5, NA, `tested >= predictors`, `r2_covariates + effect > .99`) okunur hata verir; `tested = 1.5` ham `pwrss` kabulüne sızmaz.
- `reg_overall` planlarına `tested` ya da `r2_covariates` verilirse hata; `reg_partial`'a `k`, `p1`, `rows`, `alternative` verilirse hata.
- `f2` planında `r2_covariates = NA` çıktıya "NA" olarak sızmaz (`plan_tested_f2`).
- Metinde ΔR², f² ve kısmi R² karıştırılmaz; kaynak parantezi iç içe/art arda değil.
- Elle bozulmuş plan (`tested` silinmiş, `tested >= predictors`, `effect_test` ≠ dönüşüm) her fonksiyonda `err_plan`.
- Altın test değişmez.

---

### Task 1: `reg_partial`

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/plan.R`, `inst/i18n/messages.csv`, `tests/testthat/test-anova.R` (uyarı taraması), Dilim 9'un `test-reg.R` (engine imza testi; aşağıya bak)
- Create: `tests/testthat/test-reg-partial.R`

**Interfaces:**
- `plan_study()` imzasına `tested = NULL`, `r2_covariates = NULL` eklenir; `given`/`args`'a girer; `effect_type` imza varsayılanı `c("f", "eta2")` **değişmez** (Dilim 9 kararı: genişletmek `check_choice(c("f","eta2","f2","r2","r2_change"), c("f","eta2"), ...)` hatası verir ve `effect_type` verilmeyen her ANOVA çağrısını kırar). `reg_partial` dalı `effect_type`'ı `missing()` ile zorunlu kılar, `length(effect_type) != 1` ise `err_effect_type_reg_partial` verir (çünkü `check_choice`'taki `identical(x, choices)` kısayolu `c("r2_change","f2")`'yi sessizce `"r2_change"` yapar), sonra `check_choice(effect_type, c("r2_change", "f2"), "effect_type", exact = TRUE)` çağırır. ANOVA ve `reg_overall` kendi `check_choice` kümelerini korur, `r2_change`'i reddeder (testle kanıtla; `effect_type` verilmeyen ANOVA çağrısı eskisi gibi `f` kullanır). `predictors` artık `reg_overall` ve `reg_partial` ile geçerlidir: Dilim 9'un `err_predictors_unused` ve `err_effect_type_unused` metinleri bu dilimde güncellenir (CSV tablosuna bak). `tested`/`r2_covariates` reddi (`err_partial_unused`) `reg_partial` dışındaki **her** testin `prepare`'ine girer (`t_independent`, `t_paired`, `anova_oneway`, `prop_two`, `cor_pearson`, `chisq_indep`, `reg_overall`: 7 ret satırı, her biri `reject_partial_args(a)` çağrısı); `reject_*` kalıbıyla tek yardımcı. `reg_partial` kendi `prepare`'inde yalnız `rows`, `cols`, `k`, `p1`, `p2`, `r` reddini çağırır.
- `engine_n_reg(r2, k, alpha, power, tested = k)` ve `engine_mde_reg(n, k, alpha, power, tested = k)`: `tested` varsayılanı `k`, böylece Dilim 9 çağrıları değişmez. `tested`'i `pwrss`'e `k.tested = tested` verir. Hata anahtarı: `guard_pwrss(..., "err_infeasible_plan_reg_partial")`.
- `test_spec$reg_partial` (Dilim 9'daki `reg_overall` satırının kardeşi; ortak yardımcılar çıkarılırsa `variant_reg` gibi tek küçük işlev).

**CSV (metinler aynen; yeni anahtarlar)**

| key | en | tr |
|---|---|---|
| m_intro_reg_partial | `m_intro_prop_two` / `m_intro_cor_pearson` ile aynı kalıp (", a %1$s."), çünkü `m_intro`'nun "(%1$s)" biçimi parantezli test adıyla çift parantez üretir | `m_intro` TR metniyle aynı |
| val_reg_partial | multiple regression (partial R-squared / R-squared change F test) | çoklu regresyon (kısmi R² / ΔR² F testi) |
| err_effect_type_reg_partial | For test = "reg_partial", 'effect_type' is required and must be "r2_change" or "f2". | test = "reg_partial" için 'effect_type' zorunlu ve "r2_change" ya da "f2" olmalı. |
| err_tested | Argument 'tested' must be a whole number from 1 to 'predictors' - 1; to test all predictors together use test = "reg_overall". | 'tested' argümanı 1 ile 'predictors' - 1 arasında tam sayı olmalı; tüm yordayıcıları birlikte test etmek için test = "reg_overall" kullanın. |
| err_r2cov | For effect_type = "r2_change", 'r2_covariates' is required: the R-squared of the model without the tested predictors, from 0 up to but not including 1, with 'effect' + 'r2_covariates' at most 0.99. | effect_type = "r2_change" için 'r2_covariates' zorunlu: test edilen yordayıcılar çıkarılmış modelin R² değeri; 0 (dahil) ile 1 (hariç) arasında ve 'effect' + 'r2_covariates' en fazla 0,99 olmalı. |
| err_r2cov_unused | 'r2_covariates' is used only with effect_type = "r2_change" (Cohen's f-squared already accounts for the covariates). | 'r2_covariates' yalnız effect_type = "r2_change" ile kullanılır (Cohen f² kovaryatları zaten içerir). |
| err_predictors_unused (değişir) | Argument 'predictors' is used only with test = "reg_overall" or "reg_partial". | 'predictors' argümanı yalnız test = "reg_overall" ya da "reg_partial" ile kullanılır. |
| err_effect_type_unused (değişir) | Argument 'effect_type' is used only with test = "anova_oneway", "reg_overall" or "reg_partial". | Argüman 'effect_type' yalnız test = "anova_oneway", "reg_overall" ya da "reg_partial" ile kullanılır. |
| err_partial_unused | Arguments 'tested' and 'r2_covariates' are used only with test = "reg_partial". | 'tested' ve 'r2_covariates' argümanları yalnız test = "reg_partial" ile kullanılır. |
| err_infeasible_plan_reg_partial | pwrss cannot solve this design. Check effect, predictors, tested, r2_covariates, alpha and power. | pwrss bu tasarımı çözemiyor. effect, predictors, tested, r2_covariates, alpha ve power değerlerini kontrol edin. |
| plan_effect_reg_partial | Expected R-squared change (tested predictors): %s | Beklenen R² değişimi (test edilen yordayıcılar): %s |
| plan_effect_reg_partial_f2 | Expected effect size (Cohen's f-squared of the tested predictors): %s | Beklenen etki büyüklüğü (test edilen yordayıcıların Cohen f²'si): %s |
| plan_tested | Tested predictors: %s of %s; R-squared without them: %s | Test edilen yordayıcı: %s / %s; bunlar olmadan R²: %s |
| plan_tested_f2 | Tested predictors: %s of %s | Test edilen yordayıcı: %s / %s |
| plan_partial | Equivalent partial R-squared / f-squared: %s / %s | Karşılık gelen kısmi R² / f²: %s / %s |
| sens_title_reg_partial, sens_title_reg_partial_f2, col_*_reg_partial, plan_n_group_reg_partial | Dilim 9'daki `reg_overall` anahtarlarıyla aynı kalıp | aynı |
| m_effect_reg_partial | The effect size used for planning was an R-squared change of %s%s when adding %s of %s predictors to a model whose other predictors explain R-squared = %s. | Planlamada, diğer yordayıcıların R² = %5$s açıkladığı bir modele %3$s / %4$s yordayıcı eklendiğinde R² değişimi %1$s olarak alınmıştır%2$s. |
| m_effect_reg_partial_f2 | The effect size used for planning was Cohen's f-squared = %s%s (partial R-squared = %s) for %s of %s predictors. | Planlamada, %4$s / %5$s yordayıcı için etki büyüklüğü Cohen f² = %1$s%2$s (kısmi R² = %3$s) olarak alınmıştır. |
| m_result_reg_partial | For the F test of the contribution of the tested predictors (H0: R-squared change = 0) with alpha = %s and power = %s, the required sample size was %s participants in total. Predictors were treated as fixed; with random predictors the power is somewhat lower. | Alfa = %s ve güç = %s için test edilen yordayıcıların katkısına ilişkin F testinde (H0: R² değişimi = 0) gerekli örneklem büyüklüğü toplam %s katılımcıdır. Yordayıcılar sabit varsayılmıştır; rastgele yordayıcılarda güç biraz daha düşüktür. |
| m_adjust_*_reg_partial | Dilim 8'deki üç anahtarla aynı kalıp | aynı |

Anahtar argüman sırası (`%5$s` gibi) tutarsız kalmasın diye her çok-argümanlı İngilizce anahtar da numaralı yazılır. Kaynak parantezi `%2$s` testle kontrol edilir (art arda parantez yok).

- [ ] **Step 1: Başarısız testleri yaz (`test-reg-partial.R`)**

Referans n (aynı yöntem): sabit-tasarım simülasyonu ve dönüştürülmüş `pwr`. Tamsayı ölçütü: plan n'de güç ≥ hedef, n - 1'de < hedef.

```r
# power at integer n for the SAME method: pwr's noncentral F with f2 rescaled so lambda = f2 * n.
pwr_same <- function(n, k, u, f2, alpha = 0.05) {
  pwr::pwr.f2.test(u = u, v = n - k - 1, f2 = f2 * n / (n - k + u), sig.level = alpha)$power
}
cases <- list(  # dR2, r2cov, k, tested, expected plan n
  c(0.06, 0.20, 4, 1, 99), c(0.10, 0.20, 5, 2, 71), c(0.13, 0, 3, 1, 55),
  c(0.05, 0.10, 10, 1, 136), c(0.26, 0, 6, 3, 36), c(0.02, 0.30, 8, 2, 331))

test_that("partial n matches the same-method pwr power at the integer boundary", {
  for (cs in cases) {
    f2 <- cs[1] / (1 - cs[1] - cs[2]); k <- cs[3]; u <- cs[4]
    n <- ceiling(engine_n_reg(cs[1] / (1 - cs[2]), k, 0.05, 0.8, tested = u))
    expect_identical(n, cs[5])
    expect_gte(pwr_same(n, k, u, f2), 0.8)
    expect_lt(pwr_same(n - 1, k, u, f2), 0.8)
  }
})

test_that("plain pwr is a different method: larger by less than k - tested", {
  # method note: pwr.f2.test uses lambda = f2 * (u + v + 1), pwrss uses f2 * n.
  for (cs in cases) {
    f2 <- cs[1] / (1 - cs[1] - cs[2])
    ref <- pwr::pwr.f2.test(u = cs[4], f2 = f2, power = 0.8)$v + cs[3] + 1
    d <- ref - engine_n_reg(cs[1] / (1 - cs[2]), cs[3], 0.05, 0.8, tested = cs[4])
    expect_gt(d, 0); expect_lt(d, cs[3] - cs[4])
  }
})

test_that("tested = k is the overall test; tested = 1 is the two-sided t test", {
  expect_equal(engine_n_reg(0.13, 3, 0.05, 0.8, tested = 3), engine_n_reg(0.13, 3, 0.05, 0.8))
  tt <- pwrss::power.t.reg(beta = sqrt(0.06), k.total = 4, r.squared = 0.26, power = 0.8,
                           ceil.n = FALSE, verbose = 0)$n
  expect_equal(engine_n_reg(0.06 / 0.8, 4, 0.05, 0.8, tested = 1), tt, tolerance = 1e-6)
})
```

Plan, `effect_type` eşdeğerliği, hata girdileri:

```r
test_that("reg_partial plan", {
  q <- function(...) quiet_plan(test = "reg_partial", ...)
  p <- q(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20, predictors = 5, tested = 2)
  expect_identical(c(p$n_per_group, p$n_total, p$groups), c(71L, 71L, 1L))
  expect_equal(p$effect_test, 0.125)
  pf <- q(effect = 0.10 / 0.70, effect_type = "f2", predictors = 5, tested = 2)
  expect_identical(pf$n_total, 71L)
  expect_identical(q(effect = 0.15, effect_type = "f2", predictors = 5, tested = 2)$n_total, 68L)
  expect_identical(q(effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20,
                     predictors = 5, tested = 2, dropout = 0.1)$n_total, 79L)  # 70.667 / .9 = 78.5 -> 79
})
test_that("reg_partial arguments are validated", {
  ok <- list(test = "reg_partial", effect = 0.1, effect_type = "r2_change", r2_covariates = 0.2,
             predictors = 5, tested = 2)
  chk <- function(over, pat) expect_error(do.call(plan_study, utils::modifyList(ok, over)), pat, fixed = TRUE)
  for (b in list(0, 1, -0.1, NA_real_, "a")) chk(list(effect = b), "'effect'")
  for (b in list(NULL, 0, 1, 1.5, NA_real_, 5, 6)) chk(list(tested = b), "'tested'")
  for (b in list(1, -0.1, NA_real_, 0.95)) chk(list(r2_covariates = b), "'r2_covariates'")
  chk(list(r2_covariates = NULL), "'r2_covariates'")
  chk(list(effect_type = "f2"), "'r2_covariates'")                 # f2 + r2_covariates
  chk(list(effect_type = "r2"), "'effect_type'"); chk(list(effect_type = NULL), "'effect_type'")
  chk(list(effect_type = c("r2_change", "f2")), "'effect_type'")      # length 2 must not pass via identical(x, choices)
  chk(list(alternative = "one.sided"), "alternative")
  expect_error(plan_study(test = "reg_overall", effect = 0.1, effect_type = "r2", predictors = 3,
                          tested = 1), "'tested'", fixed = TRUE)
  expect_error(plan_study(test = "anova_oneway", effect = 0.25, k = 3, effect_type = "r2_change"),
               "'effect_type'", fixed = TRUE)
})
```

Duyarlılık (geri hesap, düz bölge kontrolü):

```r
test_that("reg_partial sensitivity", {
  p <- quiet_plan(test = "reg_partial", effect = 0.10, effect_type = "r2_change",
                  r2_covariates = 0.20, predictors = 5, tested = 2)
  s <- sensitivity(p, n = 100, power = 0.8)
  expect_equal(s$mde, 0.09048 * 0.8, tolerance = 1e-3)
  expect_equal(pwrss::power.f.reg(r.squared.change = s$mde / 0.8, k.total = 5, k.tested = 2,
                                  n = 100, verbose = 0)$power, 0.8, tolerance = 1e-3)
  pf <- quiet_plan(test = "reg_partial", effect = 0.15, effect_type = "f2", predictors = 5, tested = 2)
  expect_equal(sensitivity(pf, n = 100, power = 0.8)$mde, 0.09048 / (1 - 0.09048), tolerance = 1e-3)
})
```

Metin ve çıktı testleri `test-reg.R`'deki kalıpla (EN tam cümle, TR `\u` kaçışlı ASCII, `))` ve `) (` yok, `Alternative hypothesis` satırı yok, `Tested predictors: 2 of 5; R-squared without them: 0.2` satırı var; `effect_type = "f2"` planında `r2_covariates` `NA` olduğundan `plan_tested_f2` kullanılır ve çıktıda "R-squared without" ile "NA" **geçmez**: `expect_false(grepl("NA", out))`, `expect_false(grepl("R-squared without", out))`). Elle bozulmuş plan testi `tested = NULL`, `tested = 5L`, `effect_test = 0.5` için `print`, `sensitivity`, `write_methods` `err_plan`. Simülasyon testi bu dilimde yazılmaz (Dilim 11b: `simulate_power` `reg_partial`'ı kapsar); simülasyon kıyas tablosu yukarıda "Neden" bölümünde belgelendi ve denendi.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'reg')"`
Expected: FAIL (`engine_n_reg` `tested` argümanını bilmiyor, `reg_partial` yok).

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

`@param tested`, `@param r2_covariates`, `effect_type` belgesi (üç ölçü: ΔR², küme f², kısmi R²; naif ΔR² tuzağı), `@details`: pwrss ile pwr farkı ve yöntem notu (λ = f² n, G*Power ile aynı; pwr düz hâli daha büyük n verir).

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0` (altın dahil), `Status: OK`. `devtools::document()` sonrası `man/` güncel.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi (kullanıcıya: ΔR² .10'u kovaryat .20 ile ve .00 ile girip n'nin neden değiştiğini açıklatmak), `docs/devlog.md` girdisi. Kullanıcı isterse commit (`feat: plan partial R-squared F test`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/tests.R` (`reg_partial` satırı, `prepare`, `check`, metin işlevleri, `reject_partial_args`) | ~55 |
| `R/engine.R` (`tested` argümanı, hata anahtarı) | ~6 |
| `R/plan.R` (`tested`, `r2_covariates`, `given`/`args`, roxygen) | ~18 |
| `R/tests.R` diğer yedi testin `prepare`'ine `reject_partial_args(a)` ret satırı (7) + `err_predictors_unused`/`err_effect_type_unused` metin güncellemesi (~3) | ~10 |
| **Kod toplamı** | **~90** |
| `inst/i18n/messages.csv` | ~24 satır (kod sayılmaz) |
| `tests/testthat/test-reg-partial.R` | ~110 (kod sayılmaz) |

150 satırın altında; **bölme gerekmez**.

## Dilim 9 planıyla çelişkiler (Dilim 9 dosyası değiştirilmedi)

1. Dilim 9 "sabit yordayıcı: simülasyonda .782, fark .018, sınırın altı" diyor. Rastgele yordayıcılarda fark büyük n'de .01 civarı, ama R² .30, k 3, n 30'da .043 (analitik .806, simülasyon .762; 4.000 tekrar). Dilim 9'un gerekçesi tek durumdan genelleme; metindeki "biraz düşüktür" doğru, ama sim testi için ".02 sınırı yeterli" varsayımı küçük n ve büyük R²'de tutmuyor (Dilim 11b ve 13b'de ele alınır).
2. Dilim 9'un `engine_n_reg(r2, k, alpha, power)` imzası bu dilimde `tested = k` ile genişler; `reg_overall` çağrıları değişmez ama Dilim 9'un engine testlerinin imza varsayımı korunmalı (uyarı: uygulayıcı Dilim 9 testlerini silmez).
3. Dilim 9 `plan_study()` imzasındaki `effect_type = c("f", "eta2")` varsayılanını korur; bu dilim de korur (`"r2_change"` yalnız `reg_partial` dalının kümesindedir). Dilim 9'un `missing()` + `length == 1` + `check_choice(..., exact = TRUE)` kalıbı aynen kullanılır; her test yalnız kendi kümesini kabul eder.
4. Dilim 9 `plan_study` altın dosyasına yeni test eklemeyi gerektirmiyordu; 9b de eklemez (yalnız eski çıktıların değişmediğini kanıtlar).

## Kullanıcı kararları (2026-11-14)

1. `effect_type = "r2_change"` (`r2_covariates` zorunlu) ya da `"f2"`; zorunlu, tam eşleşme, `length == 1`.
2. `tested = predictors` hata verir ve `test = "reg_overall"`'a yönlendirir.
3. `pwr` düz sonucu çıktıda gösterilmez; yalnız yardım sayfasında yöntem farkı notu.
4. `tested = 1` yalnız iki yönlü; `alternative` verilirse hata.
5. Rastgele yordayıcı: Dilim 9 ile aynı, yalnız not (Opus kararı; Dilim 9c kararı `reg_partial`'ı kapsamaz).
6. pwrss'in `r.squared.change` anlamı yardım sayfasında kaynak koda dayanarak not edilir; yazarlarla iletişim yok (Opus kararı).

## Açık sorular (yanıtlandı)

1. **Argüman adları ve ölçü:** `effect_type = "r2_change"` ile `r2_covariates` zorunlu (öneri), mi; yoksa yalnız `"f2"` mi (daha az karışıklık, ama araştırmacıların elindeki sayı çoğunlukla ΔR²)? `r2_covariates` adı uygun mu (alternatif: `r2_reduced`)?
2. **`tested = predictors`:** hata mı (öneri, `reg_overall` yönlendirmesi) yoksa sessizce genel teste mi çevrilsin?
3. **Yöntem notu:** `pwr` düz hâli 1-9 kişi daha fazla verir (k - tested'a kadar). Paket `pwrss`/G*Power yöntemini ve metinde adını kullanır (sabit-tasarım simülasyonu bunu doğruluyor). Cohen/`pwr` muhafazakâr sonucunu da ek olarak yazdırmak ister misin (öneri: hayır, yalnız belge)?
4. **Tek yönlü tek yordayıcı t testi:** `tested = 1` yalnız iki yönlü (öneri). Tek yönlü için `power.t.reg` motoru ve `alternative` desteği eklemek ister misin? Ayrı küçük dilim olur (~40 satır), çünkü işareti ve `beta` dönüşümü yeni.
5. **Rastgele yordayıcı payı:** simülasyon farkı küçük n ve büyük R²'de .04'e çıkıyor. Yine yalnız not (öneri) mi, yoksa n için rastgele-yordayıcı düzeltmesi/uyarısı (ör. n < 50 ve R² > .25'te uyarı) eklensin mi? Kullanıcı kararı gerekir (Dilim 9 kararı 4 ile çelişebilir).
6. `pwrss`'in `r.squared.change` adının kısmi R² anlamına geldiğini kaynak koddan çıkardım; pwrss yazarlarının belgesi (`power.f.regression` örneği) bunu söylemiyor. Sonuç sabit-tasarım simülasyonuyla doğrulandı, ama yazarlara not düşmek ya da yayında kaynak göstermek ister misin?
