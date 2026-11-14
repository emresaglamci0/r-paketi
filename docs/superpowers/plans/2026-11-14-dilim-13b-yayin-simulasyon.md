# Dilim 13b: yayın öncesi simülasyonla güç sınaması (tüm testler) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşullar:** Dilim 9, 9b, 10, 11a ve 11b `main`'de (`simulate_power` her `test_spec` girdisini kapsamalı). Dilim 13a'ya bağlı değildir; 13a'nın kapısıdır (yayın bunun geçmesini ister).

**Goal:** Spec §8 madde 13: "yayından önce tüm testler için simülasyonla güç testi yapılır (ör. regresyonda rastgele yordayıcılarla ampirik güç)". Her `test_spec` girdisi için rastgele ama tohumlu bir plan ızgarası üretilir, `simulate_power()` ile sınanır, sonuçlar bir tabloya yazılır ve bilinen yöntem farkları ile açıklanamayan sapmalar ayrılır. Açıklanamayan sapma varsa dilim durur, kullanıcıya getirilir.

**Architecture:** Paket koduna **hiçbir şey eklenmez**. Betik `dev/release-sim.R` (`dev/` `.Rbuildignore`'da, pakete girmez) `plansize::simulate_power` çağırır; çıktı `docs/release-sim/<tarih>.csv` ve özet `docs/release-sim/<tarih>.md`. GitHub'da elle tetiklenen `release-sim.yaml` (`workflow_dispatch`) aynı betiği çalıştırabilir (isteğe bağlı, açık soru 4).

**Tech Stack:** R 4.6.1, plansize (yerel), pwrss 1.3.3, pwr (bağımsız analitik referans, `Suggests`).

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§6 simülasyon kuralı ve çelişki kuralı, §8 madde 13)

## Sınır: Dilim 11 / 11b ile 13b ne farklı?

| | Dilim 11a/11b (`devtools::test()`) | Dilim 13b (yayın öncesi) |
|---|---|---|
| Ne | `simulate_power()` işlevi + her test için **sabit, bilinen** 1-2 vaka | Her test için **rastgele, tohumlu** plan ızgarası |
| Tekrar | 10.000 | 20.000 |
| Nerede | `tests/testthat/`, `skip_on_cran()` | `dev/release-sim.R`, testthat dışı, `R CMD check` dışı |
| Ne zaman | her `devtools::test()` | elle, yayından önce (ve simülasyon/motor kodu değişince) |
| Başarısızlık | test kırmızı | rapor satırı; açıklanamayan sapma = dur |
| Süre | ~25-40 s | ~40-60 dk |
| Çıktı | geçti/kaldı | CSV + özet tablo (kıyas tablosu, spec §11) |

