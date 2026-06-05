# R/sewer.R

validate_cso_outfall <- function(cso_outfall) {
  assert_crs(cso_outfall, 2263)
  assert_row_count(cso_outfall, min = 1, max = 200)
  assert_no_na(cso_outfall, c("Waterbody", "Waterbod_1"))
  assert_valid_geom(cso_outfall)

  if (!all(st_geometry_type(cso_outfall) == "POINT")) {
    stop("Unexpected geometry type (expected POINT)")
  }

  TRUE
}

validate_sewer_areas <- function(sewer_areas) {
  assert_crs(sewer_areas, 2263)
  assert_row_count(sewer_areas, min = 1, max = 20)
  assert_no_na(sewer_areas, "COMB_OR_SE")
  assert_valid_geom(sewer_areas)

  if (!all(st_geometry_type(sewer_areas) %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("Unexpected geometry type (expected POLYGON/MULTIPOLYGON)")
  }

  TRUE
}
