# Dilim 11b: simülasyon, ki-kare ve regresyon testleri

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development veya superpowers:executing-plans. Adımlar `- [ ]` ile izlenir.

**Durum:** 2026-11-15'te güncel `main`'e (11a sonrası, `8a25b99`) göre yeniden yazıldı. Bağımsız plan kontrolünden (1 engel, 5 düzeltme, 4 küçük bulgu) sonra güncellendi.

**Amaç:** `simulate_power()` kalan üç testi kapsar: `chisq_indep`, `reg_overall`, `reg_partial`. Bundan sonra `test_spec`'teki her test simüle edilebilir.

**Mimari:** 11a ile aynı. Üç `test_spec` girdisine `power` ve `simulate` alanları, `R/engine.R`'a `engine_power_chisq` ve `engine_power_reg`. Regresyonda yordayıcıların üretimi gücü değiştirir, bu yüzden `simulate_power()`'a yeni argüman gelir: `predictor_type = c("fixed", "random")`.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` §6, §8 madde 11.

## Kısıtlar

- `D:\R-4.6.1\bin\Rscript.exe`; `TEMP`/`TMP`/`TMPDIR` = `D:\rtmp`. R kodu ASCII; metin `inst/i18n/messages.csv`'de, `en` ve `tr` birlikte.
- Tolerans .02, genişletilmez. Aynı yöntem dışındaki fark başarısızlık değildir.
- Tohum, `skip_on_cran()`, `sim_status()` 11a ile aynı. `sim_status()` değişmez. Testler 11a gibi `seed = 11` kullanır.
- Dal: `slice-11b-simulate-chisq-reg`. Commit yalnız kullanıcı isteyince.

## Kararlar (kullanıcı, 2026-11-15)

1. **Argüman adı `predictor_type`.** `plan_study()`'de `predictors` yordayıcı sayısıdır; aynı adın iki anlamı öğrenci tuzağı olurdu.
2. **Varsayılan `"fixed"`.** pwrss'in yöntemi; plan n'si buna göre.
3. **`reg_partial` + `"random"`:** simüle edilir, `status = NA`, fark yalnız raporlanır. DMAR'da kısmi R² için rastgele-X güç fonksiyonu yok (`ss_power_reg_coef` tek katsayı içindir, farklı test).
4. **Ki-kare büyük w:** `w >= w_max` ise okunur hata `err_sim_table`. Başka örüntüye düşülmez.
5. **`reg_overall` + `"random"` + DMAR:** simülasyon yalnız DMAR gücüyle karşılaştırılır, hedef kuralı uygulanmaz (`sim_status(planned = FALSE)`). Gerekçe: plan n'si sabit X içindir; rastgele X'te bu n'de güç hedefin altında kalır (R² .30, k 3, n 30: DMAR .7667). Hedef kuralı uygulansaydı doğru çalışan her plan KALDI alırdı ve KALDI'nın 11a'daki anlamı ("formül bu n'de tutmuyor") karışırdı. Not `random`: "Planın n'si sabit yordayıcı içindir; rastgele yordayıcı için gereken n plan çıktısındaki DMAR satırındadır."

## R'da ölçülen gerçekler

Plan: `docs/research/probes/11b-probe.R`, tohum 1, 10.000 tekrar. Kontrol ajanı ayrıca tohum 2 ve 3 ile ölçtü.

| Durum | n | pwrss | sabit X sim. | rastgele X sim. | DMAR rastgele güç |
|---|---|---|---|---|---|
| R² .13, k 3 | 77 | .8001 | .8017 | .7818 | .7845 |
| R² .30, k 3 | 30 | .8059 | .8078 | .7681 | .7667 |
| R² .05, k 10 | 318 | .8003 | .7985 | .7906 | .7958 |
| `reg_partial` ΔR² .10, kov. R² .20, k 5, tested 2 | 71 | .8021 | .8029 | - | - |

| Ki-kare | n | pwrss | sim. | sonuç |
|---|---|---|---|---|
| 3x3, w .30 | 133 | .8013 | .8115 | pass (pay en dar, +.0102) |
| 2x2, w .30 | 88 | .8035 | .8095 | pass |
| 2x5, w .10 | 1194 | .8002 | .7998 | pass |
| 2x3, w .80 | 16 | .825 | .9673 | warn (formül küçük n'de tutucu) |

- Sabit X (ortalanmış dik sütunlar, `sum(x^2) = n`, eşit eğimler) ncp'yi f2·n yapar; pwrss `lambda <- f.squared * n` kullanır. Aynı yöntem.
- `reg_partial` verisi gerçek ΔR² ve kovaryat R²'den kurulur: test edilen sinyal ΔR²/(1-R²tam), kovaryat sinyali kov/(1-R²tam), hata varyansı 1. 9b'nin `effect_test` dönüşümü kullanılmaz; böylece dönüşüm bağımsız sınanır.
- DMAR `ss_power_R2(specified_N = n, random_predictors = TRUE)` ile rastgele normal X simülasyonu aynı model.
- Ki-kare örüntüsü (eşit marjinaller, `M = outer(a, b)` normalize) w'yi birebir verir. Örüntünün üst sınırı `w_max = 1/(sqrt(rc) * max|M|)`: 2x2 1, 2x3 .8165, 3x3 .6667, 3x4 .6086, 5x5 .5, 2x5 .707. Bu, tablonun değil örüntünün sınırıdır.

## Değişiklikler

1. **`R/engine.R`:** `engine_power_chisq(n, w, df, alpha)` = `pwrss::power.chisq.gof(...)$power`; `engine_power_reg(n, r2, k, alpha, tested = k)` = `pwrss::power.f.reg(...)$power`.
2. **`R/tests.R`:**
   - `chisq_indep$simulate`: `make_table(rows, cols, w)`, `rmultinom`, `chisq.test(correct = FALSE)`. `w >= w_max(rows, cols)` ise `err_sim_table` (`>=`: w_max'ta en küçük hücre kayan noktada negatif çıkabiliyor, 5x5'te `-7e-18`).
   - `reg_overall$simulate` ve `reg_partial$simulate`: `plan$predictor_type` okunur. `fixed`'de X çağrı başına bir kez kurulur, `random`'da her tekrarda `rnorm`. F testi `qr` artıklarından, p değeri `pf` ile.
   - `simulate(n, plan)` imzası değişmez. `simulate_power()` seçimi plan kopyasına yazar (`plan$predictor_type <- predictor_type`); 11a'nın beş fonksiyonu dokunulmadan kalır.
   - Başlık yorumu (`R/tests.R:23-24`, "only the five tests") güncellenir.
3. **`R/random_predictors.R`:** yeni `dmar_power(r2, k, n, alpha)`. Değer `r$value[r$term == "actual_power"]` (test-random-x.R:17 gibi). `random_predictor_n` ile aynı koruma: `has_dmar()`, `n > RANDOM_N_MAX`, `tryCatch` (hata ya da uyarı). Sorun olursa `NULL`.
4. **`R/simulate.R`:**
   - `predictor_type = c("fixed", "random")`, `match.arg` yerine `check_choice(..., exact = TRUE)`. Regresyon dışı testte `"random"` → `err_sim_predictor_type`.
   - En küçük n: regresyonda `max(spec$min_n, plan$predictors + 2)` (en az 1 artık serbestlik derecesi). Yoksa n 5, 10 yordayıcıda F NaN olur ve güç sessizce 0 çıkar.
   - Analitik güç ve durum:

     | Durum | `power_analytic` | `reference` | `status` | not |
     |---|---|---|---|---|
     | `fixed` (tüm testler) | pwrss | `"pwrss"` | 11a kuralı | - |
     | `reg_overall` + `random`, DMAR var | DMAR | `"dmar"` | `planned = FALSE` | `random` |
     | `reg_overall` + `random`, DMAR yok/kullanılamıyor | pwrss | `"pwrss"` | `NA` | `random_no_dmar` |
     | `reg_partial` + `random` | pwrss | `"pwrss"` | `NA` | `random_partial` |

   - Sonuç nesnesine `predictor_type` ve `reference` alanları.
   - `print`: `reference == "dmar"` ise `sim_analytic_dmar`, değilse `sim_analytic`.
   - `err_sim_unsupported` ve `spec$simulate` NULL kontrolü silinir: desteklenmeyen test kalmaz.
   - Roxygen: `@param plan` (sekiz test), `@param n` (ki-kare ve regresyonda toplam n), yeni `@param predictor_type`, `@return` (yeni alanlar), `@details` warn listesine büyük w'li küçük ki-kare. `man/` `devtools::document()` ile yenilenir.
5. **`R/validate.R` `check_simulation()`:**
   - Not izin listesi: `adjust, n, reps, random, random_no_dmar, random_partial`.
   - `identical(is.na(st), x$reps < 10000)` kuralı şuna döner: `is.na(st)` ancak ve ancak `reps < 10000` ya da notlarda `random_no_dmar`/`random_partial` var.
   - `predictor_type` `"fixed"`/`"random"`; `"random"` yalnız regresyonda. `reference` `"pwrss"`/`"dmar"`.
6. **CSV (en + tr):** `err_sim_table` (bu tablo için w_max'ı gösterir; sınırın planın değil simülasyon örüntüsünün olduğunu söyler), `err_sim_predictor_type`, `sim_analytic_dmar`, `sim_note_random`, `sim_note_random_no_dmar` ("DMAR kurulu değil ya da bu n'de kullanılamıyor"), `sim_note_random_partial`, `sim_n_chisq_indep`, `sim_n_reg_overall`, `sim_n_reg_partial` (toplam n). `sim_explain`: "pwrss formülü" yerine "formül (pwrss; rastgele yordayıcıda DMAR)", "normal (ya da binom)" yerine "normal, binom ya da multinom". `err_sim_unsupported` silinir.

## Testler (önce yazılır, `tests/testthat/test-simulate.R`'a eklenir)

- Analitik güç referansları, tolerans 1e-3: `pwr::pwr.chisq.test` (3x3 n 133, 2x2 n 88); `pwr::pwr.f2.test` (R² .13, k 3, n 77); `reg_partial` için 9b'deki gibi ölçeklenmiş `pwr.f2.test`.
- `sim_cases()`'e ekle (`fixed`, `pass`): üç ki-kare, üç `reg_overall`, `reg_partial` r2_change ve `reg_partial` f2.
- `warn_cases()`'e ekle: ki-kare 2x3, w .8, n 16.
- `random`, DMAR varsa (`skip_if_not(has_dmar())`): R² .30, k 3, n 30 için `reference == "dmar"`, `status == "pass"`, `"random"` notta, `power_analytic` pwrss gücünden en az .02 düşük.
- `random`, DMAR yok (`local_mocked_bindings(has_dmar = function() FALSE)`): `status` NA, `random_no_dmar` notu, `power_analytic` pwrss.
- `reg_partial` + `random`: `status` NA, `random_partial` notu.
- `w_max` sabit değerleri; 5x5, w .5 planında `err_sim_table`.
- `t_independent` + `"random"` → `err_sim_predictor_type`; iki dilde.
- En küçük n: `reg_overall`, `predictors = 10`, `n = 11` → `err_sim_n` (12 gösterir); `n = 12` çalışır.
- Sabit X üreticisi: sütunlar dik, ortalama 0, `sum(x^2) = n`.
- Varsayılan çağrı (`simulate_power(plan)`, 10.000 tekrar) her yeni test için yazdırılabilir; çıktıda toplam n birimi, DMAR vakasında `sim_analytic_dmar` satırı.
- `check_simulation`: elle bozulmuş `predictor_type`, `reference` ve not reddedilir.

**Önce tohumla doğrula:** Uygulayıcı her `pass` ve `warn` vakasını önce `seed = 11` ile çalıştırır. En dar vaka 3x3 ki-kare (+.0102, MC SE ~.004). Bir vaka beklenen sonucu vermezse tohum değiştirilmez, tolerans genişletilmez: dur ve kullanıcıya getir.

**Değişecek iki mevcut test (kullanıcı onayı gerekir):**
- "power and simulate exist for the five tests of slice 11a only" artık sekiz testi bekler.
- `err_sim_unsupported` vakası (ki-kare) silinir.

İkisi de 11a'nın sınırını sabitliyordu; 11b bu sınırı kaldırır.

## Boyut

Kod ~115 satır (`tests.R` ~45, `simulate.R` ~30, `engine.R` ~8, `random_predictors.R` ~10, `validate.R` ~8, `print` dalı dahil). 150 sınırının altında, tek dal.

## Denenmeyenler

- Büyük tablolarda süre: `rows`/`cols` 1000'e kadar izinli; 10.000 tekrarlı `chisq.test` çok yavaş olabilir. Bu dilimde sınır eklenmez.
- DMAR kurulu olmayan ortamda `check`: 9c'deki gibi DMAR gizlenip denenecek.
