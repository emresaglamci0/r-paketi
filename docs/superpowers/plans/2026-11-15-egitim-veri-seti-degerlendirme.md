# Eğitim veri setiyle paket değerlendirmesi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 500 satır x 15 değişkenli sentetik eğitim verisi üret, paketin 9 planını bu veriyi evren sayarak bootstrap ile sına, bulgu raporu yaz.

**Architecture:** Paket kodu değişmez. `dev/eval/` altında üç betik var: veri üretici, yardımcılar (etki tahmini ve bootstrap), ana değerlendirme. Paket `devtools::load_all()` ile yüklenir. Sonuçlar `docs/eval/` altına CSV ve Markdown olarak yazılır.

**Tech Stack:** R 4.6.1, base `stats`, `MASS` (recommended), `testthat`, `devtools`, paket `plansize`.

**Spec:** `docs/superpowers/specs/2026-11-15-egitim-veri-seti-degerlendirme-design.md`

## Global Constraints

- Rscript: `D:\R-4.6.1\bin\Rscript.exe`. Yolları tırnakla, depo yolu boşluk ve `ş` içerir. C sürücüsüne yazma.
- R kodu ASCII. Değişken adları ASCII (`ogrenci_id`, `mat_son`...). Rapor Türkçe, UTF-8, Edit/Write aracıyla yazılır.
- Paket dosyalarına (`R/`, `tests/`, `inst/`, `man/`, `DESCRIPTION`) dokunulmaz.
- Tohum sabit: veri `set.seed(20261115)`, bootstrap `set.seed(1)`.
- `dropout = 0`, `deff = 1`, `alpha = .05`, `power = .80`, `effect_basis = "prior_study"`. Yalnız pilot deneyinde `"pilot"`.
- Ampirik güç .80 ± .027 (3 MC SE, 2000 tekrar) içindeyse `KALDI`, değilse `INCELE`. Sınır değiştirilmez. Kötü sonuç olduğu gibi yazılır.
- Dal: `eval-education-data`. Commit yok, kullanıcı isteyince yapılır.

## Review Focus

- **Planlanan n > grup satır sayısı:** Yerine koymalı çekim yine çalışmalı. Rapor bu satırı "evrenden büyük n" diye işaretlemeli.
- **Eşit olmayan gruplar:** ANOVA, iki tabakada (tabakalı ve doğal oranlı) koşulur. Doğal oranlı sonuç paket hatası diye yazılmaz, ama paketin bu konuda uyarıp uyarmadığı rapora girer.
- **Rastgele yordayıcılar:** Veriden çekim yordayıcıları rastgele yapar. Regresyon satırları paketin kendi belgesine göre (≈ .77-.78) yorumlanır ve DMAR satırıyla kıyaslanır.
- **2x2 dışı ki-kare ve Yates:** `chisq.test(correct = FALSE)` zorunlu. Küçük beklenen hücre uyarıları `suppressWarnings` ile bastırılır, sayısı kaydedilir.
- **Bootstrap tekrarında hata:** Tek tekrarda `lm` ya da test hata verirse o tekrar `NA` olur, NA sayısı raporlanır. Döngü durmaz.

---

### Task 1: Veri üretici

**Files:**
- Create: `dev/eval/make-education-data.R`
- Create: `dev/eval/test-eval.R`
- Output: `docs/eval/egitim-500.csv`

**Interfaces:**
- Produces: `make_education_data(n = 500, seed = 20261115) -> data.frame` (15 sütun). Betik kaynak olarak yüklenince yalnız fonksiyonu tanımlar. `Rscript dev/eval/make-education-data.R` ile koşulunca CSV yazar.

- [ ] **Step 1: Testi yaz** (`dev/eval/test-eval.R`, `test_that("education data shape")`)

```r
d <- make_education_data()
expect_equal(dim(d), c(500L, 15L))
expect_identical(d, make_education_data())                 # tekrar üretilebilir
expect_setequal(levels(d$okul_turu), c("devlet", "ozel", "meslek"))
expect_true(all(d$motivasyon >= 1 & d$motivasyon <= 5))    # Likert sınırı
expect_true(all(d$devamsizlik >= 0 & d$devamsizlik == round(d$devamsizlik)))
expect_gt(mean(d$calisma_saati) - median(d$calisma_saati), 0)  # sağa çarpık
expect_false(anyNA(d))
```

- [ ] **Step 2: Koş, başarısız olduğunu gör**
`& "D:\R-4.6.1\bin\Rscript.exe" -e "source('dev/eval/make-education-data.R'); testthat::test_file('dev/eval/test-eval.R')"` beklenen: FAIL (fonksiyon yok).

