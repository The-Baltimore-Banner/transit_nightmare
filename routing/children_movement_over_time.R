## Where are kids moving?
library(tidycensus)
library(tidyverse)
library(tigris)
library(mapview)
library(RColorBrewer)
library(sf)
library(mapview)
library(janitor)

# turn off scientific notation
options(scipen = 999)


# school points
D_school_locs <- st_read("data/shapes/city_schools/Baltimore_City_Schools.shp") %>%
  st_transform(4326) %>%
  st_set_crs(4326)


# filter points down to high schools and middle schools
hs_locs_join <-
  D_school_locs %>%
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


# get baltimmore city census tracts
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



# make a join version with lat and lon for r5r
bmore_tracts_join <-
  bmore_tracts %>%
  clean_names() %>%
  dplyr::select(geoid, name, geometry) %>%
  rename(tract_name = name) %>%
  st_as_sf() %>%
  st_transform(4326) %>%
  mutate(
    valid_geometry = st_make_valid(geometry),  # Ensure geometries are valid
    tract_point = st_centroid(valid_geometry),  # Calculate the centroid of the land area,
    tract_point_lat = st_coordinates(tract_point)[, 2],  # Extract the latitude of the centroid
    tract_point_lon = st_coordinates(tract_point)[, 1]  # Extract the longitude of the centroid
  )

### Load census data and BNIA CSAs
variables_2010 <- tidycensus::load_variables(2010, "acs1", cache = TRUE)
variables_2023 <- tidycensus::load_variables(2023, "acs1", cache = TRUE)

total_kids_2010 <- get_acs(geography = "tract",
                           state = "MD",
                           county = "Baltimore city",
                           variables = c(
                             "B01001_003",
                             "B01001_004",
                             "B01001_005",
                             "B01001_006",
                             "B01001_027",
                             "B01001_028",
                             "B01001_029",
                             "B01001_030"
                           ),
                           year = 2010) %>%
  pivot_wider(names_from = "variable", values_from = "estimate") %>%
  group_by(GEOID) %>%
  summarise(total_kids =
              sum(
                B01001_003,
                B01001_004,
                B01001_005,
                B01001_006,
                B01001_027,
                B01001_028,
                B01001_029,
                B01001_030,
                na.rm = T)
  ) %>%
  ungroup() %>%
  mutate(all_kids = sum(total_kids, na.rm = T),
         pct_kids = total_kids / all_kids * 100)

total_kids_2023 <- get_acs(geography = "tract",
                           state = "MD",
                           county = "Baltimore city",
                           variables = c(
                             "B01001_003",
                             "B01001_004",
                             "B01001_005",
                             "B01001_006",
                             "B01001_027",
                             "B01001_028",
                             "B01001_029",
                             "B01001_030"
                           ),
                           year = 2023) %>%
  pivot_wider(names_from = "variable", values_from = "estimate") %>%
  group_by(GEOID) %>%
  summarise(total_kids =
              sum(
                B01001_003,
                B01001_004,
                B01001_005,
                B01001_006,
                B01001_027,
                B01001_028,
                B01001_029,
                B01001_030,
                na.rm = T)
  ) %>%
  ungroup() %>%
  mutate(all_kids = sum(total_kids, na.rm = T),
         pct_kids = total_kids / all_kids * 100)

# get 2010 baltimore tract shapes from tigris
tracts_2010 <-
  tigris::tracts(state = "MD", county = "Baltimore City", year = 2010)

tracts_2023 <-
  tigris::tracts(state = "MD", county = "Baltimore City", year = 2023)


# read BNIA CSA
bnia_csa_2020 <-
  st_read("data/shapes/Community_Statistical_Areas_2020/Community_Statistical_Areas_(2020).shp") %>%
  st_transform(4326)

#BNIA Crosswalk files
bnia_crosswalk_2020_census_to_2020_csa <-
  read_csv("data/raw/Census_Tract_(2020)_to_Community_Statistical_Area_(2020).csv") %>%
  mutate(GEOID_Tract_2020 = as.character(GEOID_Tract_2020))

# get center of baltimore
center <- tracts_2023 %>%
  # get centerpoint of all tracts
  summarise(lon = mean(st_coordinates(.$geometry)[, 1]),
            lat = mean(st_coordinates(.$geometry)[, 2])) %>%
  mutate(center = st_centroid(geometry))

center_lon <- center$lon
center_lat <- center$lat

