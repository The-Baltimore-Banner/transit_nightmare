
# Setup -------------------------------------------------------------------

# Load required packages
library(devtools)
library(elevatr)
library(r5r)
library(sf)
library(osmextract)
library(rJava)
library(tidyverse)
library(geobr)
library(here)
library(tigris)
library(tidycensus)
library(mapview)
library(RColorBrewer)
library(readxl)
library(janitor)
library(httr)
library(hms)
library(raster)
library(terra)
library(osmdata)
library(readr)

# options(tigris_use_cache = TRUE)


# School location data ----------------------------------------------------
# We'll begin with a dataset of school parcels and locations. We'll use the points as the endpoints for our tip and the parcels for visualization.

# school points
# We will use the Baltimore City Schools shapefile to get the locations of middle and high schools in Baltimore City
hs_locs_join <- st_read("data/shapes/city_schools/Baltimore_City_Schools.shp") %>%
  st_transform(4326) %>%
  st_set_crs(4326) %>%
  filter(str_detect(class, "9 - 12|6 - 12|6 - 8|5 - 8")) %>%
  mutate(join_addr = str_to_lower(address),
  )

# df version for joining
hs_locs_join_df <-
  hs_locs_join %>%
  as.data.frame() %>%
  mutate(prg_num = as.character(prg_num))

# read in school parcels
D_school_parcels <- st_read("data/shapes/school_parcels/school_parcels.geojson") %>%
  distinct(.keep_all = T) %>%
  mutate(schools_at_parcel =
           case_when(
             # rename some of the schools to make them join-able
             schools_at_parcel == "Crossroads School, The" ~ "The Crossroads School",
             schools_at_parcel == "Belair-Edison School, The" ~ "The Belair-Edison School",
             schools_at_parcel == "Dallas F. Nicholas, Sr., Elementary School" ~ "Dallas F. Nicholas Sr. Elementary School",
             schools_at_parcel == "Green School Of Baltimore, The" ~ "The Green School Of Baltimore",
             schools_at_parcel == "Reach! Partnership School, The" ~ "The Reach! Partnership School",
             schools_at_parcel == "Dr. Bernard Harris, Sr., Elementary School" ~ "Dr. Bernard Harris Sr. Elementary School",
             schools_at_parcel == "Historic Samuel Coleridge-Taylor Elementary School, The, Joseph C. Briscoe Academy" ~ "The Historic Samuel Coleridge-Taylor Elementary School, The Joseph C. Briscoe Academy",
             TRUE ~ schools_at_parcel
           )) %>%
  st_transform(4326) %>%
  st_set_crs(4326)


# join school parcels to high school locations
hs_parcels_buffer <-
  D_school_parcels %>%
  st_join(hs_locs_join) %>%
  dplyr::select(school_name, name, join_addr, fulladdr) %>%
  filter(!is.na(name)) %>%
  distinct(name, .keep_all = T) %>%
  as.data.frame() %>%
  left_join(hs_locs_join_df,
            by = c(name = "name")) %>%
  filter(str_detect(class, "9 - 12|6 - 12|6 - 8|5 - 8")) %>%
  st_as_sf() %>%
  st_transform(29902)


# join df for hs parcels (we just need school number from here)
hs_parcel_join <-
  hs_parcels_buffer %>%
  as.data.frame() %>%
  mutate(school_number = as.character(prg_num)) %>%
  ungroup()

# get start stop times
start_stop_times <- read_csv("data/setup/start_stop_times.csv") %>%
  janitor::clean_names() %>%
  mutate(school_number = as.character(school_number))

# select relevant columns
sst_new <- start_stop_times %>%
  left_join(hs_parcel_join, by = c("school_number" = "school_number")) %>%
  filter(!is.na(name)) %>%
  dplyr::select(school_number, name, am_bell, pm_bell, district_early_release_time, address.y
  )


# load functions I need to access MTA API
# source("functions/mta_api_functions.R")
source("functions/mta_api_functions.R")


