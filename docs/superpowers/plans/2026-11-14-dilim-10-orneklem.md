# Dilim 10: örnekleme modülü (Cochran kesinliği, sonlu evren, kayıp, DEFF) - plan

Dal: `slice-10-precision`. Onaydan önce kod yok. Commit yalnız kullanıcı isteyince. Sıra: testler, kod, bağımsız inceleme, `devtools::test()` + `dev\check.ps1`, Türkçe anlatım, 2-3 deneme + bilerek hatalı girdi, anlama sorusu, `main`, devlog.

## Amaç

`plan_precision(p, e, conf_level, N, dropout, deff)` tek bir oranı güven aralığı yarı genişliği `e` ile kestirmek için gereken örneklemi verir. Sıra (spec §7): n0 (Cochran), varsa sonlu evren düzeltmesi, `x deff`, `/ (1 - dropout)`, tek `ceiling()`. `write_methods()` kesinlik planı için kendi paragrafını yazar (kullanıcı kararı, 2026-11-14; ayrı `write_methods_precision` yok). `sensitivity()` kesinlik planını okunur hatayla reddeder (spec §7 korkuluk satırı, zaten bu karara göre güncel). Güç motoru yazılmaz; `pwrss` bu hesabı yapmaz, kapalı formül `stats::qnorm` ile kurulur. `plan_study()` zaten kayıp ve DEFF uyguluyor (R/plan.R:121); bu dilim yalnız kesinlik tarafını ekler.

## Dokunulan dosyalar (güncel koda göre)

