# Eğitim veri setiyle paket değerlendirmesi (tasarım)

## Amaç

Kullanıcı paketin düzgün çalışıp çalışmadığını görmek istiyor. Sonuca göre paketi GitHub ve LinkedIn'de paylaşabilir. Bu iş pakete özellik eklemez. Çıktısı bir bulgu raporudur: çalışmayan yerler, bilimsel olarak sorunlu yerler, avantajlar ve dezavantajlar.

## Hedefler

- Gerçekçi bir eğitim veri seti üretilir: 500 satır, 15 değişken.
- Paketin önerdiği n, gerçekçi (çarpık, sınırlı, ilişkili) veride söz verdiği gücü veriyor mu? Bootstrap ile ölçülür.
- Pilot veriden tahmin edilen etki büyüklüğüyle plan yapmanın sonucu gösterilir.
- `devtools::test()` ve `dev\check.ps1` çalıştırılır, sonuç olduğu gibi yazılır.
- Her dışa aktarılan fonksiyon denenir. Bilerek hatalı girdiler de verilir.

## Hedef olmayanlar

- Paket kodunu değiştirmek. Bulunan hata rapora yazılır, düzeltme ayrı dilim olur.
- Yayın (Dilim 13a), LinkedIn metni.
- Toleransı gevşetmek ya da sonucu güzel göstermek. Kötü sonuç olduğu gibi yazılır.

## Yaklaşımlar

- A. Veri yalnız pilot: etki tahmin edilir, n hesaplanır. Ucuz, ama paketin sözünü sınamaz.
- **B. Pilot + evren (seçildi):** 500 satır "evren" kabul edilir. Paketin n'i kadar satır yerine koymalı çekilir, gerçek test koşulur, ampirik güç hedefle kıyaslanır. `simulate_power`'ın normal varsayımlı verisinden farklı olarak gerçekçi veride sınar.

## Veri seti (oluşturucunun kararı)

Sabit tohum, `MASS::mvrnorm` ile ortak gizli yapı, sonra dönüşümler. 15 değişken:
`ogrenci_id`, `cinsiyet`, `sinif` (9-12), `okul_turu` (3 düzey, eşit olmayan grup boyları), `anne_egitim_yil`, `calisma_saati` (sağa çarpık), `devamsizlik` (sayım, çarpık), `ders_disi` (evet/hayır), `ozel_ders` (evet/hayır), `motivasyon`, `oz_yeterlik`, `sinav_kaygisi` (1-5 Likert ortalaması, sınırlı), `mat_on`, `mat_son` (eşli ölçüm), `gecti` (ikili).

## Test eşlemesi

| Paket testi | Veri sorusu |
|---|---|
| `t_independent` | `mat_son` ~ `ozel_ders` |
| `t_paired` | `mat_on` ve `mat_son` |
| `anova_oneway` | `mat_son` ~ `okul_turu` (eşit olmayan gruplar: paket eşit grup varsayar) |
| `prop_two` | `gecti` ~ `ozel_ders` |
| `cor_pearson` | `calisma_saati` ve `mat_son` |
| `chisq_indep` | `okul_turu` x `ders_disi` |
| `reg_overall` | `mat_son` ~ 5 yordayıcı |
| `reg_partial` | aynı model, 2 yordayıcının ΔR²'si |
| `plan_precision` | `gecti` oranı, N = 1000 |

## Yöntem

1. Etki büyüklüğü 500 satırın tamamından hesaplanır ("gerçek" değer).
2. `plan_study(..., power = .80)` ile n alınır (`dropout = 0`, `deff = 1`).
3. Bu n ile 2000 bootstrap tekrarı. Her tekrarda gerçek test (`t.test`, `aov`, `prop.test(correct = FALSE)`, `cor.test`, `chisq.test(correct = FALSE)`, `lm` ve `anova`) α = .05 ile koşulur.
4. Ampirik güç .80 ± 3 MC standart hatası (≈ ±.027) içindeyse KALDI, dışındaysa İNCELE.
5. Pilot deneyi: 30 satırlık 500 pilot çekilir. Etki tahmin edilip plan yapılır. Planlanan n ile evrendeki gerçek güç dağılımı (medyan, %25'in altı) raporlanır.
6. `plan_precision`: önerilen n ile çekilen örneklemlerde hata payının e'yi aşma oranı raporlanır.
7. `sensitivity`, `write_methods` (tr ve en), `simulate_power` her plan için bir kez koşulur. Kasıtlı hatalı girdilerle mesajlar kontrol edilir.
8. Kod okuması: varsayılanlar, uyarılar ve metin iddiaları bilimsel açıdan gözden geçirilir.

## Dosyalar

- `dev/eval/make-education-data.R`, `dev/eval/evaluate.R` (`dev/` zaten `.Rbuildignore`'da).
- `docs/eval/egitim-500.csv`, `docs/eval/2026-11-15-sonuclar.csv`, `docs/eval/2026-11-15-rapor.md`.
- Dal: `eval-education-data`. Commit yalnız kullanıcı isteyince.

## Oluşturucuya bırakılanlar

- Gizli yapının katsayıları (etkiler küçük-orta olmalı, n'ler 500'ü çok aşmamalı).
- Raporun biçimi.
- Bağlamsız ajan incelemesi: raporun iddiaları ve betik bir ajana kontrol ettirilir.
