# Dilim 10: örnekleme modülü (Cochran, sonlu evren düzeltmesi, kayıp, DEFF) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Önkoşul:** Dilim 1-8 `main`'de (Dilim 9/9b'ye bağlı değil). `dropout` ve `deff` zaten `plan_study()` içinde (Dilim 1'den beri); bu dilim aynı düzeltme sırasını **kesinlik** hesabına getirir ve kaynakla doğrular.

**Goal:** `plan_precision(p, e, conf_level, N, dropout, deff)` tek bir oranı verilen kesinlikle (güven aralığı yarı genişliği) kestirmek için gerekli örneklemi verir: Cochran n0, varsa sonlu evren düzeltmesi, `× deff`, `/ (1 - dropout)`, tek yukarı yuvarlama. Kendi yöntem paragrafını `write_methods()` ile üretir (kullanıcı kararı, 2026-11-14). Kesinlik planı `sensitivity()`'e ya da bir hipotez testi işlevine verilirse okunur hata verir (spec §7 korkuluk tablosu, 3. satır; `write_methods()` bu hatadan muaftır).

**Architecture:** Yeni dosya `R/precision.R`: `plan_precision()`, `print.plansize_precision()`, `write_methods` içindeki sınıf dalı (karar 2, aşağıda). Korkuluk `check_plan()` içinde tek yerde: sınıf `plansize_precision` ise `err_precision_plan`. Cochran formülü kapalı biçimli bir kuramsal formüldür (`pwrss` bu hesabı yapmaz); `stats::qnorm` kullanılır, güç motoru yazılmaz. Doğruluk bağımsız kaynakla (aşağıda) kanıtlanır.

**Tech Stack:** R 4.6.1, testthat 3. Referans: Cochran (1977) formülü, CRAN `cochranSize` paketinin yayımlanmış örnekleri (kurulu değil, değerler vinyetinden), spec §7 örneği.

**Spec:** `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md` (§6 Cochran sabit kıyası, §7 düzeltme sırası ve korkuluk, §8 madde 10)

## Global Constraints

