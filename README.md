# plansize

Plan and justify a study's sample size before you collect data.

plansize computes the sample size for common designs, adds dropout and
design-effect corrections, and writes a methods paragraph in English or
Turkish that you can paste into a protocol or paper. It does not do its own
power calculations: the numbers come from [pwrss](https://CRAN.R-project.org/package=pwrss),
and the test suite checks them against `stats::power.t.test()`,
`stats::power.prop.test()`, `pwr` and simulation.

The package works from functions in the R console or RStudio. It never asks
for raw data.

> Status: in development (0.0.0.9000). The API may still change. Not on CRAN.

## Installation

```r
# install.packages("remotes")
remotes::install_github("emresaglamci0/r-paketi")
```

## Supported designs

| `test` | Analysis | Effect size |
|---|---|---|
| `"t_independent"` | Independent two-sample t test | Cohen's d |
| `"t_paired"` | Paired t test | Cohen's d and the pre-post correlation `r` |
| `"anova_oneway"` | One-way ANOVA, `k` equal groups | Cohen's f or eta squared |
| `"prop_two"` | Two independent proportions | `p1`, `p2` |
| `"cor_pearson"` | Pearson correlation | r |
| `"chisq_indep"` | Chi-square test of independence | Cohen's w |
| `"reg_overall"` | Multiple regression, overall F test | R squared or f squared |
| `"reg_partial"` | Multiple regression, R squared change | R squared change or partial f squared |

`plan_precision()` plans the sample size to estimate one proportion with a
given margin of error (Cochran, with an optional finite population correction).

## Example

```r
library(plansize)

p <- plan_study("t_independent", effect = 0.5,
                effect_basis = "prior_study", dropout = 0.1)
p
#> Sample size to recruit per group (includes dropout and design effect): 71
#> Total sample size to recruit (includes dropout and design effect): 142
#> ...

write_methods(p, lang = "en")
#> An a priori power analysis was conducted in R with the plansize package ...
#> the required sample size was 64 participants per group (128 in total).
#> Allowing for an expected dropout rate of 10%, the recruitment target was
#> 71 participants per group (142 in total).

sensitivity(p)            # smallest detectable effect at 80, 90 and 95% power
simulate_power(p, seed = 1)  # check the analytic power by simulation

plan_precision(p = 0.5, e = 0.05, N = 2000)
#> Required sample size: 323
```

## Functions

- `plan_study()`: sample size for one of the designs above.
- `plan_precision()`: sample size for the precision of one proportion.
- `write_methods()`: methods paragraph in English (`"en"`) or Turkish (`"tr"`).
- `sensitivity()`: smallest effect the planned sample can detect.
- `simulate_power()`: empirical power by simulation, compared with the formula.

## Where the effect size comes from

Every plan records `effect_basis`: `"prior_study"`, `"pilot"`,
`"smallest_of_interest"`, `"convention"` or `"unknown"` (the default, which
warns). `"observed"` is rejected: power computed from the effect you observed
in your own data says nothing new. Use `sensitivity()` after the study instead.

## Known limitations

- Regression plans assume fixed predictors. With random predictors (most
  observational studies) power is a little lower. For `"reg_overall"` the
  printout also shows the random-predictor n when the `DMAR` package is
  installed. `"reg_partial"` does not show it yet.
- No warning yet for effect sizes from small pilots, which are very noisy.
- No warning yet for unrealistically large n.

## License

MIT
