# Dilim 11 doğrulama araştırması (2026-11-14)

Betikler: `D:\rtmp\q1.R`, `q2.R`, `q2b.R`, `q4.R` (repo dışı, salt okunur `load_all`). Hiçbir repo dosyası değiştirilmedi.

## 1. prop_two tek yönlü .10/.05: simülasyon ~.81, pwrss .8009 (güven: yüksek)

**Bulgu.** Sebep ayrık (binom) veri; varyans, tek yönlülük ya da `prop.test` kaynaklı değil.
- `pwrss::power.z.twoprops(std.error = "pooled")` (kaynak okundu): ortalama `lambda = (p1-p2)/SE_unpooled`, H0 sapması `null.sd = SE_pooled(p.bar gerçek p'lerden)/SE_unpooled`. Yani `prop.test(correct = FALSE)`'in birleştirilmiş-varyanslı z testinin **asimptotik gücü**; test istatistiği ile formül uyumlu. `stats::power.prop.test` aynı n'de .8009 verir (tesadüfen aynı sayı).
- Tek yönlü `prop.test` p değeri = `1 - pnorm(z)` (elle doğrulandı, p = 0.02245671 ikisinde de).
- **Tam güç** (n = 343, 344x344 ikili binom sonuçlarının hepsi sayıldı, gürültü yok): **.8095** (p1>p2 ve p1<p2 aynı, simetri). pwrss .8009, fark +.0086. Benim 1e5 koşum: .81058 / .81029 (SE .0012), denetçinin .8106/.8103 ile uyumlu; `prop.test` ile 2e4 tekrar .8098. Yani gerçek fark ~+.009, plandaki "+.010" simülasyon gürültüsüyle şişik.
- Işaret ızgarası (n = round_up(n_analytic), tam güç - pwrss; hedef .8/.9, tek/iki yönlü, p1<->p2 aynı):
  - Küçük p'de pozitif: .10/.05 +.005..+.011; .02/.01 +.006..+.012; .15/.05 tek yönlü .8 **+.0208**, iki yönlü +.0147; .30/.10 +.007..+.011; **.05/.01 +.026..+.045** (n 224-381).
  - p ~ .5'te küçük negatif: .5/.4 .8 hedef -.006 / -.005; .45/.30 iki yönlü -.001. Negatif taraf en fazla -.006: .02 bandını **asla** aşmıyor.
  - p'ler yakın ve ortada: |fark| <= .003.
- **Yanlış FAIL riski:** negatif yönde yok. Pozitif yönde (ampirik > analitik) p2 <= ~.05 ve oran büyükken .02 aşılır (.15/.05, .05/.01). Bu durum kullanıcının kararındaki `status = "warn"` kuralına düşer (ampirik >= hedef - .02 zaten sağlanır), FAIL olmaz. `.10/.05` vakası için 10.000 tekrar, gerçek fark .0086: .02'yi geçmek için ampirik >= .8209 gerekir (~2,8 SE); sabit tohumda tek seferlik ~%0,3 risk, sınır aşılırsa "dur ve getir" kuralı geçerli.

**Öneri.** Vakayı koru, test istatistiğini değiştirme (planlanan test pooled z, doğru olan o). Belgele.

**11a değişikliği.**
1. Plandaki "Neden ... doğrulanmadı" cümlesi şu yorum olur (`R/tests.R` prop_two `simulate` ya da test dosyası): `# pwrss power is the asymptotic power of the pooled z test; exact binomial power at n = 343 is .8095 (enumeration), so the +.009 gap is discreteness, not an error.`
2. Tabloda .10/.05 satırının farkı "~+.009 (tam güç .8095)" yazılsın; "gürültü" ifadesi kalksın.
3. `status` testine deterministik bir "warn" vakası ekle: prop .05/.01 tek yönlü, n 224 (pwrss .8002, tam güç .8365, fark +.036 >> MC gürültüsü). `skip_on_cran`, `reps = 10000`: beklenen `status == "warn"`, `pass == FALSE`.

## 2. cor_pearson Fisher-z: muhafazakâr mı? (güven: yüksek)

**Yöntem.** Tam güç, koşullu t dağılımıyla: x koşulunda eğim t istatistiği ~ nct(df = n-2, ncp = rho*sqrt(Sxx)/sqrt(1-rho^2)), Sxx ~ chisq(n-1); Sxx üzerinden `integrate` (1e-10 tolerans). Doğrulama: r .5 n 30 iki yönlü tam .82769, 2e5 tekrar simülasyon .82788.

**Bulgu.** Fisher-z (pwrss), cor.test'in gerçek gücünün **altında** (muhafazakâr). Plan n'lerinde (rho .1-.9, tek/iki yönlü, hedef .8/.9, 32 durum) fark (tam - pwrss) hep >= +.0003. Taranan genel ızgarada (n 4-400, rho .05-.9, iki yön) en düşük fark -1.2e-5 (gücün ~1 olduğu uçta; önemsiz). İşaret (+/-) etkisiz: nct ncp işaretiyle simetrik, tek yönlü doğru yöndeyse aynı güç. **Analitik > gerçek senaryosu yok**, dolayısıyla yasal plan için gerçek FAIL oluşmaz.