Kısaca: 11 işlevin ve **bilinen** vakaların doğruluğunu CI'da korur; 13b **bilinmeyen** parametre bileşimlerinde (küçük n, uç etki, çok yordayıcı, büyük tablo) yöntemin gerçek sınırını bulur. 13b testthat'a girmez: yavaş, rastgele ve "bulgu üretir", geçti/kaldı vermez.

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`. Çıktı D sürücüsünde (depoda `docs/release-sim/`).
- R kodu ASCII. Hesap `pwrss`'ten (analitik) ve `stats` testlerinden (simülasyon); yeni güç motoru yok.
- Kural (spec §6): `|ampirik - analitik| <= .02` ve `ampirik >= hedef - .02`. **Tolerans genişletilmez.** Aşım: önce yöntem farkı mı bak (Dilim 7 Fisher z, Dilim 9b rastgele yordayıcı, ki-kare küçük hücre); açıklanırsa tabloya "bilinen yöntem farkı" olarak yazılır, açıklanamıyorsa dur.
- Çoklu karşılaştırma: ~230 plan, 20.000 tekrar (SE ≤ .0035). Gerçek fark sıfırken bir planın |fark| > .02 çıkma olasılığı 5,7 SE ≈ 1e-8; yani tek bir aşım rastlantı sayılmaz. Gerçek fark .01 ise aşım olasılığı ≈ %0,2/plan, 230 planda ≈ %35'e yaklaşır; bu yüzden aşan planlar **yeniden** (farklı tohumla, 100.000 tekrar) koşulur; kalıcı aşım gerçek sapmadır.
- Sonuç dosyaları depoya girer (`docs/` build'e girmez); commit yalnız kullanıcı onayından sonra.
- Dal: `slice-13b-release-sim` (yalnız `dev/` ve `docs/` değişir).

## Doğrulanmış gerçekler (11a/11b/9b çalışmalarından)

- 10.000 tekrarla sabit vakalar ±.02 içinde: bağımsız t d .5 n 64: .8064/.8015; eşli t: .8049/.8078; ANOVA f .25 k 3 n 53: .8026/.8049; iki oran .45/.30 n 163: .7967/.8016; r = .3 n 85: .8016/.8003; ki-kare w .3 3x3 n 133: .8137/.8013 (fark .012; 11b'deki sabit `make_table` örüntüsüyle); 2x2 n 88: .8088/.8035; `reg_overall` .13/3/77 rastgele X: .789/.800.
- Bilinen sapmalar (13b'de tabloya "yöntem farkı" olarak girecek, **yeni değil**): (1) Pearson r = .8, n = 10: ampirik .869, analitik .828 (fark .041; Fisher z yaklaşımı küçük n'de muhafazakâr); (2) `reg_overall` rastgele yordayıcı R² .30, k 3, n 30: analitik .806, ampirik .762 (fark .043); (3) `reg_partial` rastgele yordayıcı .13/0/3/1/55: .771/.803 (fark .032), .10/.20/5/2/71: .771/.802.
- Ki-kare üretici: eşit marjinal tabloda `w` üst sınırı tabloya bağlı (2x2: 1.0; 3x3: .667; 5x5: .5); ızgara bu sınırın altında kalır.
- Süre ölçümleri (10.000 tekrar): t ~0,6 s, eşli ~0,5 s, ANOVA ~8,6 s, iki oran ~0,6 s, r ~0,5 s, ki-kare ~0,3 s, regresyon ~4 s. 20.000 tekrarla ızgara başına ~15-20 dk tahmin; toplam ~40-60 dk (ANOVA ve regresyon baskın).
- `pwrss` n'si yalnız pwrss için ±1 aynıdır; 13b n'yi değil **güç farkını** kıyaslar.

## Kararlar (öneri; açık sorulara bak)

- **Izgara (tohum 20261114):** her test için 25 rastgele plan; parametre aralıkları (n'nin 6 ile 2000 arasında kalacağı etki aralıkları):
  - `t_independent`: d ∈ [0.15, 1.5] (log-düzgün), güç ∈ {.8, .9}, alfa ∈ {.05, .01}, yön ∈ {iki, tek}.
  - `t_paired`: d ∈ [0.2, 1.2], r ∈ [-0.3, 0.9].
  - `anova_oneway`: f ∈ [0.1, 0.6], k ∈ 2..8.
  - `prop_two`: p1, p2 ∈ [.05, .95], |fark| ≥ .08.
  - `cor_pearson`: |r| ∈ [.1, .8], işaret rastgele, yön ∈ {iki, tek}.
  - `chisq_indep`: rows, cols ∈ 2..5, w ∈ [.1, w_max(rows, cols) × .9] (`w_max` Dilim 11b'de tanımlıdır: `plansize:::w_max`).
  - `reg_overall`: R² ∈ [.02, .4], predictors ∈ 1..12.
  - `reg_partial`: ΔR² ∈ [.01, .2], kovaryat R² ∈ [0, .3], predictors ∈ 2..12, tested ∈ 1..predictors-1; ΔR² + kovaryat ≤ .6.
  - Her plan `effect_basis = "pilot"`; kayıp/DEFF 0 (simülasyon bunları kapsamaz).
- **Regresyon iki kez:** `predictors = "fixed"` (**pass ölçütü**, aynı yöntem) ve `"random"` (**yalnız rapor**, fark ve eğilim: hangi n/R²/k'da > .02).
- **Rapor:** CSV sütunları `test, params, n, reps, power_sim, ci_lo, ci_hi, power_analytic, diff, status` (`status` ∈ `ok`, `known_method_gap`, `unexplained`, `info_random`). `known_method_gap` yalnız yukarıdaki üç belgelenmiş aile için ve yalnız tanımlı koşulda (örn. cor n < 30; `reg_*` rastgele). Özet `.md`: test başına en büyük |fark|, aşan sayısı, bilinen/bilinmeyen, süre.
- **Sert durak:** `unexplained` ≥ 1 ve 100.000 tekrar ile tekrarlayınca sürerse: dur, çelişki kuralı gereği kullanıcıya getir (tolerans genişletme yok).
- **Yeniden üretilebilirlik:** betik `sessionInfo()` ve paket sürümlerini (`pwrss`, `plansize`) CSV başlığına yazar.

## Review Focus

- Betik paket koduna dokunmuyor; `git diff` yalnız `dev/` ve `docs/release-sim/`.
- `known_method_gap` etiketi koşulu açıkça kontrol ediyor (örn. yalnız cor ve n < 30), geniş bir "hepsini affet" değil.
- Aynı tohumla betik iki kez aynı CSV'yi üretir (ilk 3 plan için kontrol).
- Aralıklar uç değerleri (n 6 civarı, 2000 üzeri) kapsıyor; `plan_study` hata verirse (infeasible) o plan atlanır ve `skipped` olarak sayılır, sessizce kaybolmaz.
- Özet "bulgu" ve "sınır" ayrımı doğru: hiçbir sapma sessizce `ok` yazılmamış.

---

### Task 1: `dev/release-sim.R` ve ilk koşu

**Files:**
- Create: `dev/release-sim.R`, `docs/release-sim/<tarih>.csv`, `docs/release-sim/<tarih>.md`, isteğe bağlı `.github/workflows/release-sim.yaml`
- Modify: yok (paket kodu ve testler değişmez)

**Interfaces:** `Rscript dev/release-sim.R [reps] [plans_per_test] [seed]` (varsayılan 20000, 25, 20261114); yalnız `plansize::plan_study`, `simulate_power` ve `stats` çağırır.

- [ ] **Step 1: Betik için önce küçük, hızlı doğrulama testi (`tests/testthat` DIŞINDA, `dev/release-sim-selftest.R`)**

`reps = 500`, `plans_per_test = 2` ile betiğin çalıştığını, CSV sütunlarını ve `status` mantığını sınar: bilinen kenar (`cor_pearson` r .8 → `known_method_gap`, `reg_overall` random → `info_random`), kasıtlı bozulmuş analitik güç (+.05 ekle) → `unexplained` (betiğin kuralı gerçekten yakaladığını gösteren "bilerek bozma" denemesi, Dilim 2 dersi).

```r
# expect_status() style self-test, run by hand
stopifnot(classify(power_sim = 0.869, power_analytic = 0.828, test = "cor_pearson", n = 10) == "known_method_gap")
stopifnot(classify(0.80, 0.85, "t_independent", 64) == "unexplained")
stopifnot(classify(0.762, 0.806, "reg_overall", 30, mode = "random") == "info_random")
stopifnot(classify(0.801, 0.800, "t_independent", 64) == "ok")
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" dev\release-sim-selftest.R`
Expected: FAIL (betik yok).

