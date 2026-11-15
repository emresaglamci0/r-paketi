# Örneklem planlama R paketi: tasarım

Tarih: 2026-11-09
Durum: Taslak, kullanıcı onayı bekliyor

## 1. Amaç ve neden

Asıl hedef, yapay zekâ ajanlarını yöneterek R paketi geliştirmeyi öğrenmektir. Paket bu öğrenmenin aracıdır ve portföy parçasıdır. İleride akademik yayına dönüşebilir. Çok kişinin kullanması şu an hedef değildir.

Paket, bir araştırmacının veri toplamadan önce örneklem büyüklüğünü planlamasına ve gerekçelendirmesine yardım eder. Kullanıcı varsayımlarını girer. Paket şunları üretir:

- gerekli örneklem büyüklüğü,
- duyarlılık senaryoları (verilen n ile saptanabilecek en küçük etki),
- kopyalanabilir Türkçe veya İngilizce yöntem paragrafı,
- hatalı yöntem kullanımına karşı uyarılar.

Pazar araştırması boşluğu "orta" buldu: güç hesabı, etki büyüklüğü ve APA metni parçaları dolu. Türkçe rapor üreten bir paket ve iş akışına gömülü hatalı kullanım uyarısı bulunamadı. Bu yüzden paket genel "hepsi bir arada" aracı değil, planlama aracıdır.

## 2. Hedefler

- Çalışan, test edilmiş, kurulabilir bir R paketi.
- Hem R bilen araştırmacının hem R kurabilen ama kod yazmayan tez öğrencisinin kolayca kullanabilmesi.
- Hesapların bağımsız kaynaklarla doğrulanmış olması.
- Kullanıcının her kod dilimini okuyup anlayabilmesi.
- Tekrarlanabilir bir ajanlı geliştirme süreci.

**Başarı ölçütü (kullanıcı):** Paket çalışıyorsa proje başarılıdır. Bu belgede "çalışıyor" şu demektir:

- Tüm `testthat` testleri geçer.
- `R CMD check` 0 hata ve 0 uyarı verir.
- Kapsamdaki her test için hesaplanan n, Bölüm 6'daki referanslarla toleransta uyuşur.
- Kullanıcı her dilimi kendi girdileriyle denemiştir.

## 3. Hedef olmayanlar

- Yeni bir istatistik hesap motoru yazmak.
- İlk sürümde veri analizi ve sonuç raporlamak. Bu ikinci aşamadır.
- Karma modeller.
- Tam karmaşık anket deseni (tabaka, küme ve ağırlık birlikte). Yalnızca tek sayılık DEFF girdisi vardır.
- Örnek çekme (rastgele seçim yapma).
- Benimsenme, indirme sayısı gibi hedefler.
- Barındırılan web uygulaması.

## 4. Kullanıcının verdiği kararlar

- Konum: varsayımları kaydeden, duyarlılık senaryosu üreten, Türkçe/İngilizce metin yazan planlama aracı.
- Sonuç raporu ikinci aşama.
- Hesaplar mevcut paketlere dayanır. `sampler` kullanılmaz.
- Korkuluklar uyarı verir. Gerekçesiz etki seçimi engellenmez, metinde açıkça belirtilir. Gözlenen güç isteği reddedilir ve duyarlılık analizine yönlendirilir.
- İlk testler t testi, ANOVA, oran ve korelasyondur; birkaç test daha eklenebilir.
- 5. madde (karma model, simülasyon, anket deseni) geliştirilecek, kapsamı aşağıdaki gibi önerilmiştir.
- Hedef kitle R bilen araştırmacı ile R kurabilen ama kod yazmayan tez öğrencisidir. Kullanım kolaylığı önceliklidir.
- Grafik arayüz (Shiny) yoktur (kullanıcı kararı, 2026-11-14). Paket R konsolunda ve RStudio'da R fonksiyonlarıyla kullanılır. Barındırılan web uygulaması yoktur.
- Kodu Claude yazar, Claude inceler. Codex kullanılmaz.
- Kullanıcı her dilimin kodunu okur, anlar ve dener.
- Git deposu çalışma klasöründedir.

## 5. Oluşturucunun kararları (kullanıcı henüz ayrıca onaylamadı)

