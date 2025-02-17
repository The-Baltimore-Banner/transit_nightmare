# convert mps to mph
convert_mps_to_mph <- function(mps) {
  mph <- mps * 2.23694
  return(mph)
}

# Get MTA Routes and Route ID's
routes_url <- "https://api.goswift.ly/info/mta-maryland/routes"

routes_response <- VERB("GET", routes_url, add_headers('Authorization' = '0352517c0285694758568f98b6f013ba'), content_type("application/octet-stream"), accept("application/json"))

routes_json <- content(routes_response, "text")



mta_routes <-
  jsonlite::fromJSON(routes_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  .$routes %>%
  clean_names

route_ids <- mta_routes$id %>%
  unique()


# Get MTA Agency Info
mta_info_url <- "https://api.goswift.ly/info/mta-maryland"

info_response <- VERB("GET", mta_info_url, add_headers('Authorization' = '0352517c0285694758568f98b6f013ba'), content_type("application/octet-stream"), accept("application/json"))

info_json <- content(info_response, "text")

mta_info <-
  jsonlite::fromJSON(info_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  as.data.frame() %>%
  clean_names()


# Trip updates (work in progress)

### Trip Updates

# updates_url <- "https://api.goswift.ly/real-time/mta-maryland/gtfs-rt-trip-updates"
#
# updates_queryString <- list(
#   format = "json",
#   `enable-feature` = "deleted-trips"
# )
#
# updates_response <- VERB("GET", updates_url, query = updates_queryString,
#                          add_headers('Authorization' = '0352517c0285694758568f98b6f013ba'),
#                          content_type("application/octet-stream"),
#                          accept("application/json, application/json; charset=utf-8, text/csv; charset=utf-8")
# )
#
# updates <-
#   content(updates_response, "text") %>%
#   fromJSON(simplifyDataFrame = T, flatten = T) %>%
#   as.data.frame() %>%
#   clean_names %>%
#   unnest(entity_trip_update_stop_time_update) %>%
#   clean_names %>%
#   mutate(header_timestamp = lubridate::as_datetime(as.double(header_timestamp)),
#          arrival_time = lubridate::as_datetime(as.double(arrival_time)),
#          entity_trip_update_timestamp = lubridate::as_datetime(as.double(entity_trip_update_timestamp)),
#          entity_trip_update_trip_start_date = lubridate::as_datetime(entity_trip_update_trip_start_date),
#          departure_time = lubridate::as_datetime(as.double(departure_time)))
#
#
#
# updates %>%
#   group_by(entity_trip_update_vehicle_id) %>%
#   count(sort = T)
#
# updates %>%
#   filter(entity_trip_update_trip_route_id %in% route_ids) %>%
#   filter(!entity_trip_update_trip_route_id %in% not_running) %>%
#   # dplyr::select(entity_trip_update_trip_route_id, schedule_relationship, arrival_time, departure_time) %>%
#   # filter(schedule_relationship != "SCHEDULED") %>%
#   group_by(entity_trip_update_trip_route_id, entity_trip_update_trip_trip_id)
# View()
#
# not_running %>%
#   rbind