- Yeni: `R/precision.R`, `tests/testthat/test-precision.R`.
- `R/validate.R`: `check_plan` (satır 52) en başına yeni kol: `inherits(x, "plansize_precision")` ise `fail("err_precision_plan")`, mevcut `inherits(x, "plansize_plan")` denetiminden ÖNCE. Sınıfı elle bozulmuş (ne plansize_precision ne plansize_plan) nesne eskisi gibi `err_plan` alır. `check_adjust(dropout, deff)` yeni yardımcı (R/plan.R:115-116'daki iki satır şimdilik satır içi; `fail("err_dropout", "dropout")` kalıbı) ve `round_up(x) = ceiling(x - 1e-9)` (kayan nokta payı, R/sensitivity.R:32'deki `+ 1e-9` ile aynı amaç: 400 * 1.1 = 440.00000000000006 yanlışlıkla 441 olmasın).
- `R/plan.R`: yalnız o iki satırı `check_adjust()` çağrısına çevir (davranış ve mesajlar aynı; altın dosya değişmez).
- `R/methods.R`: `write_methods` (satır 23-25) içinde `check_plan(plan)` (satır 25) çağrısından ÖNCE 3 satır: `if (inherits(plan, "plansize_precision")) return(methods_precision(plan, lang))`. `@param plan` açıklaması kesinlik planını da anar (yardım sayfası karışıklığı dersi: Dilim 3, 9, 9b).
- `R/sensitivity.R`: yalnız roxygen `@param plan` cümlesi (kesinlik planı hata verir). Kod değişmez: satır 22'deki `check_plan(plan)` yeni koldan `err_precision_plan` verir.
- `tests/testthat/helper-plan.R`: `paren_depth` buraya taşınır (şimdi `test-source-parens.R` içinde, dosyalar arası paylaşılmaz).
- `inst/i18n/messages.csv`, `NAMESPACE` ve `man/` (`devtools::document()`).
- Dokunulmaz: `R/tests.R` (`test_spec` tablosuna girmez; kesinlik hipotez testi değil), `R/print.R` (print yöntemi `precision.R`'de), altın dosya ve `helper-golden.R`.

## Arayüzler

| Ad | Durum |
|---|---|
| `plan_precision(p = 0.5, e, conf_level = 0.95, N = NULL, dropout = 0, deff = 1)` -> `plansize_precision` (alanlar: `p, e, conf_level, z, N, n0, n_analytic, n_required` (integer), `dropout, deff, method = "cochran_wald"`) | yeni |
| `print.plansize_precision`, `methods_precision(plan, lang)` (iç) | yeni |
| `check_adjust(dropout, deff)` | yeni (iç) |
| `check_plan`, `write_methods`, `sensitivity`, `fail`, `msg`, `msg_for`, `fmt_plain`, `fmt_prob`, `check_probability` (validate.R:15), `check_positive_number`, `is_num1` | var |
| Sınıf `c("plansize_precision")`; `plansize_plan` kalıtmaz (kalıtırsa `check_plan` ve `print.plansize_plan` yanlış dala girer) | karar |

Kurallar: `p` ve `conf_level` için `check_probability`; `e` için `check_positive_number`, ek olarak `e < min(p, 1 - p)` (yeni `err_precision_e`); `N` NULL ya da tam sayı >= 2 (`err_precision_N`); `n_required` tam sayı sınırını aşarsa yeni `err_precision_big` (R/plan.R:122 kalıbı; `err_overflow` kullanılmaz, karar 10). `N` verilmiş ve `n_required > N` ise sınıflı uyarı `plansize_precision_warning` (`warn_precision_N`). Kesinlik planında `effect_source` ve `effect_basis` yok (karar 3).

## CSV anahtarları (hepsi yeni; `msg(key, ...)` tam kullandığı kadar argüman alır)

- Hata/uyarı: `err_precision_plan` (sensitivity/hipotez işlevi için, `plan_study()` önerir; argüman yok), `err_precision_e`, `err_precision_N` (argüman adı `%s`), `err_precision_big`, `warn_precision_N`. `p`, `conf_level`, `dropout`, `deff` için mevcut `err_probability`, `err_dropout`, `err_deff`.
- Print: `prec_title`, `prec_n`, `prec_p`, `prec_e`, `prec_conf`, `prec_N`, `prec_method`; dropout ve deff için mevcut `plan_dropout`, `plan_deff` (print.R:21-22 kalıbı).
- Yöntem metni: `m_precision_intro` (pwrss'siz: plansize sürümü), `m_precision_result` (p, e, güven %, n), `m_precision_fpc` (yalnız `N` verilmişse; formül adı), `m_precision_adjust_dropout|deff|both` (m_adjust_* kalıbı, "grup başına" yok).
- Çift parantez dersi: `m_precision_*` metinlerinde parantez içinde parantez yok, derinlik <= 1. Kesinlik planında `effect_source` olmadığı için `chartr("()", "[]")` yolu gerekmez; ileride `effect_source` eklenirse methods.R:29'daki aynı dönüşüm zorunlu.
- CSV: UTF-8, BOM yok, virgüllü alan tırnaklı. Türkçe metin yalnız CSV'de, R kodu ASCII. Devlog'u Edit ile yaz (kabuk tırnağı dersi).

## Testler (önce yazılır, `test-precision.R`)

1. `n0` ve n tablo değerleri (aşağıdaki doğrulama tablosu): 9 hücreli n0 ızgarası, N 2000 -> 323, N 500 p .3 e .03 %99 -> 379, spec 384.16/385.
2. Düzeltme sırası: N 1000, deff 1.5, kayıp .1 -> 463; ara değerler 277.73, 416.60, 462.89; iki yanlış sıra: (a) kayıp ve deff önce, sonra FPC 390.57; (b) deff, FPC, sonra kayıp (deff-önce sırası) 365.80, 406.45, 407; ara yuvarlama 464 (`ceiling(ceiling(a) * 1.5 / .9)`). Sıranın kaynağı yalnız spec §7 (karar 9).
   `round_up()`: `expect_identical(round_up(400 * 1.1), 440)` (çıplak `ceiling(400 * 1.1)` 441 verir; `qnorm` ile z = 2 verilemez, kayan nokta durumu yardımcıyla sınanır; z = 2 için n0 = 399.99999999999994).
3. Hatalar (`msg()` ile, ayrıca `plansize.lang = "tr"`): `e = 0.5`, `p = 0`, `p = 1`, `N = 1`, `N = 100.5`, `conf_level = 1`, `deff = 0.9`, `dropout = 1`, `e` eksik (`err_missing`), `e = 1e-7` (taşma).
4. Uyarı: `N = 20, e = .05, dropout = .3` -> n_required 28 > 20, `expect_warning(class = "plansize_precision_warning")`; `N = 20` kayıpsız (19.06 -> 20) uyarı yok.
5. Korkuluk: `sensitivity(plan_precision(e = .05))` `err_precision_plan`; elle sınıfı bozulmuş nesne (ne `plansize_precision` ne `plansize_plan`) `err_plan`; `sensitivity(plan_study(...))` eskisi gibi; hata metni `plan_study()` içerir.
6. `write_methods(plan_precision(e = .05, N = 1000, deff = 1.5, dropout = .1))` hatasız, EN ve TR (TR için `\u` kaçışı), sayılar 463 ve kayıp oranı içerir (EN `10%`, TR `%10`); `write_methods(plan_study(...))` değişmez; `paren_depth <= 1` (yardımcı `test-source-parens.R` içinde, dosyalar arası paylaşılmaz: `helper-plan.R`'a taşı); formül adı metinde, `))` yok.
7. `print` EN/TR çıktısı ve `options(OutDec = ",")` altında sayı biçimi (`fmt_plain` kullanımı, methods.R:6 kalıbı).
8. `devtools::test()` altın testleri (`test-golden.R`) dokunulmadan geçer; `golden_errors()` listesine kesinlik eklenmez (dosya yeniden üretilmez).

## Sayı doğrulaması (R 4.6.1'de çalıştırıldı, 2026-11-14)

Formül: `z = qnorm(1 - (1 - conf)/2)`; `n0 = z^2 p (1 - p) / e^2`; `n = n0 / (1 + (n0 - 1)/N)`.

| Beklenen değer | Kaynak | Durum |
|---|---|---|
| z 1.96, p .5, e .05: n0 384.16, tavan 385; N 1000, DEFF 1.5, kayıp %10: 277.74, 416.6, 462.9, 463 | spec §6, §7 | spec sayıları z = 1.96 ile yeniden hesaplandı: 384.16, 277.7408, 416.6112, 462.9014 (spec'le uyuşur). `qnorm` ile 384.1459, 277.7335, 416.6002, 462.8891, hepsi 463. Spec'in kendi dayanağı bu hesabın aynısı, bağımsız yöntem değil |
| n0 ızgarası (%90/95/99 x e .05/.03/.01, p .5): 271, 752, 6764; 385, 1068, 9604; 664, 1844, 16588 | R'da qnorm formülü ile yeniden üretildi | Yalnız formülün kendisi; bağımsız paket yok. Izgara vinyette ayrıca kontrol edilmedi; testte yalnız formül tutarlılığı olarak kalır |
| N 1000 -> 277.7335; N 2000 -> 322.39 (323); N 500 p .3 e .03 %99 -> n0 1548.14, 378.12 (379) | `cochranSize` 0.1.0 belge ve vinyeti (araştırma raporu, ağdan) | Doğrulandı; paket kurulmadı |
| z^2 p q / e^2 tutarlılığı | `z * sqrt(p q / n0)` = .05 | yalnız geri-dönüş kontrolü, kaynak değil |

Bulgu (eski taslakta yoktu): "sonlu evren" formülü kaynağa göre değişiyor, N 1000, e .05, p .5 için: (A) `n0/(1 + (n0 - 1)/N)` 277.73 (spec'in 277,74'ü); (B) `n0/(1 + n0/N)` 277.53; (C) Yamane `N/(1 + N e^2)` 285.71. Spec örneği (463) A ve B ile çıkar. Seçim A. Bağımsız türetme: n, kestiricinin GERÇEK varyansından gelmeli, `(N - n)/(N - 1) * PQ / n = (e/z)^2`; kökü tam A (uniroot 277.73345, A ile aynı). Kestiriciyi hedef yapan `(1 - n/N) pq/(n - 1)` biçimi plana girmez. Simülasyon (iadesiz, N 1000, 500 bir/500 sıfır, 4e5 tekrar, tohum 1 ve 2): n 278 için SD .02550 ve .02549, hedef e/z = .02551; n 277 için .02557 ve .02552. Monte Carlo SE ~3e-5, simülasyon tek başına 277 ile 278'i ayıramaz; kesin kanıt analitik varyans (277: .025557 > hedef, 278: .025494 < hedef). Kitap kaynağı elle okunmadı. Bağımsız ikinci paket yok (`cochranSize`, `samplingbook` kurulu değil; `pwr`, `pwrss` bu hesabı yapmıyor). Tolerans kuralı (±1) farklı biçimler arasında geçmez: fark yöntem notudur, başarısızlık değil.

## Boyut tahmini

`R/precision.R` ~90 (hesap+doğrulama ~35, print ~15, `methods_precision` ~20, roxygen ayrı ~25 sayılmazsa), `validate.R` ~8, `plan.R` 0 net, `methods.R` ~3: toplam ~105-120, hedef 150'nin altı. CSV ~20 satır ve testler ~90 satır kod sayılmaz. Kesim noktası: 10a = `plan_precision` + `print` + korkuluk + `check_adjust`; 10b = `methods_precision` + CSV yöntem anahtarları. Roxygen ya da yöntem metni uzarsa 10b'ye böl.

## Risk ve inceleme odağı

- Sıra: FPC, deff, kayıp, tek `round_up` (ceiling - 1e-9); testte yanlış sıra ve ara yuvarlama ayrı ayrı yakalanır.
- `write_methods` kolu `check_plan`'dan önce olmazsa kesinlik planı reddedilir (test 6).
- Altın dosya: `check_adjust` çıkarımı `err_dropout`/`err_deff` mesajlarını değiştirmemeli (devlog 9: plan altın dosyayı kırdı, öngörmedi). Önce `devtools::test(filter = "golden")` çalıştır; kırılırsa dosyaya dokunma, dur ve sor.
- Yardım sayfası: `p = .5` en muhafazakar değer; Wald/normal yaklaşım p 0 ya da 1'e yakınken ve küçük n'de zayıf; `e` yarı genişlik, tam genişlik değil (öğrenci tuzağı); kesinlik güç değildir.
- Wald kapsama zayıflığı (R'da `dbinom` toplamıyla hesaplandı): gerçek kapsama p .1, n 139 için .933; p .02, n 31 için .465 (hedef .95). Yardım sayfasında yazılı; simülasyon Dilim 13b açık sorusunda.
- Bağlamsız inceleme ajanı yalnız belge ve diff'i görür: sayıların kaynak tablosu bu plandan okunur, ajan formülü kendi hesabıyla "doğrulamasın".

## Kararlar (kullanıcı, 2026-11-14)

Dayanak: `docs/research/2026-11-14-dilim-10-kararlar.md`.

1. **Sonlu evren biçimi:** A `n0/(1 + (n0 - 1)/N)`. Dayanak: gerçek varyansın kökü, spec 277,74, `cochranSize` 0.1.0 belgesi ve vinyeti A'yı kullanıyor (277.7335, 323, 379; araştırma raporunda ağdan okundu). `samplingbook::sample.size.prop` B kullanıyor; yardım sayfası iki biçimin en çok 1 kişi ayrıştığını yazar. Cochran (1977) sayfası okunmadı.
2. **Doğrulama paketi:** kurulmaz. Beklenen sayılar `cochranSize` vinyetinden (sabit değer, kaynak yorumuyla).
3. **`p` dayanağı:** ayrı alan yok; yalnız `p = .5` en muhafazakâr notu. `effect_source` yok.
4. **`precision_margin()`:** bu dilimde yok.
5. **`e` sınırı:** `e >= min(p, 1 - p)` hata (`err_precision_e`). `samplingbook` da `stop` veriyor.
6. **Ortalama kestirimi:** kapsam dışı.
7. **`check_adjust`:** `plan.R`'dan çıkarılır. Önce `devtools::test(filter = "golden")`; kırılırsa dur ve sor.
8. **Hesap motoru kuralı:** istisna. `pwrss` 1.3.3'te kesinlik işlevi yok; kapalı Cochran formülü elle yazılır, beklenen değerler kaynaktan.
9. **Düzeltme sırası:** spec sırası (FPC, deff, kayıp; 463) kalır. Yayımlanmış kaynakla DOĞRULANAMADI (deff sonra yanıt oranı kısmı StatCan kaynağıyla destekli; FPC'nin deff'ten önce gelmesi için kaynak yok). Deff-önce sırası 407 verir (Kish adı doğrulanmadı); 463 muhafazakâr yönde. Yardım sayfası sırayı ve bu durumu yazar.
10. **Taşma mesajı:** yeni `err_precision_big`; `err_overflow` ("effect ve deff") kesinlikte kullanılmaz.

Önceden kapanan: `write_methods` kesinlik paragrafı yazar (kullanıcı kararı, 2026-11-14).
