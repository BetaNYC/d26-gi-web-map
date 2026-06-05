library(sf)
library(terra)

# Create SpatRaster object using source data
landCover <- rast("data/source/Land_Cover/NYC_2017_LiDAR_LandCover.img")

# Get bounding box of ~500m buffer around D26-intersecting zctas
bbox_d26_zctas <- read_sf("data/prepared/d26_zctas.parquet") |> 
  st_buffer(dist = 500 * (1/0.3048)) |> 
  st_bbox()

# Crop raster
landCover_d26_zctas <- terra::crop(landCover, ext(bbox_d26_zctas))

# Write as Geotiff, LZW lossless compression
writeRaster(
  landCover_d26_zctas,
  filename = "data/prepared/landCover_d26_zctas.tif",
  filetype = "GTiff",
  overwrite = TRUE,
  gdal = c("COMPRESS=LZW",
           "GTIFF_WRITE_RAT_TO_PAM=NO") 
)