library(httr)
library(sf)
library(units)
library(dplyr)
library(tidycensus)

# Write spatial files for use in generating data mirror artifacts: 
# Council District 26
# ZCTAs significantly (>2%) intersecting with Council District 26

# Council District 26
# From DCP ESRI Endpoint
url_d26 <- "https://services5.arcgis.com/GfwWNkhOj9bNBqoJ/arcgis/rest/services/NYC_City_Council_Districts/FeatureServer/0"
parsed_url <- parse_url(url_d26)
parsed_url$path <- paste0(parsed_url$path, "/query")
parsed_url$query <- list(where = "counDist = 26",
                         outFields = "counDist",
                         f = "geojson",
                         outSR = 2263)
request <- build_url(parsed_url)
d26 <- read_sf(request) |> st_make_valid()
rm(parsed_url)

# Bounding box for ZCTA query
d26_bbox <- d26 |> 
  st_transform(4326) |> 
  st_bbox()

# ZCTAs
# From ESRI's Federal Data Collection
# Despite the URL, ESRI says these are 2020 ZCTAs
# Using the bounding box avoids the hassle of converting into ESRI's geometry type
url_zcta <- "https://services2.arcgis.com/FiaPA4ga0iQKduv3/arcgis/rest/services/Census_ZIP_Code_Tabulation_Areas_2010_v1/FeatureServer/0"
parsed_url <- parse_url(url_zcta)
parsed_url$path <- paste0(parsed_url$path, "/query")
parsed_url$query <- list(where = "0=0",
                         outFields = "ZCTA5, POP100",
                         f = "geojson",
                         outSR = 2263,
                         geometry = paste(d26_bbox["xmin"], d26_bbox["ymin"], d26_bbox["xmax"], d26_bbox["ymax"], sep = ","),
                         geometryType = "esriGeometryEnvelope",
                         inSR = 4326,
                         spatialRel = "esriSpatialRelIntersects"
                         )
request <- build_url(parsed_url)
zcta <- read_sf(request) |> st_make_valid()

# Filter for Intersecting ZCTAs
zcta_d26 <- zcta |> 
  st_filter(d26)

# Identify sliver intersections using intersection area / cd area percentage
zcta_d26$int_pct <- drop_units(
  (st_area(st_intersection(zcta_d26, d26)) / st_area(d26) * 100)
)

# Remove sliver intersections with 0.5% threshold
zcta_d26 <- zcta_d26 |> 
  filter(int_pct > 0.5)

# ZCTAs arrive with decennial population 
# Join population from decennial census to D26 for normalization
# For council district 26, sum spatially-weighted blocks

d26_block_pop <- get_decennial(
  geography = "block",
  variables = "P1_001N",
  year = 2020,
  state = 36,
  county = "081",
  geometry = TRUE
) |> 
  st_transform(2263) |>
  st_filter(d26, .predicate = st_intersects) |>
  mutate(
    block_area = st_area(geometry),
    intersect_geom = st_intersection(geometry, st_geometry(d26)),
    intersect_area = st_area(intersect_geom),
    pct_d26_int = drop_units(intersect_area / block_area),
    weighted_pop = value * pct_d26_int
  )


d26$d26_pop <- sum(d26_block_pop$weighted_pop)


# Write to parquet
write_sf(zcta_d26,
         "data/prepared/d26_zctas.parquet",
         driver = "Parquet")

write_sf(d26,
         "data/prepared/d26.parquet",
         driver = "Parquet")