- [ ] **Step 3: `make_education_data()` yaz**
Sütunlar (sıra bu): `ogrenci_id, cinsiyet, sinif, okul_turu, anne_egitim_yil, calisma_saati, devamsizlik, ders_disi, ozel_ders, motivasyon, oz_yeterlik, sinav_kaygisi, mat_on, mat_son, gecti`. Hedef yapı: `okul_turu` oranları ≈ .5/.3/.2; `ozel_ders` evet ≈ .35; `mat_son` ile `ozel_ders` d ≈ .35; `mat_on` ile `mat_son` r ≈ .7, değişim d ≈ .3; `okul_turu` üzerinde f ≈ .2; `gecti` oranı ≈ .6, `ozel_ders`'e göre fark ≈ .15; `calisma_saati` ve `mat_son` r ≈ .25; `okul_turu` x `ders_disi` w ≈ .2; `mat_son` ~ 5 yordayıcı R² ≈ .2, `motivasyon + oz_yeterlik` ΔR² ≈ .04. Likert: sürekli değer `pmin(pmax(round(x * 4) / 4, 1), 5)`. `devamsizlik` `rpois` (gizli değişkene bağlı oranla), `calisma_saati` log-normal. Tam katsayılar oluşturucunun kararı. Betik `sys.nframe() == 0` iken CSV yazar (`write.csv(..., row.names = FALSE)`).

- [ ] **Step 4: Testi koş, geçtiğini gör.** Beklenen: `[ FAIL 0 | ... | PASS 7 ]`. CSV'yi üret.

### Task 2: Etki tahmini ve bootstrap yardımcıları

**Files:**
- Create: `dev/eval/eval-helpers.R`
- Modify: `dev/eval/test-eval.R`

