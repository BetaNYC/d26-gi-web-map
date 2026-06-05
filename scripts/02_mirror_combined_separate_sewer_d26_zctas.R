library(sf)

# Combined Separate Sewer Areas via NYC Open Sewer
comb_sep_sewer <- read_sf(
  paste0(
    "/vsizip/",
    "data/source/combined_separate_sewer.zip"
  )
) |>
  st_make_valid()

# Get intersecting NTAs
d26_zctas <- read_sf("data/prepared/d26_zctas.parquet")

# There's only one feature per sewer area type -- Get intersection
comb_sep_sewer_d26_zctas <- st_intersection(
  comb_sep_sewer,
  st_union(d26_zctas)
)

# Write out
st_write(
  comb_sep_sewer_d26_zctas,
  "data/prepared/combined_separate_sewer_d26_zctas.parquet",
  driver = "Parquet"
)
