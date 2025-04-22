
# MTA Info ----------------------------------------------------------------

# mta routes
routes_url <- "https://api.goswift.ly/info/mta-maryland/routes"

# light rail url for api call
light_rail_url <- "https://api.goswift.ly/info/mta-maryland-light-rail/routes/"

# metro url for api call
metro_url <- "https://api.goswift.ly/info/mta-maryland-metro/routes/"

# get bus api response
routes_response <- VERB("GET", routes_url, add_headers('Authorization' = 'YOUR-API-KEY'), content_type("application/octet-stream"), accept("application/json"))
#
# light rail api response
light_rail_response <- VERB("GET", light_rail_url, add_headers('Authorization' = 'YOUR-API-KEY'), content_type("application/octet-stream"), accept("application/json"))
#
# metro api response
metro_response <- VERB("GET", metro_url, add_headers('Authorization' = 'YOUR-API-KEY'), content_type("application/octet-stream"), accept("application/json"))



# routes json
routes_json <- content(routes_response, "text")

# lr json
light_rail_json <- content(light_rail_response, "text")

# metro json
metro_json <- content(metro_response, "text")

# turn em all into dataframes
mta_routes <-
  jsonlite::fromJSON(routes_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  .$routes %>%
  clean_names

light_rail_routes <-
  jsonlite::fromJSON(light_rail_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  .$routes %>%
  clean_names

metro_routes <-
  jsonlite::fromJSON(metro_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  .$routes %>%
  clean_names

all_routes <-
  bind_rows(mta_routes, light_rail_routes, metro_routes) %>%
  mutate(short_name = str_remove_all(short_name, " "))

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
  st_set_crs(4326) %>%
  mutate(school_number = as.character(school_number)) %>%
  left_join(enrollment_23, by = c("school_number" = "prog_no")) %>%
  filter(!is.na(program_join))