**Interfaces:**
- Consumes: Task 1'in `make_education_data()` çıktısı.
- Produces:
  - `estimate_effects(d) -> named list`: `d_ind, d_paired, r_paired, f_anova, p1, p2, r_cor, w_chisq, r2_reg, r2_cov, r2_change, p_gecti`. Tanımlar: `d_ind` = ortalama farkı / birleşik SD (ozel_ders evet − hayır); `d_paired` = mean(mat_son − mat_on) / sqrt((var(on) + var(son)) / 2) (paketin tanımı: tek ölçümün SD'si, `r` ayrıca); `f_anova` = sqrt(eta2 / (1 − eta2)), eta2 `aov` kareler toplamından; `p1` = ozel_ders evet grubunda gecti oranı, `p2` = hayır grubunda; `w_chisq` = sqrt(X² / n), `correct = FALSE`; `r2_reg` = `lm(mat_son ~ calisma_saati + devamsizlik + motivasyon + oz_yeterlik + sinav_kaygisi)` R²; `r2_cov` = `motivasyon` ve `oz_yeterlik` çıkarılmış modelin R²'si.
  - `boot_power(d, test, n, reps = 2000, strata = NULL) -> list(power, mc_se, n_na)`: `strata` bir sütun adıysa her düzeyden `n` satır, yoksa toplam `n` satır yerine koymalı çekilir. Testler: `t.test(var.equal = TRUE)`, `t.test(paired = TRUE)`, `oneway.test(var.equal = TRUE)`, `prop.test(correct = FALSE)`, `cor.test`, `chisq.test(correct = FALSE)`, `lm` genel F, `anova(lm_kucuk, lm_buyuk)`. Her tekrar `tryCatch` ile sarılır. Hata `NA` sayılır, güç `mean(p < .05, na.rm = TRUE)`.

- [ ] **Step 1: Testleri ekle**

```r
test_that("effect estimators match base R identities", {
  d <- make_education_data(); e <- estimate_effects(d)
  tab <- table(d$okul_turu, d$ders_disi)
  expect_equal(e$w_chisq, sqrt(unname(chisq.test(tab, correct = FALSE)$statistic) / 500))
  expect_equal(e$r_cor, cor(d$calisma_saati, d$mat_son))
  expect_equal(e$r2_change, e$r2_reg - e$r2_cov)
})
test_that("boot_power is near alpha under the null and handles strata", {
  d <- make_education_data(); d$z <- sample(d$mat_son)      # z ile mat_son ilişkisiz
  set.seed(1)
  p <- boot_power(transform(d, mat_son = z), "t_independent", n = 50, reps = 1000, strata = "ozel_ders")
  expect_lt(abs(p$power - .05), .025); expect_equal(p$n_na, 0)
})
```

- [ ] **Step 2: Koş, başarısız olduğunu gör.** Beklenen: FAIL (fonksiyon yok).
- [ ] **Step 3: `estimate_effects` ve `boot_power`'ı yaz.** Test adları paketteki `test` dizgileriyle aynı: `t_independent, t_paired, anova_oneway, prop_two, cor_pearson, chisq_indep, reg_overall, reg_partial`.
- [ ] **Step 4: Testleri koş, geçtiğini gör.**

### Task 3: Ana değerlendirme

**Files:**
- Create: `dev/eval/evaluate.R`
- Output: `docs/eval/2026-11-15-sonuclar.csv`, `docs/eval/2026-11-15-konsol.txt` (`sink`)

**Interfaces:**
- Consumes: Task 1 ve 2. Paket: `plan_study`, `plan_precision`, `sensitivity`, `write_methods`, `simulate_power`; plan alanları `n_per_group`, `n_total`, `groups`; kesinlikte `n_required`.

- [ ] **Step 1: Ana tablo.** Her test için `plan_study(...)` → `n` (`t_independent`, `prop_two`, `anova_oneway` tabakalı: `n_per_group`, gerisi `n_total`) → `boot_power`. CSV sütunları: `test, effect, n_plan, n_evrenden_buyuk, power_boot, mc_se, n_na, durum`. Ek satır: `anova_oneway_dogal` (strata yok, toplam `n_total`). Regresyon satırlarına `print(plan)`'daki DMAR rastgele yordayıcı n'i not olarak eklenir (varsa).
- [ ] **Step 2: Kesinlik.** `plan_precision(p = e$p_gecti, e = .05, N = 500)` → `n_required` satır, **yerine koymadan** 2000 kez çekilir. Wald yarı genişliğinde FPC ile `|p_hat − p| <= .05` oranı ve yarı genişliğin `e`'yi aşma oranı raporlanır. (Kararım: evren 500 satır, bu yüzden tasarımdaki N = 1000 yerine N = 500. Ancak böyle tutarlı olur.)
- [ ] **Step 3: Pilot deneyi** (yalnız `t_independent`, `set.seed(2)`): 500 kez her `ozel_ders` grubundan 15 satır çekilir. Pilot d hesaplanır. d ≤ 0 ise "planlanamaz" sayılır. Kalanlarda `plan_study(effect = d_pilot, effect_basis = "pilot")$n_per_group` alınır, gerçek güç `power.t.test(n, delta = e$d_ind)$power` ile bulunur. Raporlanan değerler: planlanamaz oranı, n medyanı, gerçek güç medyanı, güç < .50 oranı, paketin pilot uyarısı olup olmadığı (`withCallingHandlers` ile yakala).
- [ ] **Step 4: Diğer fonksiyonlar.** Her plan için `sensitivity(plan)`, `write_methods(plan, "tr")`, `write_methods(plan, "en")`, `simulate_power(plan, reps = 10000, seed = 1)$status` çağrılır. Hata veya uyarı olursa kaydedilir.
- [ ] **Step 5: Bilerek hatalı girdiler.** Her biri `tryCatch` ile yakalanır, mesaj kaydedilir: `effect = -0.3` (t), `effect_basis = "observed"`, `prop_two` için `p1 = p2`, `chisq_indep` için `alternative = "one.sided"`, `reg_partial` için `tested = predictors`, `power = 1`, `dropout = 1`. Beklenen: hepsi okunabilir bir hata verir, hiçbiri sessizce n döndürmez.
- [ ] **Step 6: Koş.** `& "D:\R-4.6.1\bin\Rscript.exe" dev/eval/evaluate.R`. Süreyi ölç. Beklenen: CSV'de 10 satır, betik hatasız biter.
- [ ] **Step 7: Paket testleri.** `devtools::test()` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1` koşulur, çıktının özeti kaydedilir. Hata varsa düzeltilmez, rapora yazılır.

### Task 4: Kod okuması ve rapor

**Files:**
- Create: `docs/eval/2026-11-15-rapor.md`

- [ ] **Step 1: Bilimsel okuma.** `R/` altındaki dosyalar şu sorularla okunur: varsayılanlar savunulabilir mi; uyarılar gerçek riski karşılıyor mu (pilot yanlılığı, eşit olmayan gruplar, rastgele yordayıcılar, Yates, Wald kesinliği); yöntem metni yapılmayanı iddia ediyor mu. Her bulguya dosya:satır ve kanıt (Task 3 çıktısı ya da kaynak) yazılır.
- [ ] **Step 2: Raporu yaz.** Bölümler: veri seti özeti (gerçek etki büyüklükleri); ana tablo; kesinlik; pilot deneyi; hatalı girdiler; paket testleri ve check sonucu; çalışmayan yerler; bilimsel kaygılar (ciddiyete göre sıralı); avantajlar; dezavantajlar; sınırlılıklar (sentetik veri, 500 satırlık evren, tek tohum).
- [ ] **Step 3: Bağlamsız inceleme.** Yeni bir ajan yalnız tasarımı, bu planı, `dev/eval/` betiklerini, CSV'yi ve raporu görür. Rapordaki her sayısal iddianın CSV ya da konsol çıktısında karşılığı var mı, kontrol eder. Bootstrap ve etki tanımlarında hata arar. Bulgular düzeltilir ya da rapora "açık" diye yazılır.
- [ ] **Step 4: Kullanıcıya getir.** Kısa Türkçe özet: KALDI/INCELE tablosu, en önemli 3 bulgu, avantaj ve dezavantaj. Konsolda denenecek 2-3 örnek ve bir hatalı girdi verilir.
