library(sf)

# Load shapefiles converted from ESRI GDB
# Have to strip Z,M values from geometry
limited_flood <- read_sf("data/source/flood_shp/moderate_1_77_current.shp") |> 
  st_zm()

moderate_flood <- read_sf("data/source/flood_shp/moderate_2_13_current.shp") |> 
  st_zm()

# Get intersecting zctas
d26_zctas <- read_sf("data/prepared/d26_zctas.parquet")

# As with sewer areas, there's one large feature per flood extent type
# Get intersection with D26 intersecting zctas
limited_flood_d26_zctas <- st_intersection(
  limited_flood,
  st_union(d26_zctas)
)

moderate_flood_d26_zctas <- st_intersection(
  moderate_flood,
  st_union(d26_zctas)
)

# Write out
st_write(
  limited_flood_d26_zctas,
  "data/prepared/stormwater_flooding_limited_d26_zctas.parquet",
  driver = "Parquet",
  append = FALSE
)

st_write(
  moderate_flood_d26_zctas,
  "data/prepared/stormwater_flooding_moderate_d26_zctas.parquet",
  driver = "Parquet",
  append = FALSE
)
