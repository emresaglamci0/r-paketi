# Dilim 13b: yayın öncesi simülasyon taraması (tüm testler)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development veya superpowers:executing-plans. Adımlar `- [ ]` ile izlenir.

**Durum:** 2026-11-15'te 11b sonrası `main`'e (`2b723f0`) göre yeniden yazıldı. Eski taslak `simulate_power(predictors = ...)` ve kendi `classify` etiketlerini varsayıyordu; ikisi de artık yanlış.

**Amaç:** Spec §8 madde 13: "yayından önce tüm testler için simülasyonla güç testi". Her `test_spec` testi için tohumlu rastgele bir plan ızgarası `simulate_power()` ile sınanır. Sonuç bir CSV ve özet tabloya yazılır. 11a/11b yalnız bilinen 1-3 vakayı sınıyor; 13b bilinmeyen bileşimlerde (küçük n, uç etki, çok yordayıcı, büyük tablo) yöntemin sınırını arar. 13a'nın (GitHub yayını) kapısıdır.

**Mimari:** Paket koduna ve testlere dokunulmaz. Yeni betik `dev/release-sim.R` (`dev/` `.Rbuildignore`'da) yalnız `plan_study()` ve `simulate_power()` çağırır. Sınıflandırma için kendi kuralını yazmaz: `simulate_power()`'ın `status` alanını kullanır (spec §6 kuralı orada, 11a/11b testleriyle korunuyor). Çıktı `docs/release-sim/2026-11-15.csv` ve `.md`.

**Spec:** §6 (simülasyon ve çelişki kuralı), §8 madde 13.

## Kısıtlar

- `D:\R-4.6.1\bin\Rscript.exe`; `TEMP`/`TMP`/`TMPDIR` = `D:\rtmp`. Çıktı depoda `docs/release-sim/`.
- R kodu ASCII. Yeni hesap yok.
- Tolerans .02 genişletilmez. Tohum sonuç beğenilmediği için değiştirilmez.
- Dal: `slice-13b-release-sim`. Yalnız `dev/` ve `docs/` değişir. Commit yalnız kullanıcı isteyince.

## Ölçülen süreler (2026-11-15, 20.000 tekrar, plan n'sinde)

t 1,7 s; eşli 1,3 s; ANOVA 7,2 s; iki oran 1,4 s; korelasyon 1,4 s; ki-kare 0,8 s; regresyon genel 1,1 s (rastgele 1,4 s); kısmi 1,1 s. Kontrol ajanının en kötü uçları (alfa .01, güç .9): ANOVA f .1 k 8 13 s; `reg_overall` R² .02 k 12 8 s (rastgele 18 s); `reg_partial` ΔR² .01, 12'de 11 13 s (rastgele 26 s). Koşu sayısı 8 test × 28 = 224, artı 56 rastgele regresyon = **280 koşu, ~15-25 dk**. 100.000 tekrarlı yeniden koşu plan başına en çok ~130 s. Yerel koşu yeterli.

## Izgara (tohum 20261115, test başına 25 rastgele plan + 3 elle seçilmiş kenar vaka)

Her plan `effect_basis = "pilot"`, kayıp 0, DEFF 1 (simülasyon bunları kapsamaz). Güç ∈ {.8, .9}, alfa ∈ {.05, .01}; yönlü testlerde yön ∈ {iki, tek}.

| Test | Rastgele aralık | Kenar vakalar |
|---|---|---|
| `t_independent` | d ∈ [.15, 1.5] log-düzgün | d 1.5 (küçük n), d .15 (büyük n), tek yönlü d .8 |
| `t_paired` | d ∈ [.2, 1.2], r ∈ [-.3, .9] | r .9 d .6, r -.3, d 1.2 r .5 |
| `anova_oneway` | f ∈ [.1, .6], k ∈ 2..8 | k 2, k 8 f .6, f .1 |
| `prop_two` | p1, p2 ∈ [.05, .95], \|fark\| ≥ .08 | .05/.01 tek yönlü (bilinen warn), .95/.85, .5/.4 |
| `cor_pearson` | \|r\| ∈ [.1, .8], işaret rastgele | r .8 (bilinen warn), r -.5 tek yönlü, r .1 |
| `chisq_indep` | rows, cols ∈ 2..5; w ∈ [.1, .9 × w_max] | 2x2 w .5, 5x5 w .1, 2x3 w .8 (bilinen warn) |
| `reg_overall` | R² ∈ [.02, .4], predictors ∈ 1..12 | R² .4 k 1, R² .02 k 12, R² .3 k 3 |
| `reg_partial` | ΔR² ∈ [.01, .2], kov. R² ∈ [0, .3], predictors ∈ 2..12, tested ∈ 1..predictors-1, ΔR² + kov. ≤ .6; her 5 plandan biri f2 girdisi | tested 1 k 2, tested 11 k 12, kov. 0 |

- Regresyon planları iki kez koşulur: `predictor_type = "fixed"` ve `"random"`.
- `w_max` paket içi yardımcıdır: betik `plansize:::w_max` ile çağırır.
- `reg_partial` f2 girdisi: çekilen ΔR² ve kov. R²'den türetilir (kısmi R² = ΔR²/(1 − kov.), f2 = kısmi/(1 − kısmi)). Böylece yalnız girdi yolu değişir.
- Kenar vakalar alfa .05, güç .8 ile sabittir ve çözülebilir olmalıdır. Kontrol ajanı eşli r .9, d ≥ 1'in pwrss'te "n 4'ün altında" hatası verdiğini buldu; eşli kenar vakası r .9, d .6 olur. Uygulayıcı her kenar vakanın `plan_study()`'den geçtiğini öz-sınamada doğrular. Geçmeyen kenar vaka çıkarsa durur ve rapor eder.
- **Atlanan planlar:** `plan_study()` hata verirse satır `skipped` olarak, hata metniyle yazılır. Sessizce kaybolmaz. Hata metni pwrss'in çözülemeyen tasarım mesajlarından (`err_infeasible*`) biri değilse betik durur: bu, argüman kurucusunda hata demektir (ör. ANOVA'ya `alternative` geçmek). Bir testin rastgele planlarının %20'sinden fazlası atlanırsa da durur.
- **Tohumlar:** plan i'nin tohumu 20261115 + i, yeniden koşunun tohumu plan tohumu + 1.000.000. İkisi de tamsayı aralığında.

