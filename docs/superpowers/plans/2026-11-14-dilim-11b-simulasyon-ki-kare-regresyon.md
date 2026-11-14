# Dilim 11b: simülasyon, ki-kare ve regresyon testleri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşul:** Dilim 11a (`simulate_power`, `test_spec$*$power/simulate` alanları, `engine_power_*`), Dilim 8 (`chisq_indep`), **Dilim 9** (`reg_overall`) ve **Dilim 9b** (`reg_partial`) `main`'de olmalı. Dilim 9/9b kodlanmadan bu plan uygulanamaz.

**Goal:** `simulate_power()` üç testi daha kapsar: `chisq_indep`, `reg_overall`, `reg_partial`. Regresyonda yordayıcıların nasıl üretildiği gücü değiştirdiği için bu dilim iki mod tanımlar: `predictors = "fixed"` (pwrss/G*Power'ın yöntemi; **aynı yöntem**, `pass` ölçütü bununla verilir) ve `predictors = "random"` (kullanıcı durumu; yalnız bilgi, fark raporlanır).

**Architecture:** 11a ile aynı: `test_spec`'e üç satırda `power` ve `simulate` alanları; `engine_power_chisq`, `engine_power_reg`. `simulate_power()` imzasına yalnız `predictors = c("fixed", "random")` eklenir (yalnız regresyon testlerinde anlamlı; öteki testlerde verilirse hata `err_sim_predictors`).

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Referanslar: `pwr::pwr.chisq.test` (aynı yöntem), `pwr::pwr.f2.test` (genel test aynı yöntem; kısmi testte dönüştürülmüş biçim, bkz. Dilim 9b), simülasyon.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§6, §8 madde 11)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok.
- Hesap `pwrss`'ten gelir. Tolerans: ampirik güç analitik güçten ≤ .02; aşılırsa dur, toleransı genişletme (Dilim 9 ve 11a kuralları). Farklı yöntem farkı başarısızlık değildir, yöntem notuna yazılır.
- Tohum yönetimi ve `skip_on_cran()` 11a ile aynı.
- Mevcut testlerin çıktıları değişmez.
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-11b-simulate-chisq-reg`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (R'da denendi)

**Ki-kare (10.000 tekrar, tohum 1, `chisq.test(correct = FALSE)`):** w, bilinen kenar sınırlarla tek-parametreli tablo kurulur: satır ve sütun marjinalleri eşit (1/rows, 1/cols). Sabit örüntü (ASCII, tek tanım):

```r
make_table <- function(rows, cols, w) {
  a <- seq_len(rows) - (rows + 1) / 2          # centered row scores
  b <- seq_len(cols) - (cols + 1) / 2          # centered column scores
  M <- outer(a, b); M <- M / sqrt(sum(M^2))    # zero row/column sums, Frobenius norm 1
  1 / (rows * cols) + w / sqrt(rows * cols) * M
}
```

`M`'nin satır ve sütun toplamları 0'dır, bu yüzden marjinaller eşit kalır; hücre olasılıkları toplamı 1. R'da doğrulandı (3x3, 2x2, 5x5; w .3): `all.equal(rowSums(P), rep(1/rows, rows))` TRUE ve `sqrt(sum((P - E)^2 / E))` = 0.3 (E = marjinallerin çarpımı). Sonuçlar (`rmultinom` ile n'lik örneklem, 10.000 tekrar):

| Durum | n | ampirik | analitik (pwrss) | pwr |
|---|---|---|---|---|
| w .30, 3x3 (df 4) | 133 | .8137 | .8013 | .8013 |
| w .30, 2x2 (df 1) | 88 | .8088 | .8035 | .8035 |
| w .30, 5x5 (df 16) | 215 | .8127 | .8022 | - |

(Hepsinde fark ≤ .012, sınırın altı; 2x2'de `correct = FALSE` şart, Dilim 8 belgesi. Tek tohumlu koşular; test `reps = 10000, seed = 1` ile bunları yeniden üretir, sayılar tohuma göre ±.005 oynar.)

**`w_max(rows, cols)`** (11b'de tanımlanan, dışa aktarılmayan yardımcı; `R/simulate.R`): bu örüntüyle tüm hücre olasılıklarının pozitif kalabildiği üst sınır. `M` yukarıdaki gibi normalize edilmişse `w_max = 1 / (sqrt(rows * cols) * max(abs(M)))` (en küçük hücre `w = w_max`'ta 0'a iner; geçerli aralık `w < w_max`). Değerler: 2x2 → 1.0; 2x3 → .8165; 3x3 → .6667; 3x4 → .6086; 5x5 → **.5** (R'da hesaplandı). 13b ızgarası `plansize:::w_max` ile çağırır. `w = .5`, 5x5'te en küçük hücre ≈ 0 (`-7e-18`) olur ve `rmultinom` hata verirdi; üretici `min(P) > 0` kontrol eder, aksi hâlde `err_sim_table` ("bu w bu örüntüyle bu tabloda eşit marjinallerle kurulamıyor"). **Dikkat:** bu bir örüntü sınırıdır, tablonun varoluş sınırı değildir: başka örüntüyle 5x5, w .5 kurulabilir (ör. `v <- c(4, -1, -1, -1, -1); M <- outer(v, v)` normalize edilince en küçük hücre .02, w .5 doğrulandı). Hata metni bu yüzden "bu örüntüyle" der; başka örüntüye geçme kararı açık soru 3'tedir.

**Regresyon (`reg_overall`, yordayıcılar rastgele normal, 4.000 tekrar):**

| R² | k | n | analitik | rastgele-X simülasyon | fark |
|---|---|---|---|---|---|
| .13 | 1 | 55 | .804 | .793 | .011 |
| .13 | 3 | 77 | .800 | .788 | .012 |
| .13 | 5 | 92 | .802 | .788 | .014 |
| .13 | 10 | 119 | .804 | .796 | .008 |
| **.30** | **3** | **30** | **.806** | **.762** | **.043** |
| .05 | 3 | 212 | .802 | .809 | -.007 |
| .05 | 10 | 318 | .800 | .787 | .014 |
| .02 | 5 | 635 | .801 | .798 | .002 |

Rastgele yordayıcılarda fark küçük n ve büyük R²'de .02'yi aşıyor. Sabit tasarımda (dik, ölçeği n olan X; 40.000 tekrar) `reg_partial` için ampirik/analitik: .8058/.8030, .8028/.8021, .7471/.7497, .8576/.8553 (hepsi ≤ .005).

Sabit tasarım kurulumu (aynı yöntem): `X` = `qr.Q(qr(scale(rnorm matrisi))) * sqrt(n)` (sütunlar dik, ortalaması 0, `sum(x^2) = n`), `y = X beta + e`, F istatistiği QR artıklarından. `reg_partial` için gerçek ΔR² ve kovaryat R² sırasıyla test edilen ve kovaryat sütunlarına dağıtılır; Dilim 9b'nin kısmi R² dönüşümü simülasyonda kullanılmaz (veriyi gerçek ΔR²/kovaryat R²'den kurar), böylece dönüşüm bağımsız sınanır.

## Kararlar (öneri)

- `reg_overall` ve `reg_partial` için `simulate_power(plan, predictors = "fixed")` varsayılan; `pass` fixed moduna göre (≤ .02 ve hedeften ≥ -.02). `"random"` modunda `pass` hesaplanmaz (`NA`), `diff` ve çıktı satırı "rastgele yordayıcı farkı" yazar. Gerekçe: pwrss'in modeli sabit yordayıcıdır; kullanıcının gerçek durumu rastgeledir ve fark yöntem farkıdır, başarısızlık değildir (çelişki kuralı). Toleransı genişletmiyorum; "random" yalnız bilgidir.
- Rastgele yordayıcı farkı eşiği (ör. n < 50 ve R² > .25'te uyarı) bu dilimde **eklenmez** (kullanıcı kararı, açık soru 2 ve Dilim 9b açık soru 5).
- `chisq_indep`: yukarıdaki `make_table()` üreticisi ve `w_max()` kontrolü; `rows`/`cols` plandan.
- `reg_partial` `simulate`: `tested` yordayıcıya `effect`'ten türetilen ΔR² paylaştırılır: `r2_change` girdisinde ΔR² doğrudan ve kovaryat R² `r2_covariates`; `f2` girdisinde güç yalnız f2'ye bağlı olduğundan kovaryat R² = 0 ve ΔR² = f2 / (1 + f2) alınır. `simulate` bunları `effect_type`, `effect` ve `r2_covariates` alanlarından türetir; 9b'ye ek alan gerekmez. Kovaryat R² kovaryat sütunlarına eşit paylaştırılır.
- Süre: 10.000 tekrar `lm`/QR ile ~4 s (denendi: `reg_overall` 3,9 s), ki-kare ~0,3 s.

## Review Focus

- `pass` ve `diff` alanı modlara göre doğru (`random` → `pass` = `NA`); 11a testleri değişmez.
- `err_sim_table` (w = .5, 5x5; bu örüntüde `w >= w_max` = .5) ham `rmultinom` hatası yerine okunur mesaj; `w_max` değerleri (1, .8165, .6667, .6086, .5) testte sabitlenir.
- `reg_partial` simülasyonu, 9b'nin kısmi R² dönüşümünden **bağımsız** kurulur (aksi hâlde dönüşüm yanlışsa test de yanlış geçer; Dilim 2 dersi).
- `predictors = "random"` ve `n` küçük/büyük R²'de fark raporlanır, `pass` yok.
- Hata: `predictors` verilen ama regresyon olmayan testte `err_sim_predictors`.

---

### Task 1: üç test için `simulate` ve `power`

**Files:**
- Modify: `R/tests.R`, `R/engine.R`, `R/simulate.R` (`predictors` argümanı), `inst/i18n/messages.csv`
- Create: `tests/testthat/test-simulate-more.R`

**Interfaces:**
- `engine_power_chisq(n, w, df, alpha)` (`pwrss::power.chisq.gof(w, df, n)$power`), `engine_power_reg(n, r2_partial, k, tested, alpha)` (`pwrss::power.f.reg(...)$power`).
- `test_spec$chisq_indep|reg_overall|reg_partial$power(n, plan)` ve `$simulate(n, plan, predictors)`.
- `simulate_power(plan, n = NULL, reps = 10000, seed = NULL, predictors = c("fixed", "random"))`.

**CSV:** `err_sim_table`, `err_sim_predictors`, `sim_note_random` (rastgele yordayıcıda fark yöntem farkıdır, açıklama), `sim_title_random`.

- [ ] **Step 1: Başarısız testleri yaz (`test-simulate-more.R`)**

```r
test_that("analytic power matches independent references", {
  p <- quiet_plan(test = "chisq_indep", effect = 0.3, rows = 3, cols = 3)
  expect_equal(test_spec$chisq_indep$power(133, p), pwr::pwr.chisq.test(w = 0.3, N = 133, df = 4)$power, tolerance = 1e-3)
  r <- quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3)
  expect_equal(test_spec$reg_overall$power(77, r), pwr::pwr.f2.test(u = 3, v = 77 - 3 - 1, f2 = 0.13 / 0.87)$power, tolerance = 1e-3)
  q <- quiet_plan(test = "reg_partial", effect = 0.10, effect_type = "r2_change", r2_covariates = 0.20,
                  predictors = 5, tested = 2)
  f2 <- 0.10 / 0.70                                   # same method: pwr rescaled so lambda = f2 * n (Dilim 9b)
  expect_equal(test_spec$reg_partial$power(71, q),
               pwr::pwr.f2.test(u = 2, v = 71 - 6, f2 = f2 * 71 / (71 - 5 + 2))$power, tolerance = 1e-3)
})
test_that("simulation agrees with analytic power", {
  skip_on_cran()
  for (p in list(quiet_plan(test = "chisq_indep", effect = 0.3, rows = 3, cols = 3),
                 quiet_plan(test = "chisq_indep", effect = 0.3, rows = 2, cols = 2),
                 quiet_plan(test = "reg_overall", effect = 0.13, effect_type = "r2", predictors = 3),
                 quiet_plan(test = "reg_partial", effect = 0.10, effect_type = "r2_change",
                            r2_covariates = 0.20, predictors = 5, tested = 2))) {
    s <- simulate_power(p, reps = 10000, seed = 1)               # fixed predictors (same method)
    expect_lte(abs(s$power_sim - s$power_analytic), 0.02); expect_true(s$pass)
  }
})
test_that("random predictors are reported, not judged", {
  skip_on_cran()
  p <- quiet_plan(test = "reg_overall", effect = 0.30, effect_type = "r2", predictors = 3)
  s <- simulate_power(p, reps = 10000, seed = 1, predictors = "random")
  expect_true(is.na(s$pass)); expect_gt(s$power_analytic - s$power_sim, 0.02)  # known gap at small n, large R2 (.043 in 4000 reps)
})
```

`err_sim_table` testi: `chisq_indep` w .5, 5x5 plan → `simulate_power` okunur hata. `predictors = "random"` `t_independent`'te `err_sim_predictors`. Fixed-X üretici kendi başına: kurulan `X`'in sütunları dik ve `sum(x^2) = n` (testte doğrudan işlev çağrısı).

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'simulate')"`
Expected: FAIL.

