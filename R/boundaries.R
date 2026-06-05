# R/boundaries.R

get_wkt <- function(data) {
  data |> 
    st_union() |> 
    st_transform(4326) |> 
    st_geometry() |> 
    st_as_text()
}

get_bbox <- function(data) {
  data |>
    st_transform(4326) |> 
    st_bbox()
}

validate_d26_zctas <- function(d26_zctas) {
  # Adapted helpers from R/validate.R
  assert_crs(d26_zctas, 2263)
  assert_row_count(d26_zctas, min = 5, max = 10)
  assert_no_na(d26_zctas, "ZCTA5")
  assert_no_na(d26_zctas, "POP100")
  assert_col_type(d26_zctas, "ZCTA5", "character")
  assert_col_type(d26_zctas, "POP100", "integer")
  assert_valid_geom(d26_zctas)
  
  # Specific checks
  
  # Ranked zctas should have positive population
  if (any(d26_zctas$POP100 <= 0)) {
    stop("One or more ZCTAs have POP100 <= 0")
  }
  
  # All geometries should be valid
  if (!all(st_is_valid(d26_zctas))) {
    stop(paste0(sum(!st_is_valid(d26_zctas)), " invalid geometries"))
  }
  
  # There should not be any point features
  if (!all(st_geometry_type(d26_zctas) %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("Unexpected geometry type (expected POLYGON/MULTIPOLYGON)")
  }
  
  # Return TRUE if all checks pass
  TRUE
}

validate_d26 <- function(d26) {
  assert_crs(d26, 2263)
  assert_row_count(d26, 1, 1)
  assert_no_na(d26, "CounDist")
  assert_no_na(d26, "cd_pop")
  assert_valid_geom(d26)
  
  # Check for correct district
  if (d26$CounDist != 26) {
    stop(paste0("Council District 26 expected, actual Council District: ", d26$CounDist))
  }
  
  # CD should have positive population
  if (d26$d26_pop <= 0) {
    stop("Council District population should be > 0")
  }
  
  # There should not be any point features
  if (!st_geometry_type(d26) %in% c("POLYGON", "MULTIPOLYGON")) {
    stop("Unexpected geometry type (expected POLYGON/MULTIPOLYGON)")
  }
  
  TRUE
}