Fark büyüdükçe (plan n'de, tek yönlü / iki yönlü, hedef .8):

| rho | n | pwrss | tam | fark | pwr |
|---|---|---|---|---|---|
| .3 | 85 | .8003 | .8051 | +.005 | .8044 |
| .4 | 47 | .8024 | .8110 | +.009 | .8095 |
| .5 | 30 | .8144 | .8277 | +.013 | .8250 |
| .6 | 20 | .8154 | .8355 | **+.020** | .8306 |
| .7 | 14 | .8203 | .8493 | +.029 | .8407 |
| .8 | 10 | .8281 | .8691 | +.041 | .8541 |
| .9 | 7 | .8376 | .8978 | +.060 | .8703 |

Tek yönlü daha büyük (.9, n 6: +.083; .8, n 9: +.045). Eşik: iki yönlü rho >= .6, tek yönlü rho >= .5-.6 civarında fark > .02 olur. Plan 'r .8 n 10' ampirik .8637 (10.000 tekrar) tam .8691 ile uyumlu (SE .0034).

**Öneri.** `warn` kuralı yeterli; "analitik > ampirik" yönünde FAIL gerekmiyor. `pwr.r.test` (Fisher + düzeltme) tam güce daha yakın ama yine altında: karşılaştırma notu "farklı yöntem" doğru.

**11a değişikliği.**
1. Kod yorumu `sim_status`: `# Fisher-z power is below exact cor.test power for all planned n (checked on a grid, exact via noncentral t); only "pass" or "warn" can occur for the safe direction.`
2. Test (`skip_on_cran`): cor r .6 n 20 iki yönlü, `status == "warn"` ya da en az `pass` değil FAIL olmadığını sınasın; asıl sabit vaka r .8 n 10 `warn` zaten var. Önerilen ek vaka: r .5 n 30 iki yönlü -> `status` "pass" (fark ~.013). 
3. Yardım sayfası: "küçük n ve büyük |r|'de formül muhafazakârdır; r .6 n 20'den başlayarak fark > .02".

## 3. Denetçi sayıları (güven: yüksek)

- prop .10/.05, 1e5 tekrar (tohum 5, kendi koşum): p1>p2 **.81058**, p1<p2 **.81029**; denetçi .8106/.8103 doğrulandı. Tam güç .8095 (fark ≤ 1 SE).
- cor r .5 n 30 iki yönlü: denetçi 1e5 .8263; benim 2e5 .82788; tam .82769; pwrss .81442. Denetçinin sayısı 1,2 SE içinde tam değerle uyumlu; fark ~+.013 (planda .012).
- Plandaki r .8 n 10 (pwrss .8281) doğru; tam .8691, `pwr` .8541.

## 4. 11b açık maddeleri (güven: yüksek, kodla karşılaştırıldı)

- **`make_table`**: doğru. 2x2, 2x3, 3x3, 3x4, 5x5, 4x4, 2x10, 10x10 için marjinaller eşit (`all.equal` TRUE) ve `sqrt(sum((P-E)^2/E))` = 0.3 tam.
- **`w_max`**: formül doğru, değerler doğru (2x2 1, 2x3 .8165, 3x3 .6667, 3x4 .6086, 5x5 .5; ayrıca 4x4 .5556, 2x10 .6383, 10x10 .4074). `w = w_max`'ta en küçük hücre 0 ya da kayan nokta hatasıyla `-5e-17`: `rmultinom` hata verir, bu yüzden `min(P) > 0` kontrolü şart (taslak bunu söylüyor). `.99 * w_max`'ta en küçük hücre pozitif. Yan etki: plan `w <= 1`'e izin verir (R/tests.R `err_w`: `effect > 1`), yani 3x3'te w .7 planlanabilir ama simüle edilemez; `err_sim_table` metni "bu w bu örüntüyle bu tabloda" demeli (taslak zaten diyor). Test sabitleri: değerler `expect_equal(tolerance = 1e-4)` ile.
- **`pwr.f2.test` yeniden ölçekleme**: doğru. `f2 * n / (n - k + u)` ile `pwr.f2.test(u, v = n-k-1)`, `pwrss::power.f.reg` ile tam eşleşti: (ΔR² .10, cov .20, k 5, u 2, n 71) .8021 = .8021; (.05, .30, 4, 1, 150) .9214 = .9214; (.2, .1, 8, 3, 60) .932 = .932. Ölçeksiz f2 farklı (.7837, .9163, .9081): yani ölçekleme **gerekli**. `f2 = ΔR²/(1 - cov - ΔR²)` = `effect_test/(1-effect_test)` (kodda `effect_test = effect/(1-cov)`); taslaktaki `0.10/0.70` aynı. reg_overall (u = k) ölçeksiz doğru (.8000903 ikisinde).
- Küçük not: `plan_study` `verbose` argümanı almıyor (betiğimde hata verdi); testlerde `quiet_plan` kullanın (taslak zaten kullanıyor).

**11a/11b değişikliği.** 11b taslağında bir şey değişmez; "doğrulanmadı" ifadesi 11a planında `w_max`, `make_table`, `f2` ölçeklemesi için "doğrulandı (docs/research/2026-11-14-dilim-11-dogrulama.md)" olur.
