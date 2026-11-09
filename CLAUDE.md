# CLAUDE.md

Bu depo, veri toplamadan önce örneklem büyüklüğünü planlayan ve gerekçelendiren bir R paketidir. Asıl hedef, ajanları yöneterek R paketi geliştirmeyi öğrenmektir. Tasarım: `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`.

## Ortam

- R 4.6.1 `PATH`'te değil. Her zaman tam yol kullan: `D:\R-4.6.1\bin\Rscript.exe`.
- Depo yolu boşluk ve `ş` içerir. Yolları tırnakla.
- R paketlerini `lib = "D:/R-4.6.1/library"` ile kur. Proje çıktılarını D sürücüsünde tut, C sürücüsüne yazma.

```powershell
& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"
& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::check()"
& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::document()"
```

## Kod kuralları

- Fonksiyon adları ve kod yorumları İngilizce. R kodu ASCII kalır.
- Türkçe ve İngilizce metin, uyarı ve hatalar `inst/` altındaki UTF-8 dosyalarda durur. Kod içine Türkçe metin yazma.
- Hesap motoru yazma. `pwrss` çağır ve çıktısını testle koru.
- Hem R fonksiyonları hem Shiny aynı çekirdeği kullanır. Hesabı Shiny içine yazma.
- Arayüz yalnız yerelde çalışır ve ham veri istemez.

## Doğruluk

- Beklenen değerleri kendi hesabından alma. `stats::power.t.test()`, `stats::power.prop.test()`, `pwr` ve simülasyon kullan.
- Tolerans grup başına n'de ±1 ve yalnız aynı yöntemi kullanan referanslar arasında geçerli.
- Aynı yöntemde ±1 aşılırsa dur, kullanıcıya getir. Toleransı genişletme.

## Çalışma döngüsü

Her dilim tek daldır ve yaklaşık 150 satır kod hedefler. Aşarsa böl.

1. Tek sayfalık plan yaz. Kullanıcı onaylamadan kod başlamaz.
2. Testleri önce yaz.
3. Kodu dalda yaz.
4. Bağlamsız yeni bir Claude ajanı yalnız belgeleri ve diff'i görerek incelesin.
5. `devtools::test()` ve `devtools::check()` geçmeden kullanıcıya getirme. Hedef 0 hata, 0 uyarı.
6. Kullanıcı ders düzeyinde R biliyor. Kısa Türkçe anlatım ver: her fonksiyon ne yapar, neden böyle yazıldı, istatistik neye dayanıyor.
7. Kullanıcının konsolda deneyeceği 2-3 örnek ve bilerek hatalı bir girdi ver.
8. Kullanıcı bir anlama sorusu yanıtlasın ya da küçük bir değişiklik yaptırsın.
9. Onaydan sonra `main`'e birleştir ve `docs/devlog.md` dosyasına ajanın doğru yaptığı ve kaçırdığı şeyi yaz.

Kullanıcının açıklayamadığı kod `main`'e girmez. Commit ve push yalnız kullanıcı isteyince yapılır.
