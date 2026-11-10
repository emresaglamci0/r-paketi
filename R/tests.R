# Per-test differences live here; engine, plan and sensitivity read this table.
test_spec <- list(
  t_independent = list(design = "independent", groups = 2L, min_n = 3),
  t_paired = list(design = "paired", groups = 1L, min_n = 4)
)
