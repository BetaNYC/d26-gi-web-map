# _targets.R

library(targets)
library(tarchetypes)

tar_option_set(
  packages = c("sf",
               "socratadata",
               "terra",
               "httr",
               "dplyr",
               "tibble",
               "units",
               "arrow",
               "freestiler",
               "spatstat"),
  format = "qs"
)

# Source the scripts in R/
tar_source()

list(
  ## Boundaries 
  tar_target(d26_path, "data/prepared/d26.parquet", format = "file"),
  tar_target(d26_zctas_path, "data/prepared/d26_zctas.parquet", format = "file"),
  tar_target(d26, read_sf(d26_path)),
  tar_target(d26_zctas, read_sf(d26_zctas_path)),
  tar_target(d26_checks, validate_d26(d26)),
  tar_target(d26_zcta_checks, validate_d26_zctas(d26_zctas)),
  tar_target(wkt_d26_zctas, get_wkt(d26_zctas)),
  tar_target(bbox_d26_zctas, get_bbox(d26_zctas)),

  ## Green Infrastructure 
  tar_age(gi_all_assets, get_gi(wkt_d26_zctas), age = as.difftime(14, units = "days")),
  tar_target(gi_all_assets_checks, validate_gi(gi_all_assets)),
  tar_age(cb, get_cb(wkt_d26_zctas), age = as.difftime(30, units = "days")),
  tar_target(cb_checks, validate_cb(cb)),
  tar_target(gi_per_zcta_tbl, gi_per_zcta(d26_zctas, gi_all_assets)),
  tar_target(cb_per_zcta_tbl, cb_per_zcta(d26_zctas, cb)),

  ## 311 
  tar_target(flooding_311_path, "data/prepared/flooding_311.geojson", format = "file"),
  tar_target(flooding_311, get_311(flooding_311_path)),
  tar_target(flooding_311_checks, validate_311(flooding_311)),
  tar_target(hotspot_311_raster_path,
             hotspot_raster(flooding_311, d26_zctas, "data/processed/hotspot_311.tif"),
             format = "file"),
  tar_target(hotspot_raster_checks, validate_raster(hotspot_311_raster_path, 3857)),
  tar_target(flooding_311_per_zcta_tbl, flooding_311_per_zcta(d26_zctas, flooding_311)),

  ## Flood
  tar_target(nfhl, get_nfhl(bbox_d26_zctas)),
  tar_target(nfhl_checks, validate_nfhl(nfhl)),
  tar_target(nfhl_recoded, nfhl_recode(nfhl)),
  tar_target(nfhl_recoded_checks, validate_nfhl_recoded(nfhl_recoded)),
  tar_target(nfhl_100yr_d26_zctas, nfhl_intersected(nfhl_recoded, d26_zctas, "100-year")),
  tar_target(nfhl_500yr_d26_zctas, nfhl_intersected(nfhl_recoded, d26_zctas, "500-year")),
  tar_target(nfhl_per_zcta_tbl, nfhl_per_zcta(d26_zctas, nfhl_100yr_d26_zctas, nfhl_500yr_d26_zctas)),

  tar_age(fvi, get_fvi(wkt_d26_zctas), age = as.difftime(180, units = "days")),
  tar_target(fvi_checks, validate_fvi(fvi)),
  tar_target(fvi_per_zcta_tbl, fvi_per_zcta(d26_zctas, fvi)),

  tar_target(swf_limited_path,
             "data/prepared/stormwater_flooding_limited_d26_zctas.parquet",
             format = "file"),
  tar_target(swf_limited, read_sf(swf_limited_path)),
  tar_target(swf_limited_checks, validate_swf(swf_limited)),
  tar_target(swf_limited_per_zcta_tbl, swf_per_zcta(d26_zctas, swf_limited, "limited_swf_pct")),

  tar_target(swf_moderate_path,
             "data/prepared/stormwater_flooding_moderate_d26_zctas.parquet",
             format = "file"),
  tar_target(swf_moderate, read_sf(swf_moderate_path)),
  tar_target(swf_moderate_checks, validate_swf(swf_moderate)),
  tar_target(swf_moderate_per_zcta_tbl, swf_per_zcta(d26_zctas, swf_moderate, "moderate_swf_pct")),

  ## Landcover
  tar_target(d26_zctas_land_cover_pct_path,
             "data/prepared/d26_zctas_land_cover_pct.csv",
             format = "file"),
  tar_target(d26_zctas_land_cover_pct, read.csv(d26_zctas_land_cover_pct_path, colClasses = c("character", "numeric", "numeric"))),
  tar_target(d26_zctas_lc, left_join(d26_zctas, d26_zctas_land_cover_pct, by = "ZCTA5")),
  tar_target(d26_land_cover_pct_path,
             "data/prepared/d26_land_cover_pct.csv",
             format = "file"),
  tar_target(d26_land_cover_pct, read.csv(d26_land_cover_pct_path)),
  tar_target(d26_lc, left_join(d26, d26_land_cover_pct, by = "CounDist")),
  tar_target(lc_checks, validate_lc(d26_zctas_lc, d26_lc)),
  tar_target(tree_canopy_cog_path,
             "data/prepared/tree_canopy.tif",
             format = "file"),
  tar_target(permeable_surface_cog_path,
             "data/prepared/permeable_surface.tif",
             format = "file"),

  ## Sewer
  tar_target(cso_outfall_path,
             "data/prepared/cso_locations_d26_zctas.parquet",
             format = "file"),
  tar_target(cso_outfall, read_sf(cso_outfall_path)),
  tar_target(cso_outfall_checks, validate_cso_outfall(cso_outfall)),
  tar_target(sewer_areas_path,
             "data/prepared/combined_separate_sewer_d26_zctas.parquet",
             format = "file"),
  tar_target(sewer_areas, read_sf(sewer_areas_path)),
  tar_target(sewer_areas_checks, validate_sewer_areas(sewer_areas)),

  ## Ranking
  tar_target(d26_zctas_aggregated,
             join_aggregations(d26_zctas_lc,
                               gi_per_zcta_tbl,
                               cb_per_zcta_tbl,
                               flooding_311_per_zcta_tbl,
                               fvi_per_zcta_tbl,
                               nfhl_per_zcta_tbl,
                               swf_limited_per_zcta_tbl,
                               swf_moderate_per_zcta_tbl)),
  tar_target(d26_aggregated,
             aggregate_d26(d26_lc,
                           gi_all_assets,
                           cb,
                           flooding_311,
                           fvi,
                           nfhl_recoded,
                           swf_limited,
                           swf_moderate)),
  tar_target(d26_zcta_ranks, compute_zcta_ranks(d26_zctas_aggregated)),
  tar_target(d26_zcta_ranks_checks, validate_d26_zcta_ranks(d26_zcta_ranks)),
  tar_target(d26_zctas_attrs, build_d26_zctas_attrs(d26_zctas_aggregated, d26_zcta_ranks)),
  tar_target(d26_attrs, build_d26_attrs(d26_aggregated)),
  tar_target(d26_zctas_attrs_checks, validate_d26_zctas_attrs(d26_zctas_attrs)),
  tar_target(d26_attrs_checks, validate_d26_attrs(d26_attrs)),

  ## Output
  # Parquet attribute tables
  tar_target(d26_zctas_attrs_parquet_path,
             write_d26_zctas_attrs_parquet(d26_zctas_attrs,
                                          "data/processed/d26_zctas_attrs.parquet"),
             format = "file"),
  tar_target(d26_attrs_parquet_path,
             write_d26_attrs_parquet(d26_attrs,
                                     "data/processed/d26_attrs.parquet"),
             format = "file"),

  # PMTiles for visualization
  tar_target(d26_pmtiles_path,
             write_d26_pmtiles(d26, "data/processed/d26.pmtiles"),
             format = "file"),
  tar_target(d26_zctas_pmtiles_path,
             write_d26_zctas_pmtiles(d26_zctas, "data/processed/d26_zctas.pmtiles"),
             format = "file"),
  tar_target(cso_outfalls_pmtiles_path,
             write_cso_outfalls_pmtiles(cso_outfall, "data/processed/cso_outfalls.pmtiles"),
             format = "file"),
  tar_target(sewer_areas_pmtiles_path,
             write_sewer_areas_pmtiles(sewer_areas, "data/processed/sewer_areas.pmtiles"),
             format = "file"),
  tar_target(catch_basins_pmtiles_path,
             write_catch_basins_pmtiles(cb, "data/processed/catch_basins.pmtiles"),
             format = "file"),
  tar_target(gi_display_pmtiles_path,
             write_gi_display_pmtiles(gi_all_assets, "data/processed/gi_all_layers.pmtiles"),
             format = "file"),
  tar_target(swf_limited_pmtiles_path,
             write_swf_limited_pmtiles(swf_limited, "data/processed/swf_limited.pmtiles"),
             format = "file"),
  tar_target(swf_moderate_pmtiles_path,
             write_swf_moderate_pmtiles(swf_moderate, "data/processed/swf_moderate.pmtiles"),
             format = "file"),
  tar_target(nfhl_100yr_pmtiles_path,
             write_nfhl_100yr_pmtiles(nfhl_100yr_d26_zctas, "data/processed/nfhl_100yr.pmtiles"),
             format = "file"),
  tar_target(nfhl_500yr_pmtiles_path,
             write_nfhl_500yr_pmtiles(nfhl_500yr_d26_zctas, "data/processed/nfhl_500yr.pmtiles"),
             format = "file"),
  
  # Copy COG TIFFs to data/processed for deployment
  tar_target(tree_canopy_cog_output_path,
             copy_file(tree_canopy_cog_path,
                       "data/processed/tree_canopy.tif"),
             format = "file"),
  tar_target(permeable_surface_cog_output_path,
             copy_file(permeable_surface_cog_path,
                       "data/processed/permeable_surface.tif"),
             format = "file"),
  
  # Copy 311 geojson to data/processed for deployment
  tar_target(flooding_311_output_path,
             copy_file(flooding_311_path,
                       "data/processed/flooding_311.geojson"),
             format = "file")
)
