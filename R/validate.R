# R/validate.R

# Shared, generic helpers check a single property
# stop() accompanied by a diagnostic message

assert_crs <- function(x, expected_epsg) {
  actual <- st_crs(x)$epsg
  if (is.na(actual) || actual != expected_epsg) {
    stop(paste0("CRS: expected EPSG:", expected_epsg, ", got EPSG:", actual))
  }
}

assert_row_count <- function(x, min, max) {
  n <- nrow(x)
  if (n < min || n > max) {
    stop(paste0("Row count: ", n, ", expected ", min, "-", max))
  }
}

assert_no_na <- function(x, cols) {
  for (col in cols) {  
    n_na <- sum(is.na(x[[col]]))
    if (n_na > 0) {
      stop(paste0("Column '", col, "' has ", n_na, " NA values"))
    }
  }
}

assert_col_type <- function(x, col, expected_type) {
  actual <- class(x[[col]])[1]
  if (actual != expected_type) {
    stop(paste0("Column '", col, "': expected ", expected_type, ", got ", actual))
  }
}

assert_valid_geom <- function(x) {
  if (!all(st_is_valid(x))) {
    stop(paste0(sum(!st_is_valid(x)), " invalid geometries"))
  }
}