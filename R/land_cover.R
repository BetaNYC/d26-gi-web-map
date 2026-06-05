# R/land_cover.R

validate_lc <- function(nta_df, cd_df) {
  expected_lc_cols <- c("pct_tree_canopy",
                        "pct_permeable_surface")
  
  # Adapted helpers from R/validate.R
  assert_no_na(nta_df, expected_lc_cols)
  assert_no_na(cd_df, expected_lc_cols)

  
  missing_nta_cols <- setdiff(expected_lc_cols, names(nta_df))
  missing_cd_cols <- setdiff(expected_lc_cols, names(cd_df))
  
  if (length(missing_nta_cols) > 0) {
    stop(paste0("Missing columns in NTA dataframe: ", paste(missing_nta_cols, collapse = ", ")))
  }
  
  if (length(missing_cd_cols) > 0) {
    stop(paste0("Missing columns in Council District dataframe: ", paste(missing_cd_cols, collapse = ", ")))
  }
  
  TRUE
}