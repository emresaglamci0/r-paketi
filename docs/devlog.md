# Geliştirme günlüğü

## Dilim 0: paket iskeleti (2026-11-09)

- **Ajan doğru yaptı:** İskeleti kurdu, `R CMD check` engelinde durup Rtools hatasını bildirdi, `dev/check.ps1` betiğinin hata yolunu bilerek bozup kanıtladı.
- **Ajan kaçırdı:** `devtools::check()` komutunun Rtools istediği planlama sırasında fark edilmedi. C sürücüsü doluyken ilk `document()` çalışması açıklanamayan bir "13 hata" mesajı verdi; geçici klasör D'ye alınınca tekrar etmedi.

## Dilim 1a: Türkçe/İngilizce mesaj altyapısı (2026-11-09)

- **Ajan doğru yaptı:** Testleri önce yazdı, CSV'yi BOM'suz UTF-8 kaydetti, hata yollarını `msg()` döngüsüne sokmadı.
- **Ajan kaçırdı:** Test dosyasına ASCII dışı `Örneklem şığ` yazdı ve raporunda bahsetmedi. Bağımsız inceleme yakaladı, `R CMD check` yakalamamıştı.