- Fonksiyon adları ve kod yorumları İngilizce, çıktı dili `lang = "tr"` ya da `"en"`.
- S3 sınıflı tek plan nesnesi.
- `pwrss` `Imports` içinde. `Suggests`: `pwr` ve `testthat` (test), `DMAR` (Dilim 9c'deki rastgele yordayıcı bilgi satırı ve Dilim 11b'de `simulate_power(predictor_type = "random")` için genel R² testinin referans gücü; kurulu değilse satır gösterilmez, simülasyon durum vermez, hata vermez). `effectsize` yalnızca ikinci aşamada eklenir, çünkü ilk sürümde veri analizi yoktur. `shiny` kullanılmaz.
- Lisans MIT.
- Paket, deponun kökünde bulunur.
- Simülasyon ayrı özellik değil, doğrulama aracıdır.
- Küme örneklemesi yalnızca `n × DEFF` girdisiyle desteklenir.
- Paket adı henüz seçilmedi. Dilim 0'da CRAN'da boş olduğu kontrol edilerek kullanıcıyla seçilir.
- Yöntem kapsamı: ANOVA yalnız genel (omnibus) F testi; oran testi iki bağımsız oran; ki-kare bağımsızlık testi; çoklu regresyon genel R². Tek oran hipotez testi kapsam dışı, tek oran için Dilim 10'daki kesinlik hesabı vardır.
- Etki dayanağı açık bir argümandır: `effect_basis` (Bölüm 7). Korkuluklar serbest metne bakmaz.
- Kayıp payı (`dropout`) ve `deff` tüm planlarda geçerlidir. Alanlar Dilim 1'den itibaren plan nesnesindedir, varsayılanları `dropout = 0` ve `deff = 1`.
- Tüm kullanıcı mesajları (metin, uyarı, hata) Türkçe ve İngilizcedir. Dil altyapısı Dilim 1'de kurulur.

## 6. Doğruluk referansları

Hesapların doğruluğunu ajanın kendi hesabı belirlemez. Her test için:

- **Otomatik referans:** `pwrss`'ten bağımsız olarak `stats::power.t.test()`, `stats::power.prop.test()` ve `pwr` (yalnızca `Suggests`, test için). Tolerans: grup başına n'de ±1.
- **Simülasyon:** Yuvarlanmış n ile veri üretilir, planlanan test en az 10.000 kez çalıştırılır. Ampirik güç, o n için hesaplanan analitik güçten en çok 0,02 sapabilir ve hedef güçten en az 0,02 eksik kalmamalıdır. Hedefle değil analitik güçle karşılaştırılır, çünkü yukarı yuvarlama gücü hedefin üstüne çıkarabilir (d=1.5 için n=9, güç yaklaşık 0,85). Uzun süren simülasyon `testthat::skip_on_cran()` ile korunur.
- **Çelişki kuralı:** ±1 toleransı yalnızca aynı yöntemi kullanan referanslar arasında geçerlidir. Yöntem farkından doğan fark başarısızlık değildir, testin yöntem notuna yazılır (ör. p1=.10, p2=.05, güç=.80 için `power.prop.test` 434,4, arcsine 423,7). Paket `pwrss`'in yöntemini kullanır ve metinde adını yazar; referans olarak aynı yöntemi uygulayan fonksiyon seçilir. Aynı yöntemde ±1 aşılırsa dilim durur, kullanıcıya getirilir.

Bilinen sabit kıyaslar: d=0.5, α=.05, güç=.80, iki yönlü bağımsız t testi için grup başına 64. Cochran için z=1.96, p=.5, e=.05 ile `n0 = 384.16`, yukarı yuvarlanınca 385.

## 7. Paketin biçimi

Aşağıdaki adlar taslaktır, dilim planında kesinleşir.

```r
p <- plan_study(
  test = "t_independent",
  effect = 0.4,
  effect_basis = "prior_study",
  effect_source = "Yilmaz 2021, meta-analiz",
  alpha = 0.05,
  power = 0.80,
  alternative = "two.sided",
  dropout = 0.10,
  deff = 1
)
sensitivity(p, n = 50)
write_methods(p, lang = "tr")
```

- `effect_basis` değerleri: `"prior_study"`, `"pilot"`, `"smallest_of_interest"`, `"convention"`, `"observed"`, `"unknown"` (varsayılan). Başka çalışmadan ya da pilottan gelen etki meşrudur, aynı çalışmanın verisinden gelen etki değildir.
- `effect_source` isteğe bağlı serbest metindir, metne aynen yazılır.
- Dil: `getOption()` ile paket düzeyinde ayarlanır, varsayılan `"en"`. `write_methods(lang = )` bunu ezer.
- Türkçe metin şablonları ve mesajları kod içine değil `inst/` altındaki UTF-8 dosyalara konur. Böylece R kodu ASCII kalır.
- Gerekli n'ye düzeltme sırası: analitik n (varsa sonlu evren düzeltmesi), sonra `× deff`, sonra `/ (1 - dropout)`. Yukarı yuvarlama yalnız en sonda bir kez yapılır. Örnek: N=1000, e=.05, p=.5, DEFF=1.5, kayıp %10 için 277,74, 416,6, 462,9 ve sonuç 463. Dilim 10'da yayımlanmış kaynakla doğrulanamadı; sıra kullanıcı kararıyla korundu (2026-11-14, `docs/research/2026-11-14-dilim-10-kararlar.md`). Önce deff uygulanırsa sonuç 407 olur.
- Paket yalnızca planlama yapar, ham veri istemez.

### İlk korkuluklar

