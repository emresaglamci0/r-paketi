# Düzeltme: yuvarlama payı (plan n'i, rastgele yordayıcı n'i)

**Kaynak:** `docs/eval/2026-11-15-rapor.md` bölüm 7 ve `docs/eval/2026-11-15-ek-kontroller.txt` bölüm 3.
**Dal:** `fix-rounding-margin` (`main`'den). Commit yalnız kullanıcı isteyince.

## Sorun

Paket düzeltilmiş n'i `ceiling(n * deff / (1 - dropout))` ile yuvarlar. Sonuç tam sayı olmalıyken kayan nokta hatası değeri biraz üstüne taşırsa n 1 artar. Örnek: 28 × 1.1 / .7 = 44.000000000000007, `ceiling` 45 verir. Paketin kendi `round_up()` yardımcısı (`R/validate.R:59`, `ceiling(x - 1e-9)`) bu payı taşır. `plan_precision` ve `simulate_power` onu kullanır, ama aşağıdaki iki yer kullanmaz.

| Yer | Şimdi | Kanıt |
|---|---|---|
| `R/plan.R:120` | `ceiling(n_analytic * deff / (1 - dropout))` | `plan_study("prop_two", p1 = .70, p2 = .33, dropout = .30, deff = 1.1)$n_per_group` 45 veriyor, doğrusu 44 |
| `R/random_predictors.R:21` | `ceiling(n * plan$deff / (1 - plan$dropout))` | `reg_overall`, R² = .10, `predictors = 3`, `dropout = .30`, `deff = 1.1`: DMAR n 105, doğrusu 105 × 1.1 / .7 = 165, paket 166 veriyor |

Hata yalnız ara sonuç tam sayı olduğunda ortaya çıkar. Pratikte bu `prop_two`'da olur, çünkü pwrss n'i yuvarlanmış verir. DMAR n'i de tam sayıdır. Diğer testlerde `n_analytic` kesirli olduğu için etki yok.

## Değişiklik (3 satır)

1. `R/plan.R:120`: `ceiling(...)` yerine `round_up(...)`.
2. `R/random_predictors.R:21`: `ceiling(...)` yerine `round_up(...)`.
3. `R/methods.R:31`: `ceiling(plan$n_analytic)` yerine `round_up(plan$n_analytic)`. Burada hata gösterilmedi. Değişiklik `simulate.R:46` ile tutarlılık için. İstemezsen bu satır çıkar.

`R/sensitivity.R:32` zaten `+ 1e-9` payını kullanıyor, dokunulmuyor. Dokümantasyon (`R/plan.R:7` "one final ceiling") değişmiyor, çünkü anlam aynı kalıyor.

## Testler (önce yazılır, önce başarısız olmalı)

- `tests/testthat/test-props.R`: `plan_study("prop_two", p1 = .70, p2 = .33, dropout = .30, deff = 1.1)` için `n_analytic` 28 ve `n_per_group` 44L. Beklenen değer pwrss'in n'i (28) ile tam kesir aritmetiğinden gelir: 28 × 11/10 × 10/7 = 44.
- `tests/testthat/test-random-x.R` (`skip_if_not_installed("DMAR")`): yukarıdaki `reg_overall` planında `random_predictor_n(plan)` 165L. Aynı testte DMAR n'inin 105 olduğu da sınanır.
- Mevcut 1773 testin hepsi geçmeli. Bir altın (golden) değer değişirse dur ve kullanıcıya getir.

## Doğruluk

Hesap motoruna dokunulmuyor. Değişiklik yalnız son yuvarlamayı etkiliyor. Kayan nokta hatası olmayan durumlarda `round_up` ile `ceiling` aynı sonucu verir. Fark yalnız tam sayının 1e-9 kadar üstünde kalan değerlerde çıkar.

## Döngü

Testler, kod, bağlamsız ajan incelemesi, `devtools::test()` ve `dev\check.ps1` (0 hata, 0 uyarı), sonra kısa Türkçe anlatım ve konsol örnekleri. Onaydan sonra `main`'e birleştirilir ve `docs/devlog.md` güncellenir. Değerlendirme raporundaki bulgu "düzeltildi" diye işaretlenir.