- [ ] **Step 3: Kodu ve CSV'yi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız inceleme, genel inceleme, kullanıcıya fixed/random farkını anlama sorusu, `docs/devlog.md`. Commit yalnız istenirse (`feat: simulate chi-square and regression plans`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/tests.R` (3 test × `power`, `simulate`; `make_table`, `w_max`, fixed-X üretici) | ~45 |
| `R/engine.R` (`engine_power_chisq`, `engine_power_reg`) | ~10 |
| `R/simulate.R` (`predictors` argümanı, mod ayrımı) | ~10 |
| **Kod toplamı** | **~65** |
| `tests/testthat/test-simulate-more.R` | ~55 (kod sayılmaz) |

Tek dal, bölme gerekmez.

## Önceki planlarla çelişkiler

- **Dilim 9:** "simülasyon (n = 77, R² .13) ampirik .782 / analitik .800, fark .018, sınır .02 altında" tek durumdur; 4.000 tekrarla R² .13, k 3, n 77 için .788 çıktı (fark .012), ama R² .30, k 3, n 30'da fark .043. Yani Dilim 9'un "rastgele yordayıcıyla da sınırın altındayız" genellemesi her durumda tutmuyor. Bu plan fixed/random ayrımını getirir.
- **Dilim 9b:** `reg_partial` simülasyonu mevcut plan alanlarından (`effect_type`, `effect`, `r2_covariates`) gerçek ΔR² ve kovaryat R²'yi türetir; 9b'ye ek alan gerekmez.
- **Spec §6:** "Yuvarlanmış n ile veri üretilir, planlanan test çalıştırılır": regresyonda "planlanan test" F testidir ve veri üretimi (sabit/rastgele) spec'te belirtilmemiş; ek karar yukarıda.

