library(sf)
library(terra)
library(exactextractr)
library(dplyr)

# Load prepped boundary files
d26 <- read_sf("data/prepared/d26.parquet")
d26_zctas <- read_sf("data/prepared/d26_zctas.parquet")

## Land Cover ## 
land_cover <- rast("data/prepared/landCover_d26_zctas.tif")

# Reclassification matrix -- combine grass/shrubs (2) & bare soil (3).
# Tree canopy (1) unchanged, others to NA
m <- c(3,3,2,
       4, 8, NA)
rclmat <- matrix(m, ncol = 3, byrow = TRUE)
land_cover_rcl <- classify(land_cover, rclmat, right = NA)

cls <- data.frame(id = 1:2, cover = c("Tree Canopy", "Permeable Surface"))
levels(land_cover_rcl) <- cls

# Get area of each NTA covered by each LC class
land_cover_fracs <- exact_extract(land_cover_rcl, d26_zctas, function(df){
  df |> 
    mutate(frac_total = coverage_fraction / sum(coverage_fraction)) |> 
    group_by(ZCTA5, value) |> 
    summarize(freq = sum(frac_total), .groups = "drop")
}, summarize_df = TRUE, include_cols = 'ZCTA5')

d26_zctas <- d26_zctas |> 
  left_join(land_cover_fracs |> 
              filter(value == 1) |> 
              mutate(pct_tree_canopy = freq * 100) |> 
              select(ZCTA5, pct_tree_canopy)) |> 
  left_join(land_cover_fracs |> 
              filter(value == 2) |> 
              mutate(pct_permeable_surface = freq * 100) |> 
              select(ZCTA5, pct_permeable_surface))

# Get pct area of D26 covered by each class
land_cover_fracs_d26 <- exact_extract(land_cover_rcl, d26, function(df) {
  df |> 
    mutate(frac_total = coverage_fraction / sum(coverage_fraction)) |> 
    group_by(value) |> 
    summarize(freq = sum(frac_total))
}, summarize_df = TRUE, progress = TRUE, max_cells_in_memory = 3e+07)

d26$pct_tree_canopy <- land_cover_fracs_d26 |> 
  filter(value == 1) |> 
  mutate(pct_tree_canopy = freq * 100) |> 
  pull(pct_tree_canopy)

d26$pct_permeable_surface <- land_cover_fracs_d26 |> 
  filter(value == 2) |> 
  mutate(pct_permeable_surface = freq * 100) |> 
  pull(pct_permeable_surface)

# Write to file
write.csv(
  d26 |> 
    st_drop_geometry() |> 
    select(
      CounDist,
      pct_tree_canopy,
      pct_permeable_surface
      ),
  "data/prepared/d26_land_cover_pct.csv",
  row.names = FALSE
)

write.csv(
  d26_zctas |> 
    st_drop_geometry() |> 
    select(
      ZCTA5,
      pct_tree_canopy,
      pct_permeable_surface
    ),
  "data/prepared/d26_zctas_land_cover_pct.csv",
  row.names = FALSE
)

## Write single-category rasters for visualization 

# Tree canopy
subst(land_cover_rcl, 
      from = 1, 
      to = 1, 
      others = NA,
      raw = TRUE,
      filename = "data/prepared/tree_canopy.tif",
      filetype = "COG",
      overwrite = TRUE,
      datatype = "INT1U",
      gdal = c("COMPRESS=DEFLATE",
               "PREDICTOR=2",
               "TARGET_SRS=EPSG:3857",
               "RESAMPLING=NEAREST",
               "BLOCKSIZE=256",
               "OVERVIEWS=IGNORE_EXISTING",
               "OVERVIEW_RESAMPLING=NEAREST"))

# Permeable surfaces
subst(land_cover_rcl, 
      from = 2, 
      to = 2, 
      others = NA,
      raw = TRUE,
      filename = "data/prepared/permeable_surface.tif",
      filetype = "COG",
      overwrite = TRUE,
      datatype = "INT1U",
      gdal = c("COMPRESS=DEFLATE",
               "PREDICTOR=2",
               "TARGET_SRS=EPSG:3857",
               "RESAMPLING=NEAREST",
               "BLOCKSIZE=256",
               "OVERVIEWS=IGNORE_EXISTING",
               "OVERVIEW_RESAMPLING=NEAREST"))
