# R/output.R

# Client-specified displayed GI asset types. Used to filter the GI PMTiles output
gi_selected_features <- c(
  "Combined Blue/Green Roof",
  "Drywell",
  "Green Roof",
  "Rain Garden",
  "Rainwater Harvesting",
  "Synthetic Turf Field Storage Layer",
  "Permeable Pavers"
)

# Shared PMTiles writer. freestile is the in-package wrapper around tippecanoe
# Returns the path so the calling tar_target(format = "file") caches
write_pmtiles <- function(data, path, layer_name = NULL) {
  freestiler::freestile(
    data,
    path,
    layer_name = layer_name,
    min_zoom = 9,
    max_zoom = 20
  )
  path
}

# Parquet writers
write_d26_zctas_attrs_parquet <- function(d26_zctas_attrs, path) {
  arrow::write_parquet(d26_zctas_attrs, path)
  path
}

write_d26_attrs_parquet <- function(d26_attrs, path) {
  arrow::write_parquet(d26_attrs, path)
  path
}

# Boundary PMTiles
write_d26_pmtiles <- function(d26, path) {
  write_pmtiles(d26 |> select(CounDist), path, layer_name = "council-district")
}

write_d26_zctas_pmtiles <- function(d26_zctas, path) {
  write_pmtiles(d26_zctas |> select(ZCTA5), path, layer_name = "zctas")
}

# Sewer PMTiles
write_cso_outfalls_pmtiles <- function(cso_outfall, path) {
  write_pmtiles(cso_outfall |> select(Waterbody, Waterbod_1), path)
}

write_sewer_areas_pmtiles <- function(sewer_areas, path) {
  write_pmtiles(sewer_areas |> select(COMB_OR_SE), path)
}

# Catch basins PMTiles
write_catch_basins_pmtiles <- function(cb, path) {
  write_pmtiles(cb |> select(unitid), path)
}

# GI display PMTiles — filtered to the client-specified asset types
write_gi_display_pmtiles <- function(gi_all_assets, path) {
  display <- gi_all_assets |>
    select(asset_type, constructed_date) |>
    filter(asset_type %in% gi_selected_features)
  write_pmtiles(display, path)
}

# Stormwater flooding PMTiles
write_swf_limited_pmtiles <- function(swf_limited, path) {
  write_pmtiles(swf_limited |> select(Flooding_C), path)
}

write_swf_moderate_pmtiles <- function(swf_moderate, path) {
  write_pmtiles(swf_moderate |> select(Flooding_C), path)
}

# NFHL PMTiles (the intersected geometries already carry flood_plane)
write_nfhl_100yr_pmtiles <- function(nfhl_100yr_d26_zctas, path) {
  write_pmtiles(nfhl_100yr_d26_zctas |> group_by(flood_plane) |> summarize(), path)
}

write_nfhl_500yr_pmtiles <- function(nfhl_500yr_d26_zctas, path) {
  write_pmtiles(nfhl_500yr_d26_zctas |> group_by(flood_plane) |> summarize(), path)
}