# 2010
tracts_2010_neighborhood_details <-
  tracts_2010 %>%
  left_join(total_kids_2010, by = c("GEOID10" = "GEOID")) %>%
  mutate(
    center = st_centroid(geometry),
    lat = st_coordinates(center)[, 2],
    lon = st_coordinates(center)[, 1]
  ) %>%
  mutate(
    east_or_west = ifelse(lon > center_lon, "east", "west"),
  ) %>%
  mutate(as.numeric(pct_kids)) %>%
  ungroup() %>%
  left_join(bnia_crosswalk_2020_census_to_2020_csa, by = c("GEOID10" = "GEOID_Tract_2020"))


# 2023
tracts_2023_neighborhood_details <-
  tracts_2023 %>%
  left_join(total_kids_2023, by = c("GEOID" = "GEOID")) %>%
  mutate(
    center = st_centroid(geometry),
    lat = st_coordinates(center)[, 2],
    lon = st_coordinates(center)[, 1]
  ) %>%
  mutate(
    east_or_west = ifelse(lon > center_lon, "east", "west")
  ) %>%
  mutate(as.numeric(pct_kids)) %>%
  ungroup() %>%
  left_join(bnia_crosswalk_2020_census_to_2020_csa, by = c("GEOID" = "GEOID_Tract_2020"))


# Read student home tract data
# student_home_tracts_23 <-
#   read_xlsx("data/home_tracts/REVISED Banner Request-Enroll by Prog and Tract-2024.08.08.xlsx", sheet = 2, skip = 5) %>%
#   clean_names() %>%
#   mutate(prog_no = as.character(prog_no)) %>%
#   # change all colnames to character
#   mutate(across(-c(prog_no, program, enrollment), ~ as.numeric(as.character(.)))) %>%
#   # Pivot longer to convert census tract columns into rows
#   pivot_longer(
#     cols = -c(prog_no, program, enrollment),
#     names_to = "census_tract",
#     values_to = "students"
#   ) %>%
#   left_join(hs_parcel_join, by = c("prog_no" = "school_number")) %>%
#   dplyr::select(prog_no, program, enrollment, school_name, name, everything()) %>%
#   mutate(students = ifelse(is.na(students), 5, students)) %>%
#   filter(!is.na(school_name),
#          students > 0
#          )  %>%
#   dplyr::select(-x, -y, -join_addr.y, -GlobalID, -class, -category, -OBJECTID, -join_addr.x) %>%
#   rename(school_polygon = geometry.x,
#          school_point = geometry.y) %>%
#   mutate(school_point_lat = st_coordinates(school_point)[, 2],
#          school_point_lon = st_coordinates(school_point)[, 1],
#          census_tract = str_remove_all(census_tract, "x")) %>%
#   left_join(bmore_tracts_join, by = c("census_tract" = "geoid"))





## Question 1: Where do kids now vs. Where they were living in 2010?
east_v_west_bmore_2010 <-
  tracts_2010_neighborhood_details %>%
  group_by(east_or_west) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))


east_v_west_bmore_2010 <-
  tracts_2023_neighborhood_details %>%
  group_by(GEOID) %>%
  group_by(east_or_west) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))



# What % of kids live in east vs. west Baltimore 2023
kids_in_east_and_west_bmore_2023 <-
  tracts_2023_neighborhood_details %>%
  group_by(east_or_west) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))


kids_in_east_and_west_bmore_2010 <-
  tracts_2010_neighborhood_details %>%
  group_by(east_or_west) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))



# What % of kids live in each neighborhood
kids_by_neighborhood_2023 <-
  tracts_2023_neighborhood_details %>%
  clean_names() %>%
  group_by(community_statistical_area_2020) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))  %>%
  arrange(desc(pct_total)) %>%
  rename(pct_total_2023 = pct_total,
         total_kids_2023 = total_kids) %>%
  st_drop_geometry()

kids_by_neighborhood_2010 <-
  tracts_2010_neighborhood_details %>%
  clean_names() %>%
  group_by(community_statistical_area_2020) %>%
  summarise(pct_total = sum(pct_kids, na.rm = T),
            total_kids = sum(total_kids, na.rm = T))  %>%
  arrange(desc(pct_total)) %>%
  rename(pct_total_2010 = pct_total,
         total_kids_2010 = total_kids) %>%
  st_drop_geometry()

# how has the distribution of kids changed over time?
kids_by_neighborhood_change_over_time <-
  kids_by_neighborhood_2023 %>%
  left_join(kids_by_neighborhood_2010, by = "community_statistical_area_2020") %>%
  mutate(pct_diff = pct_total_2023 - pct_total_2010) %>%
  rename(csa = community_statistical_area_2020) %>%
  dplyr::select(csa, pct_diff, pct_total_2023, pct_total_2010, everything()) %>%
  arrange(desc(pct_total_2010))
