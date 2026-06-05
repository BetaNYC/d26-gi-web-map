# R/flooding_311.R

get_311 <- function(path) {
  read_sf(path) |> 
    st_transform(2263)
}

# Adapted helpers from R/validate.R
validate_311 <- function(df_311) {
  assert_crs(df_311, 2263)
  assert_row_count(df_311, min = 10, max = 5000)
  assert_no_na(df_311, "descriptor")
  assert_valid_geom(df_311)
  
  # Should all be point features
  if (!all(st_geometry_type(df_311) == "POINT")) {
    stop("Unexpected geometry type (expected POINT)")
  }
  
  # Data is produced outside pipeline, check to see if expected columns are present
  expected_cols <- c("created_date",
                     "closed_date",
                     "agency",
                     "descriptor",
                     "geometry")
  
  missing <- setdiff(expected_cols, names(df_311))
  
  if (length(missing) > 0) {
    stop(paste0("Missing columns in 311 data: ", paste(missing, collapse = ", ")))
  } 
  
  # Return TRUE if all checks pass
  TRUE
}

# Per-ZCTA 311 counts and rate per 10k residents.
# If ZCTAs have nta_pop == 0 their per-capita value is NA rather than Inf
flooding_311_per_zcta <- function(d26_zctas, flooding_311) {
  counts <- lengths(st_intersects(d26_zctas, flooding_311))

  tibble(
    ZCTA5 = d26_zctas$ZCTA5,
    n_flooding_311 = counts,
    n_flooding_311_p10k = ifelse(
      d26_zctas$POP100 == 0,
      NA_real_,
      counts / d26_zctas$POP100 * 10000
    )
  )
}