- Rscript yolu: `D:\R-4.6.1\bin\Rscript.exe`. `TEMP`, `TMP`, `TMPDIR` = `D:\rtmp`.
- R kodu ve testler ASCII. Kullanıcı metinleri `msg()` ile, `en` ve `tr` birlikte. CSV UTF-8, BOM yok, virgüllü alan tırnaklı. Her anahtara tam kullandığı kadar argüman geçer.
- Düzeltme sırası: analitik n (varsa sonlu evren), `× deff`, `/ (1 - dropout)`, tek `ceiling()`. Ara yuvarlama yok (cochranSize `n0`'ı önce yuvarlıyor; bu pakette yuvarlanmaz, bkz. Kararlar).
- Mevcut testlerin ve plan nesnelerinin çıktıları değişmez (altın test).
- `devtools::test()` `WARN 0`; `dev\check.ps1` `Status: OK`.
- Dal: `slice-10-precision`. Commit yalnız kullanıcı onayından sonra.

## Doğrulanmış gerçekler (R'da denendi)

Formül (`z = qnorm(1 - (1 - conf)/2)`): `n0 = z^2 p (1 - p) / e^2`; sonlu evrende `n = n0 / (1 + (n0 - 1) / N)`.

**Spec §6 sabit kıyası:** `z = 1.96`, p .5, e .05 → `n0 = 384.16`, 385. `qnorm` ile `z = 1.959964` → 384.1459 (cochranSize vinyeti: `cochran_n(p = 0.5, e = 0.05, conf.level = 0.95)` = 384.1459, birebir).

**Spec §7 düzeltme sırası örneği (N = 1000, e .05, p .5, DEFF 1.5, kayıp %10):**

| Adım | z = 1.96 (spec) | z = qnorm(.975) |
|---|---|---|
| n0 | 384.16 | 384.1459 |
| sonlu evren | 277.7408 | 277.7335 |
| × 1.5 | 416.6112 | 416.6002 |
| / 0.9 | 462.9014 | 462.8891 |
| ceiling | **463** | **463** |

Spec'teki 277,74 / 416,6 / 462,9 / 463 değerleri doğru (z = 1.96 ile). Kaynak: cochranSize vinyeti `cochran_n_adj(384.1459, N = 1000)` = 277.7335 (birebir uyuşuyor). Kaynak doğrulaması **kısmi**: Cochran'ın kitabını (1977) doğrudan okuyamadım; formülün `(n0 - 1) / N` biçimi cochranSize belgesinden, `n0 / (1 + n0 / N)` biçimi kitaptaki yaygın aktarımdan bilinen. Açık soru 1.

cochranSize yayımlanmış örnekleri (n0 ve düzeltilmiş n; bizim hesap, yuvarlama farkı not edildi):
- N 2000, e .05, %95 → n0 385, düzeltilmiş 323 (bizim: 322.3855 → 323).
- N 500, p .3, e .03, %99 → n0 1549, düzeltilmiş 379 (bizim: n0 1548.143, 378.1228 → 379).
- n0 ızgarası (p .5, `ceiling`): %90: e .05 → 271, .03 → 752, .01 → 6764; %95: 385, 1068, 9604; %99: 664, 1844, 16588 (hepsi bizim hesapla birebir).

**Üç farklı "sonlu evren" biçimi** (N 1000, e .05): `(n0 - 1)/N` biçimi 277.73; `n0/(1 + n0/N)` 277.53; Yamane `N / (1 + N e^2)` 285.71 (Israel 1992 tablosundaki 286). Küçük N ve büyük e'de farklar büyür (e .10, N 50: 33.11, 32.88, 33.33; N 20: 16.70, 16.55, 16.67). Bu paket `(n0 - 1)/N` biçimini kullanır (spec 277,74 bunu varsayar, kaynağı cochranSize), metinde adını yazar.

Paket doğruluk kuralı: yalnız aynı formülü kullanan referanslar arasında tolerans geçerlidir: cochranSize ile n'de ±1 (rastgele yuvarlama farkı), farklı biçimlerle fark yöntem notudur (çelişki kuralı), başarısızlık değildir.

## Kararlar (öneri; açık sorulara bak)

- İşlev adı `plan_precision`; sınıf `plansize_precision` (spec §7 korkuluk tablosundaki "plan_precision() çıktısı"). Argümanlar: `p = 0.5` (beklenen oran, (0, 1)), `e` (yarı genişlik, zorunlu), `conf_level = 0.95`, `N = NULL` (evren büyüklüğü, tam sayı ≥ 2; NULL = sonsuz), `dropout = 0`, `deff = 1`.
- Kısıtlar: `e` pozitif ve `e < min(p, 1 - p)` (aksi hâlde Wald aralığı [0, 1] dışına taşar; `err_precision_e`, öneri: hata); `conf_level` (0, 1) açık aralıkta ama 0.5-0.999 (aksi hâlde uyarı değil hata, çünkü anlamsız); `dropout` ve `deff` için mevcut `err_dropout`/`err_deff`.
- Alanlar: `p`, `e`, `conf_level`, `z`, `N`, `n0`, `n_analytic` (sonlu evren sonrası), `n_required` (integer, tek `ceiling`), `dropout`, `deff`, `method = "cochran_wald"`.
- Yuvarlama yalnız sonda. `N` verilmişse ve `n_required > N` ise sınıflı uyarı (`plansize_precision_warning`): kayıp/DEFF sonrası alınacak sayı evreni aşıyor, yani sayım gerekir.
- Kaynaktaki "p = .5 en kötü durum" notu metinde: `p` kullanıcı belirtmediyse (varsayılan .5) metin "en muhafazakâr değer" der; `p` verildiyse `p` dayanağı bir `effect_basis` değildir (yapılandırılmış dayanak eklenmez, açık soru 3).
- `sensitivity()` kesinlik planı kabul etmez (korkuluk). Verilen n ile elde edilen kesinlik için küçük yardımcı `precision_margin(n, p, conf_level, N, dropout, deff)` bu dilimde **yapılmaz** (açık soru 4).
- **Karar (kullanıcı, 2026-11-14):** `write_methods(plan_precision(...))` kendi kesinlik paragrafını yazar; hata yoktur. Spec §7 korkuluk satırı buna göre güncellendi (hata yalnız `sensitivity()` ve hipotez testi işlevlerinde). Ayrı `write_methods_precision` işlevi **yok**: tek `write_methods` sınıfa göre dallanır.
- Yöntem metni (EN/TR) `write_methods` içinde sınıfa göre kolu: gerekçe, formül adı (Cochran 1977, Wald/normal yaklaşım), `p`, `e`, güven düzeyi, `N`, düzeltme sırası, sonuç. Tek oran hipotez testi kapsam dışı olduğu metinde söylenmez (yalnız belge).

## Review Focus

- Spec örneği (463) ve ara değerleri (277.74, 416.6, 462.9) testte `fixed` biçimde sınanır; sıralama yanlışsa (önce kayıp, sonra DEFF, sonra FPC) başka sayı çıkar. Sıra testi bunu yakalamalı: `n0 / 0.9 * 1.5` sonra FPC = 390.5 vs 463.
- `e >= min(p, 1 - p)`, `p = 0`, `p = 1`, `N = 1`, `N = 100.5`, `conf_level = 1` okunur hata verir; `N` çok küçükken (N = 10, e .05) n < N kalır, kayıp sonrası > N ise uyarı.
- `plan_precision()` çıktısı `sensitivity()`, hipotez testi `print`'i ve elle sınıf değişikliği ile `err_precision_plan` verir; hata `plan_study()` önerir; `write_methods()` hariç. `plan_study()` planı da `write_methods`'a hâlâ doğru gider.
- `write_methods(plan_precision(...))` hatasız ve kendi paragrafını yazar; `check_plan` sırası (sınıf dalı önce) yanlışsa bu test kırılır. Spec §7 satırıyla tutarlı.
- Metinde kaynak parantezi yok ama formül adı ve sonlu evren biçimi var; `))` yok.
- Altın dosya değişmez.

---

### Task 1: `plan_precision` ve korkuluk

**Files:**
- Create: `R/precision.R`, `tests/testthat/test-precision.R`
- Modify: `R/validate.R` (`check_plan` sınıf kolu), `R/methods.R` (sınıf kolu, bkz. karar 2), `inst/i18n/messages.csv`, `NAMESPACE` (roxygen), `tests/testthat/test-anova.R` yok, dokunma

**Interfaces:**
- `plan_precision(p = 0.5, e, conf_level = 0.95, N = NULL, dropout = 0, deff = 1)` → `plansize_precision`.
- `print.plansize_precision(x, ...)`.
- `check_plan(x)`: `inherits(x, "plansize_precision")` ise `fail("err_precision_plan")` (genel `err_plan` yerine, önce bu).
- **Sıra kısıtı (`write_methods`, karar 2):** mevcut `write_methods()` ilk iş `check_plan()` çağırıyor. `write_methods` içindeki `plansize_precision` sınıf dalı `check_plan()` çağrısından **önce** gelmelidir; aksi hâlde yeni korkuluk kesinlik planını `write_methods`'ta da reddeder. Testler: `write_methods(plan_precision(e = 0.05))` hatasız metin verir (EN ve TR), `sensitivity(plan_precision(e = 0.05))` `err_precision_plan` verir, `write_methods(plan_study(...))` eskisi gibi çalışır.
- Yeni anahtarlar: `err_precision_plan`, `err_precision_e`, `err_precision_p`, `err_precision_N`, `err_precision_conf`, `warn_precision_N`, `prec_title`, `prec_n`, `prec_p`, `prec_e`, `prec_conf`, `prec_N`, `prec_method`, `m_precision_intro`, `m_precision_result`, `m_precision_adjust_*`.

**CSV (kilit anahtarlar)**

| key | en | tr |
|---|---|---|
| err_precision_plan | This object comes from plan_precision() (precision of one proportion), not from a hypothesis test; use plan_study() for power-based planning. | Bu nesne bir hipotez testinden değil plan_precision() ile tek oranın kesinlik hesabından geliyor; güce dayalı planlama için plan_study() kullanın. |
| err_precision_e | Argument 'e' must be a positive number smaller than both 'p' and 1 - 'p'. | 'e' argümanı hem 'p' hem de 1 - 'p' değerinden küçük pozitif bir sayı olmalı. |
| err_precision_N | Argument 'N' must be a single whole number of at least 2 (or NULL for an unbounded population). | 'N' argümanı en az 2 olan tek bir tam sayı olmalı (sınırsız evren için NULL). |
| warn_precision_N | The sample to recruit exceeds the population size N; a census is needed. | Alınması gereken örneklem evren büyüklüğü N'yi aşıyor; sayım yapılması gerekir. |
| m_precision_result | The sample size for estimating a proportion (expected value %s) with a margin of error of %s at a %s%% confidence level was calculated with Cochran's formula (normal approximation) as %s. | Beklenen değeri %s olan bir oranın %s hata payıyla ve %%%s güven düzeyinde kestirilmesi için gerekli örneklem büyüklüğü, Cochran formülüyle (normal yaklaşım) %s olarak hesaplanmıştır. |

(Diğer anahtarlar aynı kalıpta; Dilim 8'deki üç `m_adjust_*` kalıbı kullanılır, evren cümlesi `N` verilmişse eklenir: `n = n0 / (1 + (n0 - 1) / N)`.)

- [ ] **Step 1: Başarısız testleri yaz (`test-precision.R`)**

Beklenen sayılar yalnız kaynaktan (cochranSize vinyeti, spec); "kendi hesabın" yok. İlk testin tablosu yukarıdaki yayımlanmış değerlerdir.

```r
test_that("precision n matches published Cochran values", {
  n0 <- function(p, e, cl) plan_precision(p = p, e = e, conf_level = cl)$n0
  expect_equal(n0(0.5, 0.05, 0.95), 384.1459, tolerance = 1e-6)          # cochranSize vignette
  grid <- list(c(0.90, 0.05, 271), c(0.90, 0.03, 752), c(0.90, 0.01, 6764),
               c(0.95, 0.05, 385), c(0.95, 0.03, 1068), c(0.95, 0.01, 9604),
               c(0.99, 0.05, 664), c(0.99, 0.03, 1844), c(0.99, 0.01, 16588))
  for (g in grid) expect_identical(ceiling(n0(0.5, g[2], g[1])), g[3])
  expect_identical(plan_precision(e = 0.05, N = 2000)$n_required, 323L)   # cochranSize: 323
  expect_identical(plan_precision(p = 0.3, e = 0.03, conf_level = 0.99, N = 500)$n_required, 379L)
  expect_equal(plan_precision(e = 0.05, N = 1000)$n_analytic, 277.7335, tolerance = 1e-6)
})
test_that("correction order is FPC, then deff, then dropout, one ceiling", {  # spec section 7
  p <- plan_precision(e = 0.05, N = 1000, deff = 1.5, dropout = 0.1)
  expect_identical(p$n_required, 463L)
  expect_equal(p$n_analytic * 1.5, 416.6, tolerance = 1e-3)
  expect_equal(p$n_analytic * 1.5 / 0.9, 462.89, tolerance = 1e-3)
  expect_identical(ceiling(ceiling(p$n_analytic) * 1.5 / 0.9), 464)   # intermediate rounding would give 464
  expect_identical(p$n_required, 463L)                                    # single ceiling at the end gives 463
})
```

Hata ve korkuluk testleri (her biri `fixed = TRUE`, `msg()` ile): `e = 0.5` (p .5), `p = 0`/`1`, `N = 1`/`100.5`, `conf_level = 1`, `deff = 0.9`, `dropout = 1`; `sensitivity(plan_precision(e = 0.05))`, `print`'i bozuk sınıfla, `write_methods(plan_study(...))` hâlâ çalışır; `N = 20, e = 0.05`: kayıp %30 sonrası `n_required > N` için `expect_warning(class = "plansize_precision_warning")`. Metin testi: EN cümle birebir, TR `\u` kaçışlı ASCII, `))` yok.

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test(filter = 'precision')"`
Expected: FAIL (`plan_precision` yok).

- [ ] **Step 3: Kodu, CSV'yi ve belgeyi ekle**

`plan_precision` roxygen: formül, `(n0 - 1)/N` biçiminin adı ve kaynağı, Wald yaklaşımının kenar durum sınırı (p 0'a ya da 1'e yakınsa kötü), p = .5 en muhafazakâr, kesinlik ≠ güç uyarısı.

- [ ] **Step 4: Tüm kapıları çalıştır**

Run: `& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"` ve `powershell -ExecutionPolicy Bypass -File dev\check.ps1`
Expected: `FAIL 0 | WARN 0`, `Status: OK`.

- [ ] **Step 5: Dilim sonu**

Bağlamsız Claude incelemesi, genel inceleme, kullanıcı okuması ve denemesi (kullanıcıya: N .05'ten .03'e inince n neden 3 katı), `docs/devlog.md` girdisi. Commit yalnız istenirse (`feat: add Cochran precision planning`).

## Tahmini boyut

| Dosya | Satır |
|---|---|
| `R/precision.R` (işlev, doğrulama, hesap, print, roxygen ~25) | ~85 |
| `R/validate.R` (`check_plan` kolu) | ~4 |
| `R/methods.R` (sınıf kolu, metin) | ~25 |
| **Kod toplamı** | **~115** |
| `inst/i18n/messages.csv` | ~22 satır (kod sayılmaz) |
| `tests/testthat/test-precision.R` | ~80 (kod sayılmaz) |

150'nin altı. Aşarsa kesim noktası: **10a** (`plan_precision`, `print`, korkuluk), **10b** (yöntem metni). Roxygen çok uzarsa 10b'ye bölmek ilk adaydır.

## Önceki planlarla çelişki / etkileşim

- Spec §8 Dilim 10'u "kayıp payı ve DEFF" olarak da anar, ama Dilim 1'den beri `plan_study()` bunları zaten uyguluyor; bu dilimde yalnız kesinlik tarafına aynı sıra eklenir. `plan_study()`'ye dokunulmaz.
- Dilim 8 plan notu `msg_for_opt("plan_note", ...)`: `plansize_precision` print'i kendi anahtarlarını kullanır, `test_spec` içine **girmez** (kesinlik bir hipotez testi değil; `names(test_spec)` ve `check_choice` listesi değişmez, Dilim 12'deki test seçici etkilenmez).
- `check_plan` sınıf kolu eklenince Dilim 11'deki `simulate_power()` precision nesnesini aynı hata ile reddeder (ücretsiz).

## Açık sorular

1. **Sonlu evren biçimi ve kaynak:** `(n0 - 1)/N` (cochranSize, spec'in 277,74'ü) mi, yoksa Cochran kitabındaki sade `n0/(1 + n0/N)` (277,53) mi? Birincisini öneriyorum; kitabı kendim okuyamadım, `cochranSize` ve spec'e dayanıyor. Doğrudan kaynak (kitap sayfası) sende var mı?
2. **KARAR (kullanıcı, 2026-11-14): `write_methods` ve kesinlik.** `write_methods()` kesinlik planı için kendi yöntem paragrafını yazar; hata yalnız `sensitivity()` ve hipotez testi işlevlerinde. Ayrı `write_methods_precision` yok. Spec §7 korkuluk satırı güncellendi. Plan bu karara göre düzeltildi (Goal, Architecture, Kararlar, Task 1 sıra kısıtı, Review Focus). Artık açık değil.
3. **`p` dayanağı:** `p = .5` varsayımı ya da pilottan gelen p için `effect_basis` benzeri bir alan (ve uyarı) ister misin? Öneri: bu dilimde hayır; metinde "p = .5 en muhafazakâr" cümlesi yeterli.
4. **Kesinlik için duyarlılık:** Verilen n ile elde edilebilecek hata payı (`precision_margin()`) eklensin mi (~15 satır)? Öneri: ayrı küçük iş, bu dilimde yok.
5. **`e` kuralı:** `e >= min(p, 1 - p)` hata mı (öneri) uyarı mı? `cochranSize` ve `samplingbook` (`e < p` önerisi) uyarı düzeyinde.
6. **Ortalama kestirimi** (sürekli değişken için n = z² s² / e²) kapsam dışı mı? Spec yalnız oranı anıyor; kapsam dışı bırakıyorum.
7. **Doğrulama paketi:** `cochranSize` (CRAN'da var) kurulu değil; yayımlanmış sayıları testte sabit değer olarak kullandım. Test dışı bir kez gerçek çağrıyla doğrulamak için kurulmasını ister misin (`lib = "D:/R-4.6.1/library"`)? `samplingbook::sample.size.prop` ikinci bağımsız kaynak olur (aynı biçim mi kontrol edilmeli).
