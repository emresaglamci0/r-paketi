# Dilim 10: 7 açık karar için araştırma (2026-11-14)

Etiketler: **doğrulandı** (kaynak ya da R çıktısı), **doğrulanamadı**. Cochran (1977) ve Kish (1965) kitaplarını doğrudan OKUYAMADIM (archive.org kopyası ödünç alma kilitli, 401). Kitap ifadeleri ikincil kaynaklardandır.

## 1. FPC biçimi: A `n0/(1+(n0-1)/N)` mı, B `n0/(1+n0/N)` mi

- Arka plan: N=1000, e=.05, p=.5 için A 277.73, B 277.53; ikisi de 278 -> 463'e çıkar.
- Kanıt:
  - `cochranSize` 0.1.0 belgesi ve vinyeti A'yı kullanır: `n = n0 / (1 + (n0 - 1) / N)`; vinyet sayıları: 277.7335 (N 1000), N 2000 -> 323, N 500 p .3 e .03 %99 -> 379. Vinyet Cochran'a denklem numarası vermez. (doğrulandı: https://ftp.fau.de/cran/web/packages/cochranSize/vignettes/introduction.html, https://cran.nics.utk.edu/cran/web/packages/cochranSize/refman/cochranSize.html)
  - `samplingbook::sample.size.prop` B'yi kullanır: `n = PQ / (e^2/q^2 + PQ/N)`, eşdeğeri `n0/(1+n0/N)` (doğrulandı: rdrr.io kaynak özeti, https://rdrr.io/cran/samplingbook/src/R/sample.size.prop.R). Kaynak kitap: Kauermann ve Küchenhoff 2010.
  - UFL extension belgesi A'yı verir, N 2000 -> 323 (arama özeti; sayfa açılmadı, kısmen doğrulandı).
  - Cochran'ın kitabında hangi biçimin basılı olduğunu doğrulayamadım. Genel anlatım: Cochran bölüm 4.4 (s. 75) oran için n formülü; A, p kestiricisinin varyansında `n-1` ya da `N-1` kullanımından gelir. Bu da doğrulanamadı.
- Seçenekler: A (plandaki öneri) ya da B.
- Öneri: **A**. Dayanak: (i) mevcut tek R paketi ve çok sayıda ders notu A; (ii) planın bağımsız türetmesi (gerçek varyansın kökü, `(N-n)/(N-1)*PQ/n = (e/z)^2`) tam A; (iii) spec 277,74. B bir paket tarafından kullanılıyor, yani farkı belgelemek gerekir. Yardım sayfasına tek cümle: "Bazı kaynaklar `n0/(1+n0/N)` kullanır, fark en çok 1 kişi."
- Risk: düşük. Fark <= 1; B ile çapraz kontrol yapılırsa test toleransı (aynı yöntem kuralı) değil, "yöntem notu" olarak ele alınmalı.

## 2. Cochran formülünü elle yazmak (CLAUDE.md: "hesap motoru yazma")

- Kanıt: `pwrss` 1.3.3 dışa aktarımı elle listelendi (R çıktısı): `power.z.oneprop`, `pwrss.z.prop`, `power.exact.oneprop`, `pwrss.z.mean` vb. hepsi **güç** hesabıdır; yarı genişlik/kesinlik temelli n işlevi yok (doğrulandı). Kurulu paketlerde `pwr`, `pwrss`, `rsample` var; `samplingbook`, `cochranSize`, `survey`, `epiR`, `binom` vb. kurulu değil. `stats` içinde de kesinlik tabanlı işlev yok.
- Not: `pwrss::inflate.sample(n, rate, ceil.n = TRUE)` = `ceiling(n/(1-rate))` (kayıp payı). Kullanılabilir (`ceil.n = FALSE, verbose = 0`) ama tek satırlık `/ (1 - dropout)`'a göre kazanç yok ve ara tavan riski var; ben çağırmamayı öneririm.
- Seçenekler: (a) istisna, (b) modülü kapsam dışı bırak.
- Öneri: **istisna**; kural "güç motoru yazma" ruhuyla uyumlu: burada güç değil, kapalı formül (`qnorm` ile 3 satır). Beklenen değerler formülden değil, `cochranSize` vinyet sayılarından (277.7335, 323, 379) ve `samplingbook` çıktısından (B, fark <= 1) alınmalı. CLAUDE.md'ye tek satır "istisna: kesinlik formülü" eklemek kuralı tutarlı tutar (kullanıcı kararı).
- Risk: düşük. "Beklenen değeri kendi hesabından alma" kuralı için tek bağımsız sayı kaynağı: cochranSize vinyeti (kurmadan okundu).

## 3. Düzeltme sırası: FPC, x deff, / (1-dropout), tek tavan (463) mı, deff-önce (407) mi

- Kanıt:
  - Statistics Canada (Survey Methodology 2020): efektif n x deff = net n; net n / (yanıt oranı x uygunluk oranı) = brüt n. Yani deff sonra, kayıp (yanıt) en son (doğrulandı: https://www150.statcan.gc.ca/pub/12-001-x/2020001/article/00005/01-eng.htm). Bu, kayıp-son kısmını destekler.
  - FPC'nin deff'ten ÖNCE geldiğine dair yayımlanmış sıra bulamadım. SAGE ansiklopedisi: FPC süperpopülasyon/analitik anket için uygulanmaz (arama özeti). MetricGate FPC'yi n0'a uygular, sonra deff, sonra yanıt oranı der (bloglama niteliğinde, zayıf kaynak).
  - Kish 1965 ve Lwanga & Lemeshow 1991'in ilgili sayfalarını okuyamadım (PDF kopyası var: https://lib.umku.ac.id/wp-content/uploads/2022/06/Sample-size-determination-in-health-studies-a-practical-manual.pdf, açılmadı). Plandaki "Kish sırası 407" iddiası da doğrulanamadı.
- Mantık: deff, SRS varyansına göre çarpandır. Gereken SRS n'si FPC dahil bulunur (SRS iadesiz varyansı), sonra tasarım etkisi çarpılır, sonra yanıtsızlık brüt n'ye çevrilir. Deff-önce yapılırsa FPC "kümelenmiş" örnek boyuna uygulanmış olur ki FPC'nin türetmesi SRS içindir; sonuç daha küçük n (407) verir, yani eksik kayıt riski (daha az örneklem). Muhafazakar yön 463.
- Öneri: **spec sırası kalsın (463)**; yardım sayfasında "sıra bir yöntem kararıdır; kaynak: spec §7 + StatCan net/brüt sırası; FPC-deff sırası için yayımlanmış tek kaynak bulunamadı" yaz. Kaynak doğrulaması olarak "Dilim 10'da kaynakla doğrulanır" cümlesini spec'ten çıkarmak ya da "kısmen doğrulandı" yapmak dürüst olur.
- Risk: orta (kaynak eksik). Pratik fark: 463 vs 407, muhafazakar tarafta.

## 4. `cochranSize` ve `samplingbook` (kurulmadan inceleme)

- `cochranSize` 0.1.0, CRAN 2026-08-08, bakıcı Yosley Carrero, bağımlılık yok. İşlevler: `cochran_n`, `cochran_n_adj`, `cochran_sample_size`. Biçim A. Dikkat: çok yeni (3 ay) ve tek sürüm; bakım geçmişi yok (doğrulandı: https://cran.r-project.org/package=cochranSize).
- `samplingbook` 1.2.4, 2021-04-02, bakıcı Juliane Manitz; son sürümü 5 yıl önce, yani fiilen bakımda değil ama kararlı (doğrulandı: https://cran.r-project.org/package=samplingbook). Biçim B.
- Öneri: kurmayın, gerek yok. Tek seferlik çapraz kontrol için ikisinin de çıktı sayıları yukarıda zaten alındı (cochranSize: 277.7335 / 323 / 379; samplingbook B formu R'da elle: 277.53 -> 278). İkisini `Suggests`'e de eklemeyin. Gerçekten çalıştırmak istenirse geçici kütüphaneye (`lib = D:/rtmp/lib`) kurun, proje kütüphanesine değil.
- Risk: düşük.

## 5. `e >= min(p, 1-p)`: hata mı uyarı mı

- Kanıt: `samplingbook::sample.size.prop` `e > P` ya da `e > 1-P` için **stop** ("Estimate useless"), `e >= 0.5` için ayrıca uyarı, `P` < .1 ya da > .9 iken sonlu N'yi düşürür (uyarı) (doğrulandı: rdrr.io kaynak özeti; Details metni: "precision e should be smaller than proportion P, respectively (1-P)"). `cochranSize` bu denetimi hiç yapmaz (doğrulandı: refman).
- Mantık: `e >= p` ise aralık 0'ı (ya da 1'i) içerir; Wald aralığı bu durumda anlamsız. Hesap yine de bir sayı üretir, ama yanıltıcıdır.
- Öneri: **hata** (plandaki öneri), `samplingbook` ile uyumlu. Sınır: plan `e < min(p, 1-p)` kabul eder (eşitlik hata); samplingbook `e > P` hata, eşitlik geçer; fark yok sayılabilir, bilerek "eşitlik de hata" yazın.
- Risk: düşük.

## 6. `check_adjust` çıkarımı `R/plan.R`'a dokunur mu

- Kod (R/plan.R:115-116): iki tek satırlık `if (...) fail("err_dropout"/"err_deff", ...)`. `fail()` aynı anahtarla aynı metni verir. (doğrulandı: okundu)
- Altın dosya: `helper-golden.R`'daki `golden_errors()` listesinde dropout/deff hatası YOK (13 çağrı, hiçbiri `dropout`/`deff` değil); `golden_plans()` yalnız geçerli dropout/deff değerleri kullanır. `test-plan.R` yalnız `err_overflow`'u sınar. Yani çıkarım altın dosyayı yalnız dropout/deff'in HESAP sırasını değiştirirse kırar; çıkarım hesap satırlarına (121-123) dokunmuyor. (doğrulandı: grep + okuma)
- Tek gerçek risk: doğrulama sırası. Şimdi `check_probability(alpha)`, `check_power`, sonra dropout, sonra deff. `check_adjust(dropout, deff)` aynı yerde çağrılırsa sıra korunur; hatalar birden fazla geçersiz girdide hangi mesajın önce çıktığına bağlı, bunu da hiçbir test sınamıyor.
- Öneri: **çıkar** (plan.R'da net 0 satır, tekrar yok), önce `devtools::test(filter = "golden")` ve `test-plan` çalıştırılsın. Kopyalama iki yerde aynı kuralı tutmak demektir (gelecekte biri değişir, öteki kalır).
- Risk: düşük.

## 7. Küçük kararlar

- `p` dayanağı alanı: **hayır**. Kesinlik planında `p = .5` tipik; alan eklemek `effect_basis` mantığını (spec) kesinliğe taşır. Gerekirse sonraki dilim. (Görüş.)
- `precision_margin()`: **hayır, bu dilimde yok**; boyut hedefi 150 satır ve plan zaten 10a/10b'ye bölünebilir. (Görüş.)
- Ortalama kestirimi: **kapsam dışı**; spec §"Kapsam dışı" ile uyumlu (tek oran). (Görüş.)
- `err_overflow` metni (inst/i18n/messages.csv:43): "Check effect and deff" / "effect ve deff değerlerini kontrol edin". Kesinlik planında `effect` yok ve bu yanıltıcı. Öneri: **yeni `err_precision_big`** ("Check e, N, deff and dropout."). Mevcut anahtar plan_study için de kullanılıyor ve test-plan.R:62-64 onu bire bir sınıyor; ona dokunmak gerekmez. (doğrulandı: grep + okuma)

## Özet tablo

| # | Karar | Öneri | Güven |
|---|---|---|---|
| 1 | FPC biçimi | A `n0/(1+(n0-1)/N)`; B'yi yardımda an | yüksek (biçim) / orta (Cochran basılı biçimi doğrulanamadı) |
| 2 | Elle formül | İstisna (kapalı formül); beklenen sayılar cochranSize vinyetinden | yüksek |
| 3 | Düzeltme sırası | Spec sırası (463); FPC-deff sırası için kaynak yok, yardımda dürüstçe yaz | orta |
| 4 | Paket kurulumu | Kurma; sayılar zaten okundu | yüksek |
| 5 | `e >= min(p,1-p)` | Hata (samplingbook gibi) | yüksek |
| 6 | `check_adjust` | plan.R'dan çıkar, önce golden testi | yüksek |
| 7 | Küçükler | p alanı hayır, `precision_margin` hayır, ortalama hayır, yeni `err_precision_big` | orta-yüksek |
