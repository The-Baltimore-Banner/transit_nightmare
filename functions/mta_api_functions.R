# convert mps to mph
convert_mps_to_mph <- function(mps) {
  mph <- mps * 2.23694
  return(mph)
}

# Get MTA Routes and Route ID's
routes_url <- "https://api.goswift.ly/info/mta-maryland/routes"

routes_response <- VERB("GET", routes_url, add_headers('Authorization' = 'YOUR-API-KEY-HERE'), content_type("application/octet-stream"), accept("application/json"))

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

info_response <- VERB("GET", mta_info_url, add_headers('Authorization' = 'YOUR-API-KEY-HERE'), content_type("application/octet-stream"), accept("application/json"))

info_json <- content(info_response, "text")

mta_info <-
  jsonlite::fromJSON(info_json, simplifyDataFrame = T, flatten = F) %>%
  .$data %>%
  as.data.frame() %>%
  clean_names()

