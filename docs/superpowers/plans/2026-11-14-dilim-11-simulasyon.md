# Dilim 11a: simülasyonla doğrulama (çekirdek + 5 test) - plan

Dal: `slice-11a-simulate` (başlangıç: `main` dae8208). Onay yok, kod yok. Eski taslak güncel koda göre yeniden yazıldı (Dilim 9, 9b, 9c, 10, kaynak parantezi sonrası).

## Amaç

`simulate_power(plan, n = NULL, reps = 10000, seed = NULL)`: planın testini veri üreterek `reps` kez çalıştırır, ampirik gücü `pwrss`'in aynı n için analitik gücüyle karşılaştırır. Spec §6: |ampirik - analitik| <= 0,02 ve ampirik >= hedef - 0,02; reps >= 10000; `skip_on_cran()`. Spec §5: "simülasyon ayrı özellik değil, doğrulama aracıdır" (güç motoru değil). Kapsam: `t_independent`, `t_paired`, `anova_oneway`, `prop_two`, `cor_pearson`. Öteki üçü (`chisq_indep`, `reg_overall`, `reg_partial`) 11b.

## Güncel koda göre doğrulananlar (file:line)

- `test_spec` alanları (`R/tests.R:3-22`, girişler `:66-399`): `directional, groups, min_n, method, prepare, n, mde, effect_lines, info_lines, effect_sentence, variant, check`. **`power` ve `simulate` yok, ikisi de yeni.** Eski taslağın `plan$effect_test` kullanımı doğru: t_independent d, t_paired dz (`:89-`), anova f, prop_two `p1 - p2` (`p1`, `p2` ayrı alan), cor r, chisq w, regresyon (kısmi) R2.
- `R/engine.R`: yalnız `engine_n*` ve `engine_mde*` var (`:15,:28,:41,:54,:63,:70,:77,:84,:92,:100`); güç fonksiyonu yok. Yeni `engine_power_*` yazılacak, sarmalayıcı `guard_pwrss` (`:4`).
- `n` birimi: `plan$n_analytic` grup başına (ANOVA `n.total/k`, `:21`), tek örneklemli testlerde toplam. `plan$n_per_group` kayıp/DEFF sonrası `ceiling` (`R/plan.R:120`). Varsayılan `n = round_up(plan$n_analytic)`: `round_up` `R/validate.R:59`. Eski taslaktaki düz `ceiling` Dilim 10 ders 1'e (kayan nokta) aykırıydı.
- `check_plan` `R/validate.R:62`: kesinlik nesnesini ilk satırda `err_precision_plan` ile reddeder (`:63`); `test` adı, `effect_basis`, `groups`, `alternative`, `spec$check` bakar; **`n_analytic` bakmaz**, bu yüzden elle bozulmuş `n_analytic` için `n` doğrulaması `simulate_power` içinde olmalı.
- `sensitivity` (`R/sensitivity.R:20-39`): `n_effective <- floor(n * (1 - dropout) / deff + 1e-9)` (`:32`) kalıbı; `simulate_power` kayıp/DEFF simüle etmez, notu yazar.
- `R/print.R:7` `print.plansize_plan` `check_plan` çağırır; yeni `print.plansize_simulation` da kendi doğrulayıcısını (`check_simulation`) çağırmalı (Dilim 10 ders 4; `check_precision_plan` `R/validate.R:80` kalıbı).
- i18n: `msg()/msg_for()` `R/i18n.R:17,26`; CSV 211 satır, her anahtar en+tr (test-i18n.R). Altın test (`helper-golden.R`, `test-golden.R`) yalnız plan/print/sens/methods/hata çıktısına bakar: `test_spec`'e alan eklemek ve yeni anahtar eklemek altın dosyayı **kırmaz**. `golden_strip_tests` yalnız `err_choice` metnini ayıklar, dokunma.
- `pwrss` `stats::power.t.test`'i **maskeler** (pwrss yüklenince `power.t.test(...)` pwrss'in olur). Testlerde her zaman `stats::power.t.test`. Pakette `pwrss::` önekli çağrı.