- [ ] **Step 3: Betiği yaz**

- [ ] **Step 4: Gerçek koşu**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" dev\release-sim.R 20000 25 20261114` (arka planda; ~40-60 dk).
Expected: CSV ve özet yazılır; `unexplained` sayısı 0 (değilse Step 5 durak).

- [ ] **Step 5: Durak değerlendirmesi ve dilim sonu**

`unexplained` satırları: 100.000 tekrar ve farklı tohumla yeniden koş. Sürerse kullanıcıya getir (tolerans genişletilmez). Sonuçları kullanıcıyla oku: hangi n/etki bileşiminde yöntem sınırı çıktı? Bulgular `docs/devlog.md`'ye ve (kullanıcı isterse) paket belgesine ("küçük n'de yaklaşık" notu) yazılır; belge değişikliği ayrı dilimdir. Commit yalnız istenirse (`docs: add pre-release simulation results`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `dev/release-sim.R` (ızgara üreticileri, `classify`, döngü, CSV, özet) | ~110 |
| `dev/release-sim-selftest.R` | ~20 |
| `.github/workflows/release-sim.yaml` (isteğe bağlı) | ~25 |
| **Paket R kodu** | **0** |

150'nin altı; **bölme gerekmez**. Betik şişerse ızgara üreticileri (`grid_<test>`) ayrı dosyaya çıkarılır.

