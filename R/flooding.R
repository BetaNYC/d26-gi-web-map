# R/flooding.R

# FEMA NFHL

# Use FEMA ESRI Map Server Endpoint, layer ID 28
# Corresponds to S_Fld_Haz_Ar table
# Using bounding box avoids pain of converting to ESRI's geometry spec

get_nfhl <- function(bbox) {
  fema_url <- parse_url("https://hazards.fema.gov/arcgis/rest/services")

  fema_url$path <- "arcgis/rest/services/public/NFHLWMS/MapServer/28/query"

  fema_url$query <- list(
    geometry = paste(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax, sep = ","),
    geometryType = "esriGeometryEnvelope",
    spatialRel = "esriSpatialRelIntersects",
    inSR = "4326",
    outSR = "2263",
    outFields = "*",
    f = "geojson"
  )

  request <- build_url(fema_url)

  read_sf(request) |>
    st_make_valid()
}

# Code is based on ONLY three flood regimes present in bounding box:
# FLD_ZONE: AE & ZONE_SUBTY: NA (100 Year Flood plane)
# FLD_ZONE: X & ZONE_SUBTY: 0.2 PCT ANNUAL CHANCE FLOOD HAZARD (500 Year Flood Plane)
# FLD_ZONE: X & ZONE_SUBTY: AREA OF MINIMAL FLOOD HAZARD

validate_nfhl <- function(nfhl) {
  expected_groups <- tribble(
    ~FLD_ZONE, ~ZONE_SUBTY,
    "AE", NA_character_,
    "X", "0.2 PCT ANNUAL CHANCE FLOOD HAZARD",
    "X", "AREA OF MINIMAL FLOOD HAZARD"
  )

  actual_groups <- nfhl |>
    st_drop_geometry() |>
    distinct(FLD_ZONE, ZONE_SUBTY)

  missing <- anti_join(expected_groups, actual_groups, by = c("FLD_ZONE", "ZONE_SUBTY"))
  extra   <- anti_join(actual_groups, expected_groups, by = c("FLD_ZONE", "ZONE_SUBTY"))

  if (nrow(missing) > 0 || nrow(extra) > 0) {
    stop(paste0(
      "FEMA NFHL groups don't match expected. ",
      "Missing: ", nrow(missing), ". ",
      "Unexpected: ", nrow(extra), "."
    ))
  }

  TRUE
}

nfhl_recode <- function(nfhl) {
  nfhl |>
    group_by(FLD_ZONE, ZONE_SUBTY) |>
    summarize(.groups = "drop") |>
    filter(ZONE_SUBTY != "AREA OF MINIMAL FLOOD HAZARD" | is.na(ZONE_SUBTY)) |>
    mutate(flood_plane = case_when(FLD_ZONE == "AE" ~ "100-year",
                                   FLD_ZONE == "X" ~ "500-year"))
}

validate_nfhl_recoded <- function(nfhl_recoded) {
  assert_crs(nfhl_recoded, 2263)
  assert_row_count(nfhl_recoded, min = 2, max = 2)
  assert_no_na(nfhl_recoded, "flood_plane")
  assert_valid_geom(nfhl_recoded)

  TRUE
}

# Intersection of one flood plane with d26_zctas 
# Returns one row per ZCTAs that intersects the flood plane
# The geometry is the per-ZCTA clipped polygon used
# for PMTiles output and for per-ZCTA area aggregation.
nfhl_intersected <- function(nfhl_recoded, d26_zctas, plane) {
  nfhl_recoded |>
    filter(flood_plane == plane) |>
    st_intersection(d26_zctas) |>
    mutate(area_sqft = units::drop_units(st_area(geometry)))
}

