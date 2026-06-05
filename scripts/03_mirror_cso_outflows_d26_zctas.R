library(sf)

# Load Combined Sewer Overflow Outflows
# Via NYC Open Sewer Atlas
cso_outfalls <- read_sf(
  paste0(
    "/vsizip/",
    "data/source/cso_locations.zip"
  )
) |> 
  st_make_valid() |> 
  st_transform(2263)

# Get intersecting zctas
d26_zctas <- read_sf("data/prepared/d26_zctas.parquet")

# Get intersecting features
cso_outfalls_d26_zctas <- st_filter(
  cso_outfalls,
  d26_zctas
)

# Write out
st_write(
  cso_outfalls_d26_zctas,
  "data/prepared/cso_locations_d26_zctas.parquet",
  driver = "Parquet"
)
