# R/ranking.R

# The columns that get ranked into 1-5 bins
rank_cols <- c(
  "n_gi_sqmi",
  "n_cb_sqmi",
  "n_flooding_311_p10k",
  "mean_fshri",
  "limited_swf_pct",
  "moderate_swf_pct",
  "pct_100_year",
  "pct_500_year",
  "pct_tree_canopy",
  "pct_permeable_surface"
)

# Join per-ZCTA aggregation tibbles onto sf object 
# sf object already carries land cover via d26_zctas_lc
join_aggregations <- function(d26_zctas_lc,
                              gi_per_zcta_tbl,
                              cb_per_zcta_tbl,
                              flooding_311_per_zcta_tbl,
                              fvi_per_zcta_tbl,
                              nfhl_per_zcta_tbl,
                              swf_limited_per_zcta_tbl,
                              swf_moderate_per_zcta_tbl) {
  d26_zctas_lc |>
    left_join(gi_per_zcta_tbl, by = "ZCTA5") |>
    left_join(cb_per_zcta_tbl, by = "ZCTA5") |>
    left_join(flooding_311_per_zcta_tbl, by = "ZCTA5") |>
    left_join(fvi_per_zcta_tbl, by = "ZCTA5") |>
    left_join(nfhl_per_zcta_tbl, by = "ZCTA5") |>
    left_join(swf_limited_per_zcta_tbl, by = "ZCTA5") |>
    left_join(swf_moderate_per_zcta_tbl, by = "ZCTA5")
}

# D26 aggregations, no ranking
aggregate_d26 <- function(d26_lc,
                          gi_all_assets,
                          cb,
                          flooding_311,
                          fvi,
                          nfhl_recoded,
                          swf_limited,
                          swf_moderate) {
  d26_area_sqft <- units::drop_units(st_area(d26_lc))

  n_gi <- lengths(st_intersects(d26_lc, gi_all_assets))
  n_cb <- lengths(st_intersects(d26_lc, cb))
  n_311 <- lengths(st_intersects(d26_lc, flooding_311))

  # For mean FVI in D26, don't need to use st_join(..., largest = TRUE)
  # since there's only a single district feature -- FVI tracts won't be double-counted
  mean_fshri <- fvi |>
    st_join(d26_lc |> select(CounDist), left = FALSE) |>
    st_drop_geometry() |>
    summarize(mean_fshri = mean(as.integer(fshri), na.rm = TRUE)) |>
    pull(mean_fshri)

  swf_limited_pct <- units::drop_units(
    st_area(st_intersection(st_union(swf_limited), d26_lc)) / st_area(d26_lc) * 100
  ) |> sum()

  swf_moderate_pct <- units::drop_units(
    st_area(st_intersection(st_union(swf_moderate), d26_lc)) / st_area(d26_lc) * 100
  ) |> sum()

  # NFHL -- filter to single recoded flood regime, then intersect with d26, 
  # sum the resulting areas
  pct_for_plane <- function(plane) {
    intersection <- nfhl_recoded |>
      filter(flood_plane == plane) |>
      st_intersection(d26_lc)
    sum(units::drop_units(st_area(intersection))) / d26_area_sqft * 100
  }

  d26_lc |>
    st_drop_geometry() |>
    mutate(
      n_gi = n_gi,
      n_gi_sqmi = n_gi / d26_area_sqft * 27878400, # sq ft to sq mi
      n_cb = n_cb,
      n_cb_sqmi = n_cb / d26_area_sqft * 27878400,
      n_flooding_311 = n_311,
      n_flooding_311_p10k = n_311 / d26_pop * 10000,
      mean_fshri = mean_fshri,
      limited_swf_pct = swf_limited_pct,
      moderate_swf_pct = swf_moderate_pct,
      pct_100_year = pct_for_plane("100-year"),
      pct_500_year = pct_for_plane("500-year")
    )
}

# Ranking -- 5 equal-width bins
compute_zcta_ranks <- function(d26_zctas_aggregated) {
  d26_zctas_aggregated |>
    st_drop_geometry() |>
    select(ZCTA5, all_of(rank_cols)) |>
    mutate(across(
      all_of(rank_cols),
      ~ as.integer(cut(., breaks = 5, include_lowest = TRUE, labels = FALSE)),
      .names = "rank_{.col}"
    )) |>
    select(ZCTA5, starts_with("rank_"))
}

validate_d26_zcta_ranks <- function(d26_zcta_ranks) {
  ranked_cols <- setdiff(names(d26_zcta_ranks), "ZCTA5")

  for (col in ranked_cols) {
    vals <- d26_zcta_ranks[[col]]
    if (any(is.na(vals))) {
      stop(paste0("rank column '", col, "' has ", sum(is.na(vals)), " NA values for ranked ZCTAs"))
    }
    if (!all(vals %in% 1:5)) {
      bad <- unique(vals[!vals %in% 1:5])
      stop(paste0("rank column '", col, "' has values outside 1-5: ", paste(bad, collapse = ", ")))
    }
  }

  TRUE
}

# Final attribute tibble with ranks, no geometry
build_d26_zctas_attrs <- function(d26_zctas_aggregated, d26_zcta_ranks) {
  d26_zctas_aggregated |>
    st_drop_geometry() |>
    left_join(d26_zcta_ranks, by = "ZCTA5")
}

# Build the D26-level attribute tibble
build_d26_attrs <- function(d26_aggregated) {
  d26_aggregated
}

validate_d26_zctas_attrs <- function(d26_zctas_attrs) {
  # Per-ZCTA aggregations should produce finite values

  for (col in rank_cols) {
    vals <- d26_zctas_attrs[[col]]
    if (any(!is.finite(vals))) {
      stop(paste0("column '", col, "' has ", sum(!is.finite(vals)),
                  " non-finite values among ranked ZCTAs"))
    }
  }

  # Every ZCTA should have all ten rank columns populated 1-5
  for (col in paste0("rank_", rank_cols)) {
    vals <- d26_zctas_attrs[[col]]
    if (any(is.na(vals))) {
      stop(paste0("rank column '", col, "' has NA values for ranked ZCTAs"))
    }
    if (!all(vals %in% 1:5)) {
      stop(paste0("rank column '", col, "' has values outside 1-5"))
    }
  }

  TRUE
}

validate_d26_attrs <- function(d26_attrs) {
  expected_cols <- c("CounDist", "d26_pop",
                     "n_gi", "n_gi_sqmi",
                     "n_cb", "n_cb_sqmi",
                     "n_flooding_311", "n_flooding_311_p10k",
                     "mean_fshri",
                     "limited_swf_pct", "moderate_swf_pct",
                     "pct_100_year", "pct_500_year",
                     "pct_tree_canopy", "pct_permeable_surface")

  missing <- setdiff(expected_cols, names(d26_attrs))
  if (length(missing) > 0) {
    stop(paste0("Missing columns in d26_attrs: ", paste(missing, collapse = ", ")))
  }

  if (nrow(d26_attrs) != 1) {
    stop(paste0("d26_attrs should have 1 row, has ", nrow(d26_attrs)))
  }

  TRUE
}
