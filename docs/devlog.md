# Geliştirme günlüğü

## Dilim 0: paket iskeleti (2026-11-09)

- **Ajan doğru yaptı:** İskeleti kurdu, `R CMD check` engelinde durup Rtools hatasını bildirdi, `dev/check.ps1` betiğinin hata yolunu bilerek bozup kanıtladı.
- **Ajan kaçırdı:** `devtools::check()` komutunun Rtools istediği planlama sırasında fark edilmedi. C sürücüsü doluyken ilk `document()` çalışması açıklanamayan bir "13 hata" mesajı verdi; geçici klasör D'ye alınınca tekrar etmedi.

## Dilim 1a: Türkçe/İngilizce mesaj altyapısı (2026-11-09)

- **Ajan doğru yaptı:** Testleri önce yazdı, CSV'yi BOM'suz UTF-8 kaydetti, hata yollarını `msg()` döngüsüne sokmadı.
- **Ajan kaçırdı:** Test dosyasına ASCII dışı `Örneklem şığ` yazdı ve raporunda bahsetmedi. Bağımsız inceleme yakaladı, `R CMD check` yakalamamıştı.

## Dilim 1b: bağımsız t testi planı ve duyarlılık (2026-11-09)

- **Ajan doğru yaptı:** Hesabı `pwrss`'e bıraktı, düzeltme sırasını doğru uyguladı, referanslarla ±1 içinde kaldı. Görev incelemesi planın n=2 alt sınırındaki hatayı yakaladı.
- **Ajan kaçırdı:** Testler geçmesine rağmen genel inceleme 7 kullanıcı hatası buldu: `alternative = "greater"` ham hata veriyordu, `pwrss` güç aralığı planlamada atlanmıştı, `n_effective` kayan nokta hatasıyla bir eksik çıkıyordu. Bir düzeltme de `alpha` kelimesini bozuk karakterle yazdı.

## Dilim 2: Türkçe/İngilizce yöntem metni (2026-11-09)

- **Ajan doğru yaptı:** Metni CSV'den kurdu, sayıları ek hesap yapmadan biçimlendirdi, kullanıcı metnini biçim dizgesine sokmadı.
- **Ajan kaçırdı:** Planın kendi metni iki yanlış ifade içeriyordu: ilgilenilen en küçük etkiye "beklenen" diyordu, kaynak verilmişken "dayanağı belirtilmemiştir" yazıyordu. Testler bunları yakalayamadı, çünkü beklenen metin de plandan geliyordu; genel inceleme buldu. Son turda iki test koddan sonra yazıldı, bilerek bozma denemesi testlerin çalıştığını gösterdi.

## Dilim 3: dayanak korkulukları (2026-11-10)

- **Ajan doğru yaptı:** `"observed"` hatasını motordan önce, uyarıyı başarılı hesaptan sonra koydu; uyarıyı sınıflı yaptı, böylece testler yalnız onu susturdu. Silinecek iki metnin tüm kullanımlarını bulup düzeltti.
- **Ajan kaçırdı:** Kritik bir şey kaçırmadı. Genel inceleme yardım sayfasının yeni davranışı anlatmadığını ve uyarının dürüst seçenekleri söylemediğini buldu; ikisi düzeltildi. Elle değiştirilmiş plan nesnesindeki kötü hata mesajı ertelendi.

## Dilim 4: bağımlı örneklemler t testi (2026-11-10)

- **Ajan doğru yaptı:** Test tablosunu (`test_spec`) kurdu, d ve r'den dz hesabını doğru uyguladı; 42 bileşimde referanslarla ±1 içinde kaldı. Elle bozulmuş plan nesnesi sorununu da kapattı.
- **Ajan kaçırdı:** Planın kendisi hangi d'nin girileceğini tanımlamıyordu; öğrenci dz'yi d sanarsa n yarıya inebilirdi. Genel inceleme buldu, belgeye ve metne tanım eklendi. Kaynak verilince çift parantez oluştuğunu örnek çıktıda kontrolcü fark etti; inceleme bunu kaynaksız örnekle çalıştığı için görmemişti. CSV yazarken ajan bir kez tırnaksız alan ve kontrol karakteri bıraktı, kendisi düzeltti.

## Dilim 5: tek yönlü ANOVA (2026-11-10)

- **Ajan doğru yaptı:** `pwrss::power.f.ancova`'yı sardı, f ve η² yolunu doğru çevirdi; 168 bileşimde referanslarla ve simülasyonla uyuştu. t testi çıktıları birebir aynı kaldı.
- **Ajan kaçırdı:** Çok büyük `k` ham hata veriyordu; "anova" yazınca kısmi eşleşme sessizce `anova_oneway`'i seçiyordu (test adları artık tam eşleşiyor). Planın post hoc cümlesi F testinin gösterdiğinden fazlasını iddia ediyordu ve yardım sayfası etkiyi yalnız d diye tanımlıyordu; ikisini genel inceleme buldu.

## Dilim 6: test arayüzü ve bağımsız iki oran (2026-11-13)

- **Ajan doğru yaptı:** Teste özgü dalları `test_spec` fonksiyonlarına taşıdı; altın dosya `main`'den bağımsız yeniden üretilip birebir aynı çıktı. İki oranı yeni dal açmadan ekledi; n `stats` ile 709 durumda uyuştu. Oturum kesilince kaldığı yerden devam etti.
- **Ajan kaçırdı:** `pwrss`'in duyarlılık araması düz bölgeye takılıp 0.9998 döndürüyordu; plandaki "0.999 üstü hata" kuralı bunu gizledi ve bir test hatalı davranışı sabitledi. Genel inceleme yakaladı, `pwrss` gücü üzerinde kök arama ile çözüldü. Ham İngilizce hatalar, iç içe parantez ve "süreklilik düzeltmesi yok" eksikliği de incelemede çıktı. "En fazla 1 kişi" iddiası (benim planımdaki) ölçümle yanlış çıktı.

## Dilim 7: Pearson korelasyonu (2026-11-13)

- **Ajan doğru yaptı:** Korelasyonu yalnız `test_spec` ve motor dosyasına ekledi; Fisher z formülüyle birebir uyuştu. `pwr` ile karşılaştırma ±1'i aşınca toleransı genişletmek yerine durdu ve sordu. `pwrss`'in negatif yönde bozuk duyarlılık aramasını plan kontrol ajanı önceden buldu.
- **Ajan kaçırdı:** Planın kendisi `pwr`'ı aynı yöntem sanmıştı (o bir düzeltme ekliyor). Genel inceleme iki kullanıcı sorunu buldu: `r = 0.3` yazan öğrenci yardımcı mesajı göremiyordu, tek yönlü testte yön metne yazılmıyordu. Düzenleme aracı testteki `\u` kaçışlarını iki kez gerçek harfe çevirdi; ajan fark edip düzeltti.
