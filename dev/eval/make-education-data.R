# Synthetic secondary-school dataset used as a "population" for plansize evaluation.
make_education_data <- function(n = 500, seed = 20261115) {
  set.seed(seed)
  lik <- function(x) pmin(pmax(round(x * 4) / 4, 1), 5)
  # shared latent structure: ability, motivation, self-efficacy, anxiety, effort
  S <- matrix(c(1,   .3,  .3, -.2,  .3,
                .3,  1,   .5, -.3,  .4,
                .3,  .5,  1,  -.4,  .3,
               -.2, -.3, -.4,  1,  -.1,
                .3,  .4,  .3, -.1,  1), 5, 5)
  Z <- MASS::mvrnorm(n, rep(0, 5), S)
  ab <- Z[, 1]; mo <- Z[, 2]; ef <- Z[, 3]; ka <- Z[, 4]; ca <- Z[, 5]

  okul <- sample(c("devlet", "ozel", "meslek"), n, TRUE, c(.5, .3, .2))
  ders_disi <- rbinom(n, 1, c(devlet = .30, ozel = .55, meslek = .30)[okul])
  ozel_ders <- rbinom(n, 1, plogis(-.7 + .3 * ab + .3 * (okul == "ozel")))
  sch <- c(devlet = 0, ozel = 4, meslek = -3)[okul]

  mat_on <- 50 + 10 * (ab + 0.3 * rnorm(n)) / 1.1 + sch * 0.5
  mat_son <- 52.9 + 0.6 * (mat_on - 50) + 1.8 * mo + 1.8 * ef - 1.2 * ka + 1.0 * ca +
    0.5 * sch + 2.0 * ozel_ders + rnorm(n, 0, 8)
  calisma <- exp(0.9 + 0.5 * ca + rnorm(n, 0, 0.3))
  devam <- rpois(n, exp(1.3 - 0.35 * mo - 0.1 * ab))
  gecti <- rbinom(n, 1, plogis(0.35 + 0.04 * (mat_son - 52) + 0.75 * ozel_ders))

  data.frame(
    ogrenci_id = seq_len(n),
    cinsiyet = factor(sample(c("K", "E"), n, TRUE), levels = c("K", "E")),
    sinif = sample(9:12, n, TRUE),
    okul_turu = factor(okul, levels = c("devlet", "ozel", "meslek")),
    anne_egitim_yil = pmin(pmax(round(8 + 2 * ab * 0.3 + sch * 0.3 + rnorm(n, 0, 3)), 0), 18),
    calisma_saati = round(calisma, 2),
    devamsizlik = devam,
    ders_disi = factor(c("hayir", "evet")[ders_disi + 1], levels = c("hayir", "evet")),
    ozel_ders = factor(c("hayir", "evet")[ozel_ders + 1], levels = c("hayir", "evet")),
    motivasyon = lik(3 + 0.7 * mo + rnorm(n, 0, 0.25)),
    oz_yeterlik = lik(3 + 0.7 * ef + rnorm(n, 0, 0.25)),
    sinav_kaygisi = lik(3 + 0.7 * ka + rnorm(n, 0, 0.25)),
    mat_on = round(mat_on, 1),
    mat_son = round(mat_son, 1),
    gecti = gecti
  )
}

if (sys.nframe() == 0) {
  d <- make_education_data()
  write.csv(d, "docs/eval/egitim-500.csv", row.names = FALSE)
}
