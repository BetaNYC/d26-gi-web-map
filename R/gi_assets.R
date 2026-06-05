# R/gi_assets.R

get_gi <- function(wkt) {
  # Suppress the warning about uninitialized columns from the Socrata side
  suppressWarnings(
    soc_read(
      "https://data.cityofnewyork.us/Environment/DEP-Green-Infrastructure-Map-All-Layers-/h3ce-uahi.json",
      query = soc_query(
        select = "asset_type, constructed_date, the_geom",
        where =
          paste0(
            "within_polygon(the_geom, '",
            wkt,
            "')"
          )
      ),
      include_synthetic_cols = FALSE
    )
  ) |> 
    st_transform(2263)
}

validate_gi <- function(gi_df) {
  # Adapt helpers from R/validate.R
  assert_crs(gi_df, 2263)
  assert_row_count(gi_df, min = 25, max = 2500)
  assert_no_na(gi_df, "asset_type")
  assert_valid_geom(gi_df)
  
  # Return TRUE if all checks pass
  TRUE
}

get_cb <- function(wkt) {
  soc_read(
    "https://data.cityofnewyork.us/Environment/NYCDEP-Citywide-Catch-Basins/2w2g-fk3i.geojson",
    query = soc_query(
      select = "the_geom, unitid",
      where = paste0(
        "within_polygon(the_geom, '",
        wkt,
        "')"
      )
    ),
    include_synthetic_cols = FALSE
  ) |>
    st_transform(2263)
}

validate_cb <- function(cb_df) {
  assert_crs(cb_df, 2263)
  assert_row_count(cb_df, min = 2500, max = 8000)
  assert_no_na(cb_df, "unitid")
  assert_valid_geom(cb_df)

  TRUE
}

# Per-ZCTA GI counts 
gi_per_zcta <- function(d26_zctas, gi_all_assets) {
  counts <- lengths(st_intersects(d26_zctas, gi_all_assets))
  areas_sqft <- units::drop_units(st_area(d26_zctas$geometry))

  tibble(
    ZCTA5 = d26_zctas$ZCTA5,
    n_gi = counts,
    n_gi_sqmi = counts / areas_sqft * 27878400
  )
}

# Per-NTA catch basin counts
cb_per_zcta <- function(d26_zctas, cb) {
  counts <- lengths(st_intersects(d26_zctas, cb))
  areas_sqft <- units::drop_units(st_area(d26_zctas$geometry))

  tibble(
    ZCTA5 = d26_zctas$ZCTA5,
    n_cb = counts,
    n_cb_sqmi = counts / areas_sqft * 27878400
  )
}