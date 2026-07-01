# R/flooding_311.R

get_311 <- function(path) {
  read_sf(path) |> 
    st_transform(2263)
}

# Adapted helpers from R/validate.R
validate_311 <- function(df_311) {
  assert_crs(df_311, 2263)
  assert_row_count(df_311, min = 3000, max = 30000)
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

hotspot_raster <- function(df_311, d26_zctas, path) {
  # Generate point process object
  pp <- as.ppp(st_coordinates(df_311),
               as.owin(d26_zctas))
  
  # Get kernel density from point process object
  # The bandwith parameter sigma was determined manually
  
  d <- stats::density(pp, sigma = 400)
  
  # Convert to terra raster
  r <- rast(d)
  
  # Assign CRS using authority:code
  crs(r) <- "epsg:2263"
  
  # Set hotspot threshold for visualization to >= median density estimation + 1.5x std. dev.
  threshold <- median(values(r), na.rm = T) + (1.5 * sd(values(r), na.rm = T))
  
  r[r <= threshold] <- NA

  # Write a Cloud Optimized GeoTIFF and return the path
  writeRaster(r, 
              path, 
              filetype = "COG", 
              overwrite = TRUE,
              gdal = c("COMPRESS=DEFLATE",
                       "PREDICTOR=2",
                       "TARGET_SRS=EPSG:3857",
                       "RESAMPLING=NEAREST",
                       "BLOCKSIZE=256",
                       "OVERVIEWS=IGNORE_EXISTING",
                       "OVERVIEW_RESAMPLING=NEAREST"))
  path
}

validate_raster <- function(path, expected_epsg) {
  r <- rast(path)

  # Check CRS
  r_crs <- crs(r, describe = TRUE)
  
  if (r_crs$code != as.character(expected_epsg)) {
    stop(paste0("CRS: expected EPSG:", expected_epsg, ", got EPSG:", r_crs$code))
  }
  
  # Ensure there are non-NA values
  if (sum(values(r), na.rm = T) == 0) {
    stop(paste0("No non-NA values present in raster."))
  }
  
  # Return TRUE if all checks pass
  TRUE
}