## Önceki planlarla çelişkiler ve bağımlılıklar

- **Dilim 9:** "simülasyon testi bu dilimde yok; yayından önce tüm testler için birlikte yapılır" ile uyumlu; ancak Dilim 9'un ".02 sınırı yeterli" varsayımı rastgele yordayıcıda küçük n/büyük R²'de tutmuyor (fark .043). 13b bu bölgeyi sistematik haritalar ve kullanıcıdan "rastgele yordayıcı uyarısı/payı" kararı (9b açık soru 5, 11b açık soru 2) beklenir.
- **Spec §6:** simülasyon "en az 10.000 kez"; 13b 20.000 kullanır (SE daha küçük, 230 plan nedeniyle).
- **Dilim 11:** `simulate_power` imzası (`predictors`) 11b'ye bağlı; 11b yoksa 13b regresyon ve ki-kare satırlarını atlar (rapor "kapsam dışı" yazar), bu da "tüm testler" iddiasını bozar. Önkoşul bu yüzden 11b.
- **Dilim 10:** `plan_precision` `test_spec` dışı ve hipotez gücü yoktur; 13b'ye girmez. Kesinlik için ayrı bir simülasyon (oranın güven aralığı yarı genişliği ve kapsama olasılığı, Wald'ın p .5 dışında bozulması) **yapılmıyor**; kullanıcıya soru (açık soru 3).

## Açık sorular

1. **Süre ve yer:** ~40-60 dk yerel koşu kabul mü, ya da `workflow_dispatch` ile GitHub Actions'ta mı koşsun (bu 13a'ya ve GitHub deposuna bağlı)?
2. **Rastgele yordayıcı bulguları:** `info_random` farkları .02'yi aşarsa (beklenen) ne yapılsın: yalnız belge (Dilim 9 kararı 4), plan çıktısında uyarı, ya da n'ye pay? Kural "toleransı genişletme" bunu yöntem farkı sayıp `pass`'ten ayırıyor; bu ayrımı kullanıcı onaylamalı.
3. **Kesinlik (Dilim 10) kapsama sınaması:** Wald aralığının gerçek kapsama olasılığı p .5 dışında ve küçük n'de bozulur. Simülasyonla `plan_precision` için kapsama testi (yeni küçük işlev ya da betik) eklensin mi? Spec yalnız "güç testi" diyor; öneri: hayır, belgede Wald sınırı yazılı.
4. **Izgara büyüklüğü:** 25 plan/test yeterli mi? Daha çok plan = daha uzun süre. Uç kenarlar (cor n < 30 ya da küçük hücreli ki-kare) için ayrıca elle seçilmiş vakalar eklensin mi (öneri: evet, test başına 3 kenar vaka)?
5. **Sonuç dosyası yeri:** `docs/release-sim/` (build dışı, depoda) uygun mu, yoksa vinyet "Accuracy" için pakete (`inst/`) kopyalansın mı (13a açık soru 5)?
6. **`known_method_gap` kuralı:** Fisher z için "n < 30", rastgele yordayıcı için "mod = random", ki-kare için "en küçük beklenen hücre < 5" eşikleri benim varsayımım (ölçüm kısmi: r .8 n 10 ve reg R² .30 n 30 ölçüldü; ki-kare küçük hücre ölçülmedi). Eşikleri ilk koşunun verisinden mi belirleyelim, yoksa önceden mi sabitleyelim (öneri: önceden sabitle, sonradan gevşetme)?
