# Dilim 11 (11a): simülasyonla doğrulama, çekirdek ve ilk beş test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşul:** Dilim 1-8 ve **Dilim 10** `main`'de (`err_precision_plan` testi `plan_precision` ve `check_plan` kolunu ister). 11b (ki-kare, `reg_overall`, `reg_partial`) ayrıca Dilim 9 ve 9b'ye bağlıdır; 11a onlara bağlı değildir.

**Goal:** `simulate_power(plan, n = NULL, reps = 10000, seed = NULL)` bir planı veri üreterek sınar: yuvarlanmış n ile veri üretir, planlanan testi `reps` kez çalıştırır, ampirik gücü (Monte Carlo güven aralığıyla) `pwrss`'in o n için analitik gücüyle karşılaştırır. Spec §6 kuralı: ampirik güç analitik güçten en çok 0,02 sapabilir ve hedef güçten en az 0,02 eksik kalmamalıdır. Bu dilim `t_independent`, `t_paired`, `anova_oneway`, `prop_two`, `cor_pearson` testlerini kapsar.

**Architecture:** `test_spec`'e iki yeni alan: `power(n, plan)` (analitik güç, `pwrss` ince sarmalayıcıları `engine_power_*`) ve `simulate(n, plan)` (bir `function()` döndürür; her çağrıda yeni veri üretip planlanan testin p değerini verir). `R/simulate.R` yalnız döngü, tohum yönetimi, özet ve `print` içerir; teste özgü dal yok. Hesap motoru yazılmaz: güç `pwrss`'ten, test `stats`'tan (`t.test`, `anova(lm)`, `prop.test`, `cor.test`).

