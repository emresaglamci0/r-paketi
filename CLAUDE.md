# CLAUDE.md

Bu depo, veri toplamadan önce örneklem büyüklüğünü planlayan ve gerekçelendiren bir R paketidir. Asıl hedef, ajanları yöneterek R paketi geliştirmeyi öğrenmektir. Tasarım: `docs/superpowers/specs/2026-11-09-orneklem-planlama-paketi-design.md`.

## Ortam

- R 4.6.1 `PATH`'te değil. Her zaman tam yol kullan: `D:\R-4.6.1\bin\Rscript.exe`.
- Depo yolu boşluk ve `ş` içerir. Yolları tırnakla.
- R paketlerini `lib = "D:/R-4.6.1/library"` ile kur. Proje çıktılarını D sürücüsünde tut, C sürücüsüne yazma.
- Rtools yok; `devtools::check()` çalışmaz, `dev\check.ps1` kullan.

```powershell
& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::test()"
powershell -ExecutionPolicy Bypass -File dev\check.ps1
& "D:\R-4.6.1\bin\Rscript.exe" -e "devtools::document()"
```

## Kod kuralları

- Fonksiyon adları ve kod yorumları İngilizce. R kodu ASCII kalır.
- Türkçe ve İngilizce metin, uyarı ve hatalar `inst/` altındaki UTF-8 dosyalarda durur. Kod içine Türkçe metin yazma.
- Hesap motoru yazma. `pwrss` çağır ve çıktısını testle koru.
- Shiny ya da başka grafik arayüz yok. Paket R konsolunda ve RStudio'da fonksiyonlarla kullanılır.
- Paket ham veri istemez.

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
5. `devtools::test()` ve `dev\check.ps1` geçmeden kullanıcıya getirme. Hedef 0 hata, 0 uyarı.
6. Kullanıcı ders düzeyinde R biliyor. Kısa Türkçe anlatım ver: her fonksiyon ne yapar, neden böyle yazıldı, istatistik neye dayanıyor.
7. Kullanıcının konsolda deneyeceği 2-3 örnek ve bilerek hatalı bir girdi ver.
8. Onaydan sonra `main`'e birleştir ve `docs/devlog.md` dosyasına ajanın doğru yaptığı ve kaçırdığı şeyi yaz.

Commit ve push yalnız kullanıcı isteyince yapılır.