## Kararlar

- Dönüş: sınıf `plansize_simulation` listesi: `test, n, reps, seed, power_sim, mc_se, ci, power_analytic, diff, target, status, pass, notes`. `mc_se = sqrt(p(1-p)/reps)`; `ci = power_sim +/- 1.96 * mc_se`.
- `pass = abs(diff) <= 0.02 && power_sim >= plan$power - 0.02` (spec §6). Toleransı genişletme yok. `reps` tam sayı ve >= 100 değilse hata (`err_reps`); `reps < 10000` iken spec şartı sağlanmadığı için **`pass = NA`** ve not ("spec en az 10000 tekrar ister; sapma gürültü olabilir"); `diff` ve `ci` yine verilir.
- **`status` (kullanıcı kararı, 2026-11-14):** `"pass"` (spec kuralı sağlandı), `"warn"` (ampirik güç analitikten 0.02'den fazla YÜKSEK ve hedef - 0.02'nin üstünde: plan güvenli, analitik formül bu n'de muhafazakâr bir yaklaşım; örn. cor r .8 n 10), `"fail"` (diğer her durum), `reps < 10000` iken `NA`. `pass` spec kuralı olarak kalır (`status == "pass"`). `print` `"warn"` için FAIL değil sınıflı olmayan bir uyarı satırı (`sim_warn`) gösterir: "Simülasyon gücü formülden yüksek; plan hedefi karşılıyor, fark formülün küçük n'deki yaklaşımından geliyor; yöntem notuna yazılabilir." Tolerans genişlemez: `warn` yalnız güvenli yönde.
- Tohum: `seed` verilirse `.Random.seed` kaydedilir, çıkışta geri yüklenir (yoksa silinir). `seed = NULL` iken işlev kullanıcının RNG'sini her rastgele R işlevi gibi ilerletir; yardım sayfası bunu söyler. Kod `base`, `withr` yalnız testte.
- `pass = FALSE` çıktısı öğrenciye ne yapacağını söyler: "10000 tekrarla yeniden dene; sürerse n küçük olabilir, yaklaşımın sınırı, yöntem notuna yaz; toleransı büyütme."
- Veri üretimi (standart normal / Bernoulli; ek parametre yok): t_ind `x~N(0,1), y~N(d,1)`, `t.test(var.equal=TRUE)`; t_paired `y = d + r*x + sqrt(1-r^2)*e` (d = fark / tek ölçüm SD, `messages.csv` içindeki `m_effect` tanımı ile uyumlu; `tests.R` yalnız `msg_for` çağırır), `paired=TRUE`; anova eşit aralıklı ortalamalar, `sqrt(mean((mu-mean(mu))^2)) = f`, F testi `oneway.test(var.equal=TRUE)` (p değeri `anova(lm)` ile aynı, R'da `all.equal` TRUE); prop_two `rbinom` + `prop.test(correct=FALSE)`, yön `p1 > p2 ? "greater" : "less"`; cor `y = rho*x + sqrt(1-rho^2)*e`, `cor.test`, yön işarete göre.
- `engine_power_cor` `abs(rho)` ile çağırır (`engine_n_cor` gibi, `R/engine.R:63`); R'da doğrulandı: pwrss rho = -.3 ve +.3 için aynı gücü verir (.8025 tek yönlü, n 68).

## Sayılar (R'da çalıştırıldı, 10.000 tekrar, tohum 11, n = round_up(n_analytic); ön deneme kodu, uygulama farklı çekiş sırası verir)

| Vaka | n | ampirik | pwrss | bağımsız referans | fark |
|---|---|---|---|---|---|
| t_ind d .5 iki yönlü | 64 | .8052 | .8015 | `stats::power.t.test` .8015 | .004 |
| t_ind d .5 tek yönlü | 51 | .8080 | .8059 | `stats::power.t.test` .8059 | .002 |
| t_paired d .5 r .5 (dz .5) | 34 | .8008 | .8078 | `stats::power.t.test(type="paired")` .8078 | -.007 |
| t_paired d .5 r -.3 (dz .31) | 84 | .7983 | .8021 | `stats::power.t.test(type="paired")` .8021 | -.004 |
| t_paired d .4 r .7 (dz .52) | 32 | .8099 | .8078 | `stats::power.t.test(type="paired")` .8078 | .002 |
| anova f .25 k 3 | 53 | .8018 | .8049 | `pwr::pwr.anova.test` .8049 | -.003 |
| prop .45/.30 | 163 | .8006 | .8016 | `stats::power.prop.test` .8016 | -.001 |
| prop .10/.05 tek yönlü | 343 | .8113 | .8009 | `stats::power.prop.test` .8009 | **.010** |
| prop .05/.10 tek yönlü (p1<p2) | 343 | .8051 | .8009 | `stats::power.prop.test` .8009 | .004 (gürültü; denetçi 1e5 tekrar: .8103) |
| cor r .3 | 85 | .8010 | .8003 | `pwr::pwr.r.test` .8044 (farklı yöntem: düzeltmeli) | .001 |
| cor r -.3 tek yönlü | 68 | .8099 | .8025 | `pwr::pwr.r.test` .8077 (farklı yöntem) | .007 |

Monte Carlo SE: .80 gücünde 10.000 tekrarda 0,0040 (tolerans 0,02 = 5 SE; yanlış ret ~6e-7), 2.000'de 0,0089 (2,2 SE, ~%3), 1.000'de 0,0126 (1,6 SE, ~%11). Not: prop .10/.05 tek yönlü fark gerçektir (benim koşularım +.010 ve +.014; denetçi 1e5 tekrar: .8106 p1>p2, .8103 p1<p2, pwrss .8009; benim 1e5 koşum yok). Neden ayrık veri / normal yaklaşım olarak yorumlanıyor, **doğrulanmadı**; uygulamada kod yorumu olarak yazılır. 10.000 tekrarda .02 sınırına ~2,6 SE pay var: **risk**; uygulamadan sonra vaka yeniden koşulur, sınır aşılırsa dur ve getir.
Bilinen kenar (testlenmez, bkz. açık soru 2): cor r .8 n 10: ampirik .8637, pwrss .8281 (fark **.036 > .02**), `pwr` .8541; denetçi r .5 n 30'da 1e5 tekrar .8263 / pwrss .8144 (.012, doğrulanmadı). Bağımsız t d 1.5 n 9: ampirik .8501, pwrss .8476, `stats::power.t.test` .8476 (spec'in "9, yaklaşık .85" örneği doğrulandı).

Süre (tek çalışma, 10.000 tekrar): t testleri 0,6-1,0 s, prop 0,8 s, cor 0,7 s, ANOVA `anova(lm)` 12 s, `oneway.test` 8 s. 11 vaka yaklaşık 25 s. `skip_on_cran` testleri `dev\check.ps1` ve `R CMD check` altında atlanır (NOT_CRAN ayarlı değil, denetçi doğruladı); yalnız `devtools::test()` koşturur. **Simülasyon testlerinin kapısı `devtools::test()`'tir**, `check.ps1` onları sınamaz.

## Dosyalar

- Yeni: `R/simulate.R`, `tests/testthat/test-simulate.R`.
- Değişen: `R/tests.R` (beş girişe `power`, `simulate`; başlık yorumu `:3-22` güncellenir), `R/engine.R` (`engine_power_t/_anova/_props/_cor`), `inst/i18n/messages.csv`, `NAMESPACE` (roxygen), `R/validate.R` (`check_simulation`).

## Arayüzler

- Yeni: `simulate_power`, `print.plansize_simulation`, `check_simulation(x)`, `test_spec$<test>$power(n, plan)`, `test_spec$<test>$simulate(n, plan)` (p değeri üreten `function()` döner), `engine_power_t(n, d, alpha, alternative, design)`, `engine_power_anova(n, k, f, alpha)`, `engine_power_props(n, p1, p2, alpha, alternative)`, `engine_power_cor(n, rho, alpha, alternative)`.
- Mevcut: `check_plan`, `round_up`, `fail`, `msg`, `msg_for`, `fmt_plain`, `fmt_prob`, `guard_pwrss`. `check_plan` kolu kesinlik planını zaten reddeder, ek kod yok.
- `simulate` alanı olmayan test (chisq, reg_*) için `err_sim_unsupported` (okunur hata, `NULL is not a function` değil); 11b alanı ekleyince kalkar.

## CSV anahtarları (en+tr, her biri tam kullandığı kadar argüman)

`sim_title, sim_n, sim_reps, sim_power, sim_analytic, sim_diff, sim_target, sim_pass, sim_fail, sim_warn, sim_note_adjust, sim_note_reps, err_reps, err_sim_n, err_sim_seed, err_sim_unsupported, err_sim_obj`. Test adı için mevcut `val_<test>` kullanılır. Mevcut `err_precision_plan`, `err_plan` yeniden kullanılır.

## Testler (önce yazılır, hepsi başarısız görülür)

1. Analitik güç bağımsız referansla (hızlı, atlanmaz): t_ind 64 ve tek yönlü 51 `stats::power.t.test`; paired 34, 84 (r -.3), 32 (r .7); props 163 `stats::power.prop.test`; anova 53 `pwr::pwr.anova.test`; cor 85 `pwr::pwr.r.test`, tolerans 0,01 (farklı yöntem, nedeni yorumda).
2. `skip_on_cran`: 11 vaka (tablodaki; d/dz karışıklığını yakalamak için r .5 dışı iki eşli vaka dahil), `reps = 10000, seed = 11`; `abs(diff) <= 0.02`, `power_sim >= hedef - 0.02`, `pass`. Tolerans genişletilmez; aşılırsa dur.
3. Aynı `seed` aynı sonuç; `seed` verilince `.Random.seed` önce/sonra aynı (`seed` önceden yokken de; `reps = 200`); `seed = NULL` iken sonuç `pass = NA` (reps < 10000) ve RNG ilerler (belgelenen davranış).
4. Hatalar en+tr: `reps = 10`, `reps = 99`, `n = 0/1.5/NA`, `seed = "a"`, kesinlik planı, elle bozulmuş plan, chisq planı (`err_sim_unsupported`).
5. Kayıplı/DEFF'li plan: `n == round_up(n_analytic)`, `notes` dolu.
6. `print` en+tr (`Empirical power` / Türkçe karşılığı), simüle edilen n'yi ve kayıp/DEFF'li planda neden `n_per_group`'tan farklı olduğunu söyler, "gözlenen güç değildir" cümlesi, `OutDec = ","` iken noktalı sayı, elle bozulmuş `plansize_simulation` için `err_sim_obj`.
7. `status` sınıflaması `simulate_power` çıktısı üzerinde değil, sabit sayılarla iç `sim_status()` yardımcısında sınanır: (analitik .80, ampirik .80, hedef .80) "pass"; (.8281, .8637, .80) "warn"; (.80, .75, .80) "fail"; (.80, .85, .90) "fail" (hedefin altında); reps 9999 -> NA. `skip_on_cran` altında cor r .8 n 10 `status == "warn"` (karar 2; kötü davranışı dondurmaz, doğru sınıflamayı sınar).
8. `power` ve `simulate` yalnız beş testte tanımlı (11b'ye iz).

## Boyut

`R/simulate.R` ~60 (döngü, tohum, özet, print, doğrulayıcı, roxygen), `R/tests.R` ~35, `R/engine.R` ~20, `R/validate.R` ~8: **~125 satır**, 150 altında. Aşarsa bölme noktası: 11a-1 = çekirdek + t_independent + t_paired (~80), 11a-2 = anova + prop_two + cor (~45). Test dosyası ~90 ve CSV ~16 satır kod sayılmaz.

## İnceleme odağı (Dilim 10 dersleri)

- Plandaki her sayı uygulamada yeniden çalıştırılır; yukarıdaki ön deneme çekişi farklıdır, prop .10/.05 farkı .02'ye yaklaşabilir (altın dosya değil, test eşiği riski).
- Kayan nokta: `round_up`, `ceiling` değil; `n_analytic` tam sayıya çok yakınken (prop_two) n bir artmamalı.
- Öğrenci metni: `pass = FALSE` mesajı "ne yap" der; ampirik/analitik sözcükleri tek cümleyle açıklanır; "simülasyon doğrulaması gerçek veriyi değil, formülün bu n'de tuttuğunu sınar" (varsayım: normal veri, etki doğru) ve "bu gözlenen güç değildir" (gözlenen güç isteği reddedilir, spec §4).
- Yardım sayfası tuzakları: `n` birimi (grup başı / toplam, kayıp sonrası değil), `reps` küçükse `pass` gürültü, `seed` kullanıcının RNG'sini bozmaz, `stats::power.t.test` maskeleme (belge değil test notu).
- Elle bozulmuş nesne: hem plan (`check_plan` + `n_analytic`) hem `plansize_simulation` doğrulanır; `print` doğrulayıcıdan geçer.
- Her test için `power` ile `simulate` aynı varsayımı kullanır (tek yönlü işaret, `p1 < p2`, negatif r).

## 11b için güncel koddan doğan değişiklikler (11b yeniden yazılmıyor)

- `reg_partial` artık `main`'de (`R/tests.R:335`): alanlar `predictors, tested, effect_type ("r2_change"|"f2"), r2_covariates (f2'de NA), effect_test` = kısmi R2. 11b'nin "9b gerek" önkoşulu sağlandı; 11b taslağındaki `reg_partial` ΔR2/kovaryat türetimi alanlara uyuyor. Taslaktaki ölçeklenmiş `pwr.f2.test` formülü (`f2 * n / (n - k + u)`) yeniden doğrulanmadı; 9b ile karşılaştır.
- Dilim 9c: `random_predictor_n()` (`R/random_predictors.R:12`) DMAR ile rastgele yordayıcı n verir ve `print` bu satırı gösterir. 11b `predictors = "random"` modu bunu bağımsız kanıt olarak kullanabilir (DMAR n'sinde rastgele-X simülasyon gücü hedefte mi). Bu 11b'nin "yalnız bilgi" kararını değiştirebilir: `pass` hesaplanabilir (açık soru 5).
- `chisq_indep` planı `rows, cols, df` taşır (`R/tests.R:239`); `n_analytic` 132,61, `n_per_group` = `n_total` = 133; `pwrss` gücü .8013, `pwr.chisq.test` .8013 (R'da doğrulandı). `reg_overall` 77'de `pwrss` .8001 (doğrulandı).
- 11b `simulate(n, plan, predictors)` üçüncü argüman ekler; 11a imzası `(n, plan)` kalır, 11b `simulate_power`'a `predictors` ekler. `err_sim_unsupported` 11b'de beş/üç testten kalkar. 11b'nin `w_max` ve tablo üreticisi bu çalışmada **doğrulanmadı**.

## Açık sorular (kullanıcıya)

1. **Kesinlik planı:** `simulate_power(plan_precision(e = .05))` öneri: **hata** (`check_plan`, ek kod yok; spec §6 "planlanan test" der, kesinlik planının testi yok). Alternatif: ayrı kapsama simülasyonu (kesinlik yarı-genişliğinde |p_hat - p| <= e olasılığı, p .5 n 385'te R'da 0,9475, hedef .95); bu başka bir işlev ve dilim olur. Spec bunu belirlemiyor; karar sizin.
2. **KARAR (kullanıcı, 2026-11-14) cor küçük n (r .8 n 10 fark .036; r .5 n 30 fark ~.012):** güvenli yöndeki sapma `status = "warn"` olur, FAIL gösterilmez (bkz. Dönüş). Yardım sayfasına r .8 n 10 örneği yazılır. Kalan sorular (1, 3-6) önerildiği gibi kabul edildi.
3. **Kayıp/DEFF:** Öneri: yalnız not. Gerekçe: MCAR kayıp beklenen etkin n'e denktir, DEFF simüle edilemez; ~8 satır ve yanıltıcı güven.
4. **ANOVA hızı:** Öneri `oneway.test` (8 s, `anova(lm)` ile aynı p). Gerekçe: aynı F testi, 4 s kazanç, sadakat kaybı yok.
5. **Ad ve dönüş:** Öneri `simulate_power()`, `pass` mantıksal (`reps < 10000` iken `NA` + not). Gerekçe: ad ne yaptığını söyler; spec 10000 şartını `pass`'e bağlamak dürüst.
6. **Kapı:** Öneri: simülasyon testlerinin kapısı `devtools::test()`; yayından önce ek tam koşu gerekmez. Gerekçe: `check.ps1` onları atlar, bu bilinir ve dilim raporuna yazılır.

## Araştırma sonrası ekler (2026-11-14, `docs/research/2026-11-14-dilim-11-dogrulama.md`)

- **prop .10/.05 tek yönlü farkı gürültü değil, binom ayrıklığı.** pwrss pooled formülü `prop.test(correct = FALSE)` z testinin asimptotik gücü; tam binom sayımıyla n 343'te güç .8095 (pwrss .8009, +.009). Tablodaki "gürültü" ifadesi kalkar. Kod yorumu: `# pwrss gives asymptotic pooled-z power; exact binomial power is .8095 here, the gap is discreteness`. Küçük p'de fark büyür (.05/.01 +.026 ile +.045), p ~ .5'te en çok -.006: yanlış FAIL yok, pozitif aşım `warn`'a düşer.
- **Yeni `warn` vakası (skip_on_cran):** prop .05/.01 tek yönlü, n 224: pwrss .8002, tam binom .8365 -> `status == "warn"`.
- **cor Fisher z her zaman muhafazakâr.** Plan n'lerinde 32 durumda pwrss tam güçten düşük (en kötü -1e-5, işaret etkisiz); analitik > gerçek yok. Fark .02'yi iki yönlü r >= .6 (n 20: +.020), tek yönlü r >= .5-.6'da aşar; r .8 n 10: +.041. `sim_status()` yanında yorum: `# Fisher z power is conservative for cor_pearson; empirical above analytic is expected at large r`.
- **Yeni `pass` vakası (skip_on_cran):** cor r .5 n 30 iki yönlü: tam .8277, pwrss .8144 (+.013) -> `status == "pass"`. Kenara yakın; düşerse dur ve getir.
- **Yardım sayfası:** iki yönlü r >= .6 ya da tek yönlü r >= .5'te `warn` beklenir; küçük p'li iki oranda da (ör. .05/.01).
- Denetçinin 1e5 sayıları doğrulandı (.8106/.8103, .8263); tam değerlerin ~1 SE içinde.
- 11b: `make_table`, `w_max` ve `f2 * n / (n - k + u)` ölçeklemesi doğru; `min(P) > 0` kontrolü şart; 3x3'te w .7 simüle edilemez, `err_sim_table` metni bunu söylemeli (11b planına taşınır).