**Tech Stack:** R 4.6.1, pwrss 1.3.3, testthat 3. Bağımsız referanslar (analitik gücün kendisi için): `stats::power.t.test`, `pwr::pwr.anova.test`, `pwr::pwr.r.test`; simülasyon ise zaten bağımsız kanıttır.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§4 madde 5 ve §5 "simülasyon ayrı özellik değil, doğrulama aracıdır"; §6; §8 madde 11)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok. Her anahtara tam kullandığı kadar argüman.
- Hesap `pwrss`'ten gelir. Simülasyon ayrı bir "güç motoru" değildir; yalnız doğrulayıcıdır.
- Küresel rastgele sayı üreticisi durumu kullanıcıdan çalınmaz: `seed` verilirse `.Random.seed` kaydedilir ve işlev çıkışında geri yüklenir (`withr` `Suggests`'te kalır, kod `base`).
- Uzun simülasyon testleri `testthat::skip_on_cran()` ile korunur.
- Mevcut testlerin çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-11a-simulate`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (R'da denendi, 10.000 tekrar, tohum 11)

Analitik güç `pwrss` ile, ampirik güç bu planın üreteceği veriyle (ilgili `stats` testi); n = plan n'si (kayıp/DEFF hariç):

| Test (ayar) | n | ampirik | analitik (pwrss) | bağımsız analitik |
|---|---|---|---|---|
| bağımsız t (d .5) | 64/grup | .8064 | .8015 | `power.t.test` .8015 |
| eşli t (d .5, r .5; dz .5) | 34 | .8049 | .8078 | `power.t.test(type="paired")` .8078 |
| ANOVA (f .25, k 3) | 53/grup | .8026 | .8049 | `pwr.anova.test` .8049 |
| iki oran (.45/.30, havuzlu z) | 163/grup | .7967 | .8016 | `power.prop.test` .8016 (aynı n'de aynı) |
| Pearson r (.3) | 85 | .8016 | .8003 | `pwr.r.test` .8044 (pwr düzeltmeli, bkz. Dilim 7) |

Hepsi ±.02 içinde. Süre: t testleri ~0,6 s; `anova(lm())` ile ANOVA 10.000 tekrarda ~8,6 s (en yavaşı).

Kenar durumlar (denendi): Pearson r = .8, n = 10: ampirik .869, analitik .828 (**fark .041 > .02**; Fisher z yaklaşımı küçük n'de muhafazakâr, bkz. Dilim 7 belgesi). Bağımsız t d = 1.5, n = 9: .850 / .848. İki oran tek yönlü .10/.05, n = 343: .815 / .801 (fark .014).

Tek yönlü testlerde ampirik güç `alternative = "greater"/"less"` ile işaretli veriden sınanmalıdır (etkinin işaretine göre).

## Kararlar (öneri; açık sorulara bak)

- Adlandırma: `simulate_power()` (kullanıcı için ne yaptığı belli). Dönüş: sınıf `plansize_simulation` listesi: `test`, `n` (kullanılan, planın birimiyle), `reps`, `power_sim`, `mc_se`, `ci` (Wilson olmadan `power_sim ± 1.96 * mc_se`), `power_analytic`, `diff`, `target`, `pass` (mantıksal), `notes`.
- `n = NULL` ise `ceiling(plan$n_analytic)` kullanılır (analitik n; **kayıp ve DEFF simüle edilmez**). Tek sayılık DEFF simülasyonla temsil edilemez; kayıp rastgele (MCAR) simüle edilebilir ama beklenen etkin n'e eşdeğerdir, anlamsız tekrar olur. Plan kayıp/DEFF içeriyorsa `notes` ve çıktı satırı bunu söyler (`sim_note_adjust`).
- `pass`: `abs(power_sim - power_analytic) <= 0.02` **ve** `power_sim >= plan$power - 0.02` (spec §6; analitik güçle karşılaştırılır, hedefle değil, çünkü yukarı yuvarlama gücü hedefin üstüne çıkarabilir). `mc_se` 10.000 tekrarda ≤ .005; `reps < 1000` hata (`err_reps`), `reps < 10000` için çıktı "spec önerisi altında" notu taşır; `pass` yine hesaplanır.
- Veri üretim kalıbı (tüm testler standart normal/Bernoulli, ek parametre yok):
  - `t_independent`: `x ~ N(0,1)`, `y ~ N(d,1)`; `t.test(y, x, var.equal = TRUE, alternative = )`.
  - `t_paired`: `d` = ortalama değişim / tek ölçümün SD'si, `r` ölçümler arası korelasyon: `x ~ N(0,1)`, `y = d + r x + sqrt(1 - r^2) e`; `t.test(y, x, paired = TRUE)`.
  - `anova_oneway`: Cohen f'yi veren eşit aralıklı ortalamalar `mu` (`sqrt(mean((mu - mean(mu))^2)) = f`, eşitlik: F testinin gücü yalnız f'ye bağlıdır, örüntüye değil); `anova(lm(y ~ g))`.
  - `prop_two`: `rbinom` iki grup, `prop.test(c(x1, x2), c(n, n), correct = FALSE, alternative = )` (havuzlu z testiyle aynı; Yates **yok**, Dilim 6 ile tutarlı). Yön: `p1 > p2` ise `"greater"`.
  - `cor_pearson`: `y = rho x + sqrt(1 - rho^2) e`; `cor.test`. Yön işarete göre.
- `engine_power_*` işlevleri `pwrss::power.t.student(n2 = )`, `power.f.ancova(n.total = )`, `power.z.twoprops(n2 = )`, `power.z.onecor(n = )` çağırır; hata sarmalama `guard_pwrss`.
- Korkuluk: `check_plan()` zaten kesinlik nesnesini reddeder (Dilim 10); `simulate_power` `check_plan` çağırır.
- Simülasyonun sınırı: bir **doğrulama** aracıdır (spec). Rastgele plan ızgarası ve yayın öncesi toplu sınama Dilim 13b'dir; bu dilimdeki testler testthat içinde sabit, birkaç plandır.

## Review Focus

- Aynı `seed` aynı sonucu verir; çağrıdan sonra `.Random.seed` değişmemiş (ya da hiç yoktu ve yine yok).
- Tek yönlü plan için işaretli veri: `alternative = "one.sided"`, negatif r ve `p1 < p2` ile de güç hedefte.
- `n` verilirse planın birimiyle (grup başına ya da toplam); bozuk n (0, 1.5, NA, `n_effective` altı) okunur hata.
- Kayıp/DEFF'li planda not çıkar, sonuç yine analitik n'ye göredir.
- `anova_oneway` süresi: 10.000 tekrar testte ~9 s; testte yalnız bir ANOVA vakası.
- `pass = FALSE` olduğunda çıktı "dur, kullanıcıya getir" der (kural: aşırı sapmada toleransı genişletme); r = .8, n = 10 gibi bilinen kenar için test beklenen `FALSE`'u belgeler (yöntem notu).
- Altın test değişmez.

---

### Task 1: `simulate_power` çekirdeği ve beş test

**Files:**
- Create: `R/simulate.R`, `tests/testthat/test-simulate.R`
- Modify: `R/tests.R` (`power`, `simulate` alanları, 5 test), `R/engine.R` (`engine_power_*`), `inst/i18n/messages.csv`, `NAMESPACE` (roxygen)

**Interfaces:**
- `engine_power_t(n, effect, alpha, alternative, design)`, `engine_power_anova(n, k, f, alpha)`, `engine_power_props(n, p1, p2, alpha, alternative)`, `engine_power_cor(n, rho, alpha, alternative)` → ondalıklı güç (0-1).
- `test_spec$<test>$power(n, plan)`, `test_spec$<test>$simulate(n, plan)` (plan alanları `effect_test`, `alpha`, `alternative`, `k`, `r`, `p1`, `p2` kullanır).
- `simulate_power(plan, n = NULL, reps = 10000, seed = NULL)`; `print.plansize_simulation`.

**CSV:** `sim_title`, `sim_n`, `sim_power`, `sim_analytic`, `sim_diff`, `sim_pass`, `sim_fail` (kural ve "kullanıcıya getir"), `sim_note_adjust`, `sim_note_reps`, `err_reps`, `err_sim_n`. (Tam metinler kodlamada; her anahtar en/tr, kalıp Dilim 8 ile aynı.)

- [ ] **Step 1: Başarısız testleri yaz (`test-simulate.R`)**

Analitik güç testi (hızlı, `skip_on_cran` gerekmez; bağımsız referanslarla):

```r
test_that("analytic power matches independent references", {
  p <- quiet_plan(effect = 0.5)
  expect_equal(test_spec$t_independent$power(64, p), stats::power.t.test(n = 64, delta = 0.5)$power, tolerance = 1e-3)
  pp <- quiet_plan(test = "t_paired", effect = 0.5, r = 0.5)
  expect_equal(test_spec$t_paired$power(34, pp), stats::power.t.test(n = 34, delta = 0.5, type = "paired")$power, tolerance = 1e-3)
  pa <- quiet_plan(test = "anova_oneway", effect = 0.25, k = 3)
  expect_equal(test_spec$anova_oneway$power(53, pa), pwr::pwr.anova.test(k = 3, n = 53, f = 0.25)$power, tolerance = 1e-3)
  pc <- quiet_plan(test = "cor_pearson", effect = 0.3)
  expect_equal(test_spec$cor_pearson$power(85, pc), pwr::pwr.r.test(n = 85, r = 0.3)$power, tolerance = 0.01)  # pwr: bias correction
})
```

Simülasyon (spec §6 kuralı; `skip_on_cran`):

```r
test_that("simulation agrees with analytic power", {
  skip_on_cran()
  cases <- list(
    quiet_plan(effect = 0.5), quiet_plan(effect = 0.5, alternative = "one.sided"),
    quiet_plan(test = "t_paired", effect = 0.5, r = 0.5),
    quiet_plan(test = "anova_oneway", effect = 0.25, k = 3),
    quiet_plan(test = "prop_two", p1 = 0.45, p2 = 0.30),
    quiet_plan(test = "prop_two", p1 = 0.10, p2 = 0.05, alternative = "one.sided"),
    quiet_plan(test = "cor_pearson", effect = 0.3),
    quiet_plan(test = "cor_pearson", effect = -0.3, alternative = "one.sided"))
  for (p in cases) {
    s <- simulate_power(p, reps = 10000, seed = 1)
    expect_lte(abs(s$power_sim - s$power_analytic), 0.02)
    expect_gte(s$power_sim, p$power - 0.02)
    expect_true(s$pass)
  }
})
```

Davranış testleri: aynı tohum aynı sonuç ve `.Random.seed` korunur (`set.seed(5); a <- runif(1); ...`), `reps = 10` hata, `n = 1` hata, kayıplı planda `s$notes` boş değil ve `n` analitik n, `simulate_power(plan_precision(e = .05))` `err_precision_plan`, `print` çıktısında (EN) `Empirical power`. Bilinen kenar: `cor_pearson` r .8 n 10 için `expect_false(s$pass)` ve çıktı yöntem notu (açık soru 3'te bu testin kalıp kalmayacağı sorulur; Fisher z yaklaşımının küçük n farkı).

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'simulate')"`
Expected: FAIL.

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`. `check.ps1` süresi: simülasyon testleri `R CMD check` altında da koşar (`skip_on_cran` yalnız `NOT_CRAN` ayarsızken atlar); süre kabul edilir mi diye 11a sonunda ölçülür (açık soru 5).

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi (kullanıcıya: `simulate_power(p, reps = 2000)` ve bilerek `reps = 5`), `docs/devlog.md` girdisi. Commit yalnız istenirse (`feat: add simulation check for power`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/simulate.R` (döngü, tohum, özet, `print`, roxygen ~20) | ~65 |
| `R/tests.R` (5 test × `power` + `simulate`) | ~35 |
| `R/engine.R` (`engine_power_*`) | ~20 |
| **Kod toplamı** | **~120** |
| `inst/i18n/messages.csv` | ~12 satır (kod sayılmaz) |
| `tests/testthat/test-simulate.R` | ~75 (kod sayılmaz) |

150'nin altında. **Bölme:** ki-kare, `reg_overall`, `reg_partial` (Dilim 9/9b gerektirir) ayrı dilim 11b'dir (`2026-11-14-dilim-11b-simulasyon-ki-kare-regresyon.md`, ~55 satır).

## Dilim 9, 9b, 10 ile etkileşim ve çelişkiler

- Dilim 9 "simülasyon testi bu dilimde yok; yayından önce tüm testler için" diyor. Bu plan onu iki katmana ayırır: **11a/11b** = `simulate_power()` işlevi ve testthat'ta sabit birkaç vaka (kullanıcının de kullanabileceği özellik); **13b** = yayın öncesi rastgele plan ızgarası. Dilim 9'un "Dilim 11'e bırakılsın mı?" sorusu bu yanıtla uyumlu.
- Dilim 9 yordayıcıları rastgele üretilen simülasyonda fark ≈ .018 diyor; 9b ve bu çalışma küçük n/büyük R²'de fark > .02 buldu (R² .30, k 3, n 30: .043). Regresyon simülasyonu 11b'de ele alınır.
- Dilim 10 `check_plan` kolu burada kesinlik nesnesini `simulate_power`'dan da reddeder.

## Açık sorular

1. **Ad ve dönüş:** `simulate_power()` uygun mu (`validate_plan()` ya da `check_by_simulation()` alternatifler)? Dönüşte `pass` mantıksal alanı yeterli mi?
2. **Kayıp/DEFF:** Yalnız not mu (öneri), yoksa MCAR kayıp simülasyonu (`n_recruited` üretip her gözlemi `dropout` olasılığıyla silmek, ~8 satır) eklensin mi? DEFF simüle edilemez.
3. **Bilinen kenar (cor r .8, n 10, fark .041):** Sınır .02'yi aşıyor. Kural "aynı yöntemde aşılırsa dur", ama burada fark yöntemden (Fisher z yaklaşımı) kaynaklanıyor ve Dilim 7 belgeliyor. Testte `pass = FALSE` beklenen davranış olarak kalsın mı, yoksa `cor_pearson` için "n < 30'da yaklaşık" uyarısı mı eklensin? Kullanıcı kararı gerekir; toleransı genişletmiyorum.
4. **Yöntem referansı:** Analitik gücün bağımsız referansı için `pwr` kullanıldı; iki oran için `power.prop.test` aynı n'de aynı güç (.8016) verdi. Başka referans gerekir mi?
5. **Test süresi:** 8 vaka × 10.000 tekrar ≈ 20-25 s (ANOVA 9 s dahil). `dev\check.ps1` içinde `NOT_CRAN` ayarsız çalışırsa testler `skip_on_cran` ile atlanır; kullanıcı `devtools::test()` çalıştırınca koşar. Bu dağılım kabul mü, yoksa `check.ps1`'i `NOT_CRAN=true` ile de çalıştıralım mı?
6. **`anova(lm())` hızı:** 10.000 tekrar ~9 s; daha hızlı `.lm.fit` yolu kullanılırsa planlanan test (F) birebir çağrılmaz. Hız yerine sadakati seçtim; ister misin?
7. **ANOVA ortalama örüntüsü:** F testinin gücü yalnız f'ye bağlı, ama kullanıcıya "eşit aralıklı ortalamalar kullanıldı" notu yazılsın mı?
