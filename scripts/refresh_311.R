library(socratadata)
library(sf)

# Get WKT of D26-intersecting zctas for spatial query
wkt_d26_zctas <- read_sf("data/prepared/d26_zctas.parquet") |> 
  st_union() |> 
  st_transform(4326) |> 
  st_geometry() |> 
  st_as_text()

# Flooding-related 311 Requests
flooding_311 <- soc_read(
  "https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9.json",
  query = soc_query(
    select= "created_date, closed_date, agency, descriptor, location",
    where = paste0(
      "within_polygon(location, '",
      wkt_d26_zctas,
      "') AND created_date >= '2022-01-01T00:00:00' AND
      (descriptor = 'Flooding on Highway' OR descriptor = 'Flooding on Street' OR descriptor = 'Catch Basin Clogged' OR descriptor = 'Culvert' OR descriptor = 'Manhole Overflow' OR descriptor = 'Backup' OR descriptor = 'Ponding'  )
      "
    )
  ),
  include_synthetic_cols = FALSE
)

# Delete data source before writing
write_sf(flooding_311,
         "data/prepared/flooding_311.geojson",
         delete_dsn = TRUE)