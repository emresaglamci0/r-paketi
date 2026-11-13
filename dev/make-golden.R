# Rebuild golden output. Run only from code whose behavior is the reference.
devtools::load_all(".", quiet = TRUE)
source("tests/testthat/helper-plan.R")
source("tests/testthat/helper-golden.R")
saveRDS(golden_build(), "tests/testthat/fixtures/golden.rds", version = 3)