# Baltimore City Shapes ---------------------------------------------------
# get Baltimore city census tracts
bmore_tracts <- tigris::tracts(
  state = "MD",
  county = "Baltimore City"
) %>%
  tigris::erase_water() %>%
  st_transform(4326) %>%
  # First make valid
  st_make_valid() %>%
  # Remove any empty geometries
  filter(!st_is_empty(.)) %>%
  # Extract polygons
  st_collection_extract("POLYGON") %>%
  # Remove any potential duplicate vertices and fix other issues
  st_buffer(0) %>%
  # Group and union
  group_by(GEOID, NAME) %>%
  summarise(geometry = st_union(geometry), .groups = "drop")


# If Trump breaks tiger/lines again
# bmore_tracts <-
#   st_read("/Users/greg.morton/Documents/data-library/baltimore/baltimore-shapes/baltimore-census-tracts.geojson") %>%
#   # tigris::erase_water() %>%
#   st_transform(4326) %>%
#   # First make valid
#   st_make_valid() %>%
#   # Remove any empty geometries
#   filter(!st_is_empty(.)) %>%
#   # Extract polygons
#   st_collection_extract("POLYGON") %>%
#   # Remove any potential duplicate vertices and fix other issues
#   st_buffer(0) %>%
#   # Group and union
#   group_by(GEOID20, NAME20) %>%
#   summarise(geometry = st_union(geometry), .groups = "drop")

# add parks so we can remove them
parks <- st_read("data/shapes/Parks/Parks.shp") %>% st_transform(32618)

# add a slight buffer to the parks so we can remove them from the tracts
parks <- st_buffer(parks, 50) %>% st_union() %>% st_transform(4326)

# add schools so we can remove them
schools <- hs_parcels_buffer %>%
  st_buffer(100) %>%
  st_union() %>%
  st_transform(4326)

# industrial areas on the waterfront
mizod <- st_read("data/shapes/MIZOD/MIZOD.shp") %>%
  st_union() %>%
  st_transform(4326)


# load EU Global Human Settlement Layer Raster
grid <- raster("data/raw/GHS_BUILT_S_E2030_GLOBE_R2023A_54009_100_V1_0_R5_C12/GHS_BUILT_S_E2030_GLOBE_R2023A_54009_100_V1_0_R5_C12.tif")

# change raster projection to 4326
grid <- projectRaster(grid, crs = st_crs(4326)$proj4string)

# Make a bounding box that we will use for cropping the raster
bbox <- extent(st_bbox(bmore_tracts))

# another bounding box that we'll use to crop the OSM.PBF file later
area_bbox <- st_bbox(bmore_tracts) %>%
  st_as_sfc() %>%
  st_transform(4326) %>%
  st_buffer(3000) %>%
  st_bbox() %>%
  st_as_sfc() %>%
  st_transform(4326) %>%
  st_bbox()

# crop our raster
cropped_raster <- crop(grid, bbox)

# convert cropped raster to points
baltimore_grid <- rasterToPoints(cropped_raster, spatial = TRUE)

# get Baltimore elevation data from elevatr
# Convert bbox to sf object for get_elev_raster
aoi <- st_as_sfc(st_bbox(area_bbox)) %>%
  st_sf() %>%
  st_set_crs(4326)

# Step 2: Get elevation data using elevatr
# zoom = 9-14 determines resolution (higher = more detailed but larger file)
elevation_raster <- get_elev_raster(locations = aoi, z = 12, clip = "locations")

elevation_terra <- rast(elevation_raster)  # Convert to terra format

writeRaster(elevation_terra,
            filename = "data/poa/elevation.tif",
            overwrite = TRUE)


# remove parks, schools, and industrial area from tracts. This is so we don't accidentally pick a starting point where we know for a fact no one lives
bmore_tracts_no_parks <-
  bmore_tracts %>%
  st_difference(parks) %>%
  st_difference(schools) %>%
  st_difference(mizod)