# Per-ZCTA percentage of area in each flood plane
# left_join back to d26_zctas so ZCTAs with zero coverage get an explicit 0
# rather than being dropped using coalesce(..., 0)
nfhl_per_zcta <- function(d26_zctas, nfhl_100yr_d26_zctas, nfhl_500yr_d26_zctas) {
  zcta_areas <- tibble(
    ZCTA5 = d26_zctas$ZCTA5,
    zcta_area_sqft = units::drop_units(st_area(d26_zctas))
  )

  area_100 <- nfhl_100yr_d26_zctas |>
    st_drop_geometry() |>
    group_by(ZCTA5) |>
    summarize(area_100 = sum(area_sqft), .groups = "drop")

  area_500 <- nfhl_500yr_d26_zctas |>
    st_drop_geometry() |>
    group_by(ZCTA5) |>
    summarize(area_500 = sum(area_sqft), .groups = "drop")

  zcta_areas |>
    left_join(area_100, by = "ZCTA5") |>
    left_join(area_500, by = "ZCTA5") |>
    mutate(
      pct_100_year = coalesce(area_100, 0) / zcta_area_sqft * 100,
      pct_500_year = coalesce(area_500, 0) / zcta_area_sqft * 100
    ) |>
    select(ZCTA5, pct_100_year, pct_500_year)
}

# FVI

get_fvi <- function(wkt) {
  soc_read(
    "https://data.cityofnewyork.us/Environment/New-York-City-s-Flood-Vulnerability-Index/mrjc-v9pm.json",
    query = soc_query(
      select = "fshri, geoid, the_geom",
      where = paste0(
        "intersects(the_geom, '",
        wkt,
        "')"
      )
    ),
    include_synthetic_cols = FALSE
  ) |>
    st_transform(2263)
}

validate_fvi <- function(fvi) {
  assert_crs(fvi, 2263)
  assert_row_count(fvi, min = 50, max = 5000)
  assert_no_na(fvi, "fshri")
  assert_valid_geom(fvi)

  # fshri arrives from Socrata as character 
  # The integer cast must not introduce NAs
  cast <- suppressWarnings(as.integer(fvi$fshri))
  if (any(is.na(cast))) {
    stop(paste0(sum(is.na(cast)), " values of fshri are not castable to integer"))
  }

  TRUE
}

# Per-ZCTA mean FVI score. 
# Assign each FVI feature to whichever zcta it intersects with most 
# (via st_join(..., largest = TRUE)), then take the mean 

fvi_per_zcta <- function(d26_zctas, fvi) {
  fvi |>
    st_join(d26_zctas |> select(ZCTA5),
            largest = TRUE) |>
    st_drop_geometry() |>
    group_by(ZCTA5) |>
    summarize(mean_fshri = mean(as.integer(fshri), na.rm = TRUE), .groups = "drop") |>
    right_join(
      tibble(ZCTA5 = d26_zctas$ZCTA5),
      by = "ZCTA5"
    )
}

# Stormwater flooding

validate_swf <- function(swf) {
  assert_crs(swf, 2263)
  assert_valid_geom(swf)

  if (!all(st_geometry_type(swf) %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("Unexpected geometry type (expected POLYGON/MULTIPOLYGON)")
  }

  TRUE
}

# Percent of each ZCTA's area covered by the union of a polygon layer. 
# The st_union collapses the input to a single geometry first so the
# intersection result has at most one row per intersecting ZCTA left_join
# back to d26_zctas so zero-coverage ZCTA get 0 using coalesce(..., 0).

swf_per_zcta <- function(d26_zctas, swf_polygons, col_name) {
  intersection_areas <- st_intersection(d26_zctas, st_union(swf_polygons)) |>
    mutate(area_sqft = units::drop_units(st_area(geometry))) |>
    st_drop_geometry() |>
    select(ZCTA5, area_sqft)

  zcta_areas <- tibble(
    ZCTA5 = d26_zctas$ZCTA5,
    zcta_area_sqft = units::drop_units(st_area(d26_zctas))
  )

  result <- zcta_areas |>
    left_join(intersection_areas, by = "ZCTA5") |>
    mutate(pct = coalesce(area_sqft, 0) / zcta_area_sqft * 100) |>
    select(ZCTA5, pct)

  names(result)[2] <- col_name
  result
}