## Sınıflandırma

`simulate_power()` sonucu doğrudan kullanılır:

| `status` | Anlamı | Rapor etiketi |
|---|---|---|
| `pass` | formül bu n'de tutuyor | `ok` |
| `warn` | ampirik güç formülden > .02 yüksek; plan güvenli, formül tutucu | `conservative` |
| `fail` | açıklanmamış sapma | `fail` → yeniden koşu |
| `NA`, not `random_partial` | rastgele `reg_partial`: karşılaştırılacak formül yok | `info_random` |
| `NA`, not `random_no_dmar` | rastgele `reg_overall`, DMAR kullanılamadı (yok, hata, uyarı ya da n > 1e5) | `info_no_dmar` |
| `NA`, not `reps` | 10.000'den az tekrar (yalnız öz-sınamada) | `low_reps` |

Başka bir `NA` durumu betikte hata verir.

- **Yeniden koşu:** `fail` alan her plan yeni tohumla 100.000 tekrar koşulur. İki satır da CSV'de kalır; karar yeniden koşuya göre verilir. Yine `fail` ise **betik özet yazıp `quit(status = 1)` ile durur, kullanıcıya getirilir.**
- **Çoklu karşılaştırma:** 280 koşu, 20.000 tekrar (MC SE güç .8-.9'da ≈ .0028, en çok .0035). Gerçek fark .01 olan bir plan rastlantıyla .02'yi en çok %0,2 olasılıkla aşar; gerçek fark 0 ise olasılık yok denecek kadar küçüktür. Yeniden koşu rastlantıyı ayırır. **Sınır:** .02'nin hemen üstündeki gerçek bir sapma (ör. −.021) yalnız yaklaşık yarı yarıya yakalanır (ilk koşuda .64, yeniden koşuda .79). Bu tarama kaba sapmaları bulur; .02 sınırındaki küçük sapmaları kanıtlamaz.
- **Bilinen `conservative` aileleri (koşudan önce sabit, sonradan gevşetilmez):**
  - korelasyon: \|r\| ≥ .6 iki yönlü, ≥ .5 tek yönlü (11a);
  - iki oran: min(p1, p2) ≤ .15 (.13/.05 tek yönlü +.018 ölçüldü);
  - ki-kare: w / w_max ≥ .45 (kontrol ajanı: 3x3 w .4 +.032, 3x3 w .3 +.020, .9 × w_max'ta her boyut warn).

  Bu ailelerin dışında çıkan her `conservative` özette ayrı işaretlenir ve kullanıcıya bulgu olarak getirilir. Dilimi durdurmaz.

## Çıktı

- **CSV sütunları:** `test, predictor_type, params, n, reps, seed, power_sim, ci_lo, ci_hi, power_analytic, reference, diff, target, status, label`.
- CSV'de yorum satırı ve zaman damgası yok; `params` sabit biçimde yazılır. Aynı tohum aynı CSV'yi verir.
- **Özet `.md`:** `sessionInfo()` özeti; `pwrss`, `plansize` ve `DMAR` sürümleri; test başına koşu sayısı, en büyük \|fark\|, etiket sayıları, `conservative` listesi (aile içi ve dışı), atlananlar ve hata metinleri, yeniden koşu sonuçları, süre.

## Adımlar

- [ ] **Step 1: Öz-sınama önce (`dev/release-sim-selftest.R`).** Betik fonksiyonlarını kaynaklar. Şunları sınar:
  - Izgara üreticisinin aynı tohumla aynı planları verdiğini.
  - Her test için en az 1 plan ürettiğini.
  - `label()` eşlemesinin tüm satırları doğru çevirdiğini ve tanımsız `NA`'da hata verdiğini.
  - Her kenar vakanın `plan_study()`'den geçtiğini (sıfır atlama).
  - **Bilerek bozma, betiğin kendi mantığında:** simülasyon fonksiyonu yerine `status = "fail"` döndüren sahte bir fonksiyon verilir. Betik o planı yeniden koşar, kalıcı fail'i özette listeler ve `quit(status = 1)` ile durur. Satır sayısı plan sayısına eşittir. (Yalnız `power_analytic`'i değiştirmek `status`'u değiştirmez; o sınama hiçbir şeyi yakalamazdı. Dilim 2 ve 6 dersi.)
  - Atlama kuralı: beklenmeyen hata metni durdurur.
  - Küçük koşu (`reps = 500`, test başına 2 plan) iki kez çalıştırılır ve iki CSV `identical()`.
- [ ] **Step 2:** öz-sınamayı çalıştır, başarısız olduğunu gör.
- [ ] **Step 3:** `dev/release-sim.R`'ı yaz; öz-sınama geçsin.
- [ ] **Step 4: Gerçek koşu.** Depo kökünden, arka planda: `$env:TEMP='D:\rtmp'; $env:TMP='D:\rtmp'; $env:TMPDIR='D:\rtmp'; & "D:\R-4.6.1\bin\Rscript.exe" dev\release-sim.R 20000 25 20261115`. Başka `check` ya da test turu ile aynı anda koşulmaz (Dilim 11a dersi).
- [ ] **Step 5:** Kalıcı `fail` varsa dur. Sonra `devtools::test()` ve `dev\check.ps1` (paket değişmese de kural). Bağlamsız inceleme. Kullanıcıya Türkçe anlatım; 2-3 konsol örneği ve bilerek hatalı bir girdi (ör. eşli r .9, d 1.2 planı). Sonuçları kullanıcıyla okuma, `docs/devlog.md`.

## Boyut

`dev/release-sim.R` ~120 satır, `dev/release-sim-selftest.R` ~40 satır. Paket kodu 0. Tek dal.

**Gerçekleşen (2026-11-15):** iki betik inceleme düzeltmeleriyle 287 satır (197 + 90). Kullanıcı ~150 hedefinin bu dilimde aşılmasını kabul etti (kod paket dışında, `dev/` altında). Gerçek koşu 48,7 dk sürdü; tahmin (~15-25 dk) yaklaşık 2 kat düşüktü. Kalıcı fail çıkış kodu 2'dir (1, herhangi bir R hatasıdır). Çıktı yolu koşu tarihinden gelir. İlk koşudan sonra özet, yeniden koşu yapılmadan aynı CSV'den yeniden üretildi.

## Kararlar (kullanıcı onayladı, 2026-11-15)

Yeniden koşu: `fail` → farklı tohum, 100.000 tekrar; kalıcı `fail` → dur.

Koşu sonrası (kullanıcı): `prop_two`'da aile dışı 3 `conservative` satırın hepsinde max(p) ≥ .85. Etiketler değişmez; özet bunu min(p) ≤ .15 ailesinin olası aynası (p ↔ 1 − p) olarak, varsayım diye yazar. Aile kuralı sonradan genişletilmez.

1. **Yer:** yerel koşu (~15-25 dk). GitHub Actions'a `workflow_dispatch` akışı eklenmez; gerekirse 13a'da.
2. **Izgara:** test başına 25 rastgele + 3 kenar vaka.
3. **Kesinlik (Dilim 10):** Wald aralığının kapsama sınaması yapılmaz. Spec yalnız güç testi diyor; Wald sınırı belgede yazılı.
4. **Sonuç yeri:** `docs/release-sim/`. Vinyette kıyas tablosu olup olmayacağı 13a'da karar verilir.
5. **`warn`:** durdurmaz, `conservative` olarak listelenir. Gerekçe: plan güvenli yönde; 11a'da kullanıcı kararı.
6. **Rastgele yordayıcı bulguları:** yalnız raporlanır. Plan n'sine pay ya da uyarı eklemek ayrı dilim ve kullanıcı kararıdır (9c'de DMAR satırı zaten var).