## Açık sorular

1. **Varsayılan mod:** `predictors = "fixed"` varsayılan olsun mu (öneri, `pass` anlamlı olur), yoksa kullanıcının gerçek durumu olan `"random"` mı (`pass` anlamsız kalır)?
2. **Rastgele yordayıcı eşiği:** Küçük n ve büyük R²'de fark > .02. Plan uyarısı ister misin (örn. R² > .25 ve n < 50), ya da n'ye pay? Dilim 9 kararı 4 (yalnız not) ile çelişir, onu yeniden açar.
3. **Ki-kare tablo örüntüsü:** Eşit marjinaller ve tek örüntülü `M` kullanıyorum; gerçek tablolar farklıdır ama Cohen w yalnız ncp'yi belirler. Kullanıcıya "eşit marjinaller" notu yazılsın mı? Büyük w'de (w > en büyük uygun değer) hata mı veriyoruz (öneri), yoksa başka örüntüye mi düşelim?
4. **Küçük beklenen hücre sayısı:** 3x3, w .3, n 133'te fark .012 (sınır .02'nin altı). Daha büyük tablolar ve düşük w ile beklenen hücre sayısı < 5 olduğunda fark artabilir (Dilim 8 beklenen hücre uyarısı eklememişti). 13b ızgarasında ölçülür; bu dilimde yalnız sabit vakalar.