| Durum | Davranış |
|---|---|
| `effect_basis = "unknown"` ya da `"convention"` | Uyarı ve metinde açık ifade |
| `effect_basis = "observed"` (gözlenen güç) | Hata, `sensitivity()` önerisi |
| `plan_precision()` çıktısı (Cochran) `sensitivity()`'e ya da bir hipotez testi işlevine verilir | Sınıfından tanınır, hata ve `plan_study()` önerisi. `write_methods()` hata vermez: kesinlik planı için kendi yöntem paragrafını yazar (kullanıcı kararı, 2026-11-14) |

İlk iki satır Dilim 3'te, Cochran satırı Dilim 10'da yapılır.

## 8. Dilimler

Her dilim tek git dalıdır ve yaklaşık 150 satır kod hedefler. Aşarsa bölünür.

0. Kurulum: geliştirme paketleri, iskelet, `CLAUDE.md`, `R CMD check` denemesi, paket adı.
1. Bağımsız t testi: plan nesnesi, n hesabı, duyarlılık, dil altyapısı. Gerekirse iki dala bölünür.
2. Türkçe ve İngilizce yöntem metni.
3. Korkuluklar.
4. Eşli t testi.
5. Tek yönlü ANOVA.
6. İki oran.
7. Korelasyon.
8. Ki-kare.
9. Çoklu regresyon (genel R² F testi).
9b. Kısmi/artımsal R² (ΔR²) ve tek yordayıcı testi. `pwrss` kısmi testte `pwr` ile uyuşmaz (54,59 ve 56,52); yöntem farkı ve çelişki kuralı bu dilimde ele alınır.
9c. Rastgele yordayıcı bilgi satırı (DMAR, `Suggests`).
10. Örnekleme modülü: Cochran, sonlu evren düzeltmesi, kayıp payı, DEFF.
11. Simülasyonla doğrulama fonksiyonları.
12. (Kaldırıldı, 2026-11-14: Shiny arayüzü yapılmayacak. Numara korunur, böylece 13 değişmez.)
13. `pkgdown` sitesi, GitHub Actions, CRAN hazırlığı. Yayından önce tüm testler için simülasyonla güç testi yapılır (ör. regresyonda rastgele yordayıcılarla ampirik güç).

Ki-kare ve çoklu regresyon için `pwrss` desteği Dilim 0'da doğrulanır. Destek yoksa kapsam kullanıcıyla yeniden konuşulur.

## 9. Her dilimin döngüsü

1. Tek sayfalık plan yazılır. Kullanıcı onaylamadan kod başlamaz.
2. Testler önce yazılır, beklenen değerler Bölüm 6'dan gelir.
3. Kod dalda yazılır.
4. Bağlamsız yeni bir Claude ajanı yalnızca belgeleri ve diff'i görerek inceler.
5. `devtools::test()` ve `R CMD check` geçer.
6. Kullanıcıya kısa Türkçe anlatım gelir: her fonksiyon ne yapar, neden böyle yazıldı, istatistik neye dayanıyor.
7. Kullanıcı konsolda 2-3 örneği ve bilerek hatalı bir girdiyi dener.
8. Kullanıcı bir anlama sorusu yanıtlar ya da küçük bir değişikliği ajana yaptırır.
9. Onay sonrası `main`'e birleştirilir, `docs/devlog.md` dosyasına ajanın doğru yaptığı ve kaçırdığı şey yazılır.

Kural: kullanıcının açıklayamadığı kod `main`'e girmez.

## 10. Kısıtlar ve ortam

- R 4.6.1, `D:\R-4.6.1\bin\Rscript.exe`. `PATH`'te değil, komutlar tam yol kullanmalıdır.
- Eksik paketler: `devtools`, `usethis`, `testthat`, `pkgdown`, `pwrss` (`shiny` 2026-11-14'te kapsamdan çıktı). Kurulu: `roxygen2`, `pkgbuild`.
- Rtools `PATH`'te bulunamadı. Saf R paketi için gerekmemesi beklenir, Dilim 0'da doğrulanır.
- Depo yolu boşluk ve `ş` içerir: `D:\r paketi geliştirme`. Dilim 0'da `R CMD build` ve `R CMD check` burada denenir. Sorun çıkarsa kullanıcıya sorulup depo ASCII bir yola taşınır.
- Kullanıcı ders düzeyinde R biliyor. Anlatımlar buna göre yazılır.
- Commit ve push yalnızca kullanıcı isteyince yapılır.

## 11. Yayın hazırlığı

Yayın şimdi hedef değildir, ama şu izler korunur: doğruluk kıyas tablosu (`pwr`, temel R, simülasyon) ve geliştirme günlüğü. Hedef dergi şartları ve yapay zekâ kullanım beyanı kuralları yayın kararı verilirse kontrol edilir.

## 12. Oluşturucuya bırakılanlar

- Dosya ve iç fonksiyon düzeni.
- Plan nesnesinin alanları.
- Hata mesajlarının tam metni.
- Metin şablon biçimi.
- `pwrss` çıktısının sarmalanma yöntemi (sürüm değişikliklerine karşı testle korunmalıdır).
