
library(tidyverse)
library(lubridate)
library(sf)
library(rgeocodio)
library(janitor)
library(hms)
library(kableExtra)

options(dplyr.summarise.inform = FALSE)

county_bus_routes_parsed <-
  read_csv("data/setup/baltimore_county_routes.csv") %>%
  clean_names()

# functions
clean_am_routes <-
  function(x, am_or_pm) {
    x %>%
      filter(
        # We'll filter here for just AM routes
        str_detect(route, am_or_pm),
        # We want to exclude the first or last "stops" of a route if it doesn't include any students boarding or alighting. We don't want those counted in the trip's length overall because no students are riding
        !(stop == 1 & students == 0),
        !(stop == max(stop) & students == 0),
        # we don't care about railroad crossings and don't want to treat them as stops
        location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**",
        !str_detect(route, "NON-TRANSPORTED ZONE")
      ) %>%
      # join to our summary file so we can calculate how long students who get on the bus at each stop spend on the bus
      left_join(county_bus_route_summaries, by = c("route", "source_file")) %>%
      # calculate the time spent on the bus for students who board at each stop
      mutate(net_time = as.numeric(difftime(max_time, time, units = "mins"))) %>%
      # calculate average time spent riding the bus weighted by students at each stop
      group_by(route, source_file) %>%
      summarise(
        # we want to weighht travel time by the number of students at each stop to reflect the average time a student spends on the bus
        # we also want to exclude stops where no students are on the bus
        avg_time = weighted.mean(net_time[students > 0],
                                 w = students[students > 0]),
        # just so we have it, we'll also take the unweighted travel time for each stop, though this is less valuable
        # unweighted_avg_time = mean(net_time[students > 0], na.rm = T),
        avg_boarding_time = weighted.mean(time[students > 0],
                                          w = students[students > 0]),
        avg_alighting_time = weighted.mean(max_time[students > 0],
                                           w = students[students > 0]),
        students = sum(students[students > 0], na.rm = T),
      ) %>%
      # As we'll find out later on in this code, some routes are missing times, while including number of students who rely on them.
      # The reason for this, I presume, is to avoid doxxing the students who get picked up near their homes to be bused to out of zone magnet schools.
      filter(avg_time > 1) %>%
      ungroup()
  }

## How many bus routes are there in Baltimore County Public Schools?

# check for data completeness or places where the parser messed up and look at all routes
county_bus_route_summaries <-
  county_bus_routes_parsed %>%
  # make our columns the right format
  mutate(students = as.numeric(students),
         stop = as.numeric(stop),
         time = hms(as.numeric(time))) %>%
  group_by(route, source_file) %>%
  summarise(n = n(),
            # Since stops are numbered by row, to find the number of stops on a route, we can just take the max stop number
            max_stop = max(stop, na.rm = T),
            net_students = sum(students, na.rm = T),
            min_time = min(time, na.rm = T),
            max_time = max(time, na.rm = T)
  ) %>%
  ungroup() %>%
  mutate(max_time = as_hms(max_time),
         min_time = as_hms(min_time))

# small sample
# county_bus_route_summaries %>%
#   sample_n(25) %>%
#   kbl() %>%
#   kable_material()
#



## AM and PM Summaries

# all
all_am_routes <-
  county_bus_routes_parsed %>%
  clean_am_routes(am_or_pm = " AM") %>%
  mutate(
    avg_boarding_time = as_hms(avg_boarding_time),
    avg_alighting_time = as_hms(avg_alighting_time)
    ) %>%
  # the distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T)


# summaries
am_routes_summary <-
  county_bus_routes_parsed %>%
  clean_am_routes(am_or_pm = " AM") %>%
  distinct(route, .keep_all = T) %>%
  summarise(
    n = n(),
    avg_time = weighted.mean(avg_time, w = students),
    # unweighted_avg_time = mean(unweighted_avg_time, na.rm = T),
    avg_boarding_time = as_hms(weighted.mean(avg_boarding_time, w = students, na.rm = T)),
    avg_alighting_time = as_hms(weighted.mean(avg_alighting_time, w = students, na.rm = T)),
    students = sum(students),
    students_per_route = students / n
  )

am_routes_summary %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material_dark() %>%
  scroll_box(width = "150%")


# PM Routes
# all
all_pm_routes <-
  county_bus_routes_parsed %>%
  clean_am_routes(am_or_pm = " PM") %>%
  mutate(
    avg_boarding_time = as_hms(avg_boarding_time),
    avg_alighting_time = as_hms(avg_alighting_time)
  ) %>%
  # the distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T)

# small sample
# all_pm_routes %>%
#   sample_n(25) %>%
#   kbl() %>%
#   kable_material()

#summary
pm_routes_summary <-
  county_bus_routes_parsed %>%
  clean_am_routes(am_or_pm = " PM") %>%
  distinct(route, .keep_all = T) %>%
  summarise(
    n = n(),
    avg_time = weighted.mean(avg_time, w = students),
    # unweighted_avg_time = mean(unweighted_avg_time, na.rm = T),
    avg_boarding_time = as_hms(weighted.mean(avg_boarding_time, w = students, na.rm = T)),
    avg_alighting_time = as_hms(weighted.mean(avg_alighting_time, w = students, na.rm = T)),
    students = sum(students),
    students_per_route = students / n
  )

pm_routes_summary %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material() %>%
  scroll_box(width = "150%")

# pm_routes_summary %>%
#   write_csv(here::here("data/output/baltco_pm_routes_summary.csv"))


### Checking our work



# All non AM or PM routes
non_am_pm_routes <-
  county_bus_routes_parsed %>%
  filter(
  !str_detect(route, " AM| PM"),
  !str_detect(route, "NON-TRANSPORTED ZONE"),
  !(stop == 1 & students == 0),
  !(stop == max(stop) & students == 0),
  location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**") %>%
  group_by(route, source_file) %>%
  summarise(n = n(),
    students = sum(students[students > 0], na.rm = T)
            ) %>%
  ungroup()

# weird routes
non_am_pm_routes_at_least_one_student <-
  county_bus_routes_parsed %>%
  filter(
  !str_detect(route, " AM| PM"),
  !str_detect(route, "NON-TRANSPORTED ZONE"),
  !(stop == 1 & students == 0),
  !(stop == max(stop) & students == 0),
  location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**") %>%
  left_join(county_bus_route_summaries, by = c("route", "source_file")) %>%
  mutate(net_time = as.numeric(difftime(max_time, time, units = "mins"))) %>%
  # calculate average time spent riding the bus weighted by students at each stop
  group_by(route, source_file) %>%
  summarise(
    avg_time = weighted.mean(net_time[students > 0],
                             w = students[students > 0]),
    # unweighted_avg_time = mean(net_time[students > 0], na.rm = T),
    avg_boarding_time = weighted.mean(time[students > 0],
                                      w = students[students > 0]),
    avg_alighting_time = weighted.mean(max_time[students > 0],
                                       w = students[students > 0]),
    students = sum(students[students > 0], na.rm = T)
  ) %>%
  # ungroup() %>%
  filter(students > 0) %>%
  mutate(
    avg_boarding_time = as_hms(mean(avg_boarding_time, na.rm = T)),
    avg_alighting_time = as_hms(mean(avg_alighting_time, na.rm = T))
  ) %>%
  ungroup()

non_am_pm_routes_at_least_one_student %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material() %>%
  scroll_box(width = "250%")


# avg of all weird routes (minus ones carrying students)
non_am_pm_route_summary <-
  county_bus_routes_parsed %>%
  filter(
  !str_detect(route, " AM| PM"),
  !str_detect(route, "NON-TRANSPORTED ZONE"),
  !(stop == 1 & students == 0),
  !(stop == max(stop) & students == 0),
  location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**") %>%
  left_join(county_bus_route_summaries, by = c("route", "source_file")) %>%
  mutate(net_time = as.numeric(difftime(max_time, time, units = "mins"))) %>%
  # calculate average time spent riding the bus weighted by students at each stop
  group_by(route, source_file) %>%
  summarise(
    avg_time = weighted.mean(net_time[students > 0],
                             w = students[students > 0]),
    # unweighted_avg_time = mean(net_time[students > 0], na.rm = T),
    avg_boarding_time = weighted.mean(time[students > 0],
                                      w = students[students > 0]),
    avg_alighting_time = weighted.mean(max_time[students > 0],
                                       w = students[students > 0]),
    students = sum(students[students > 0], na.rm = T)
  ) %>%
  ungroup() %>%
  filter(avg_time > 1) %>%
  summarise(
    n = n(),
    avg_time = weighted.mean(avg_time, w = students),
    # unweighted_avg_time = mean(unweighted_avg_time, na.rm = T),
    avg_boarding_time = as_hms(mean(avg_boarding_time, na.rm = T)),
    avg_alighting_time = as_hms(mean(avg_alighting_time, na.rm = T)),
    total_students = sum(students)
  )

non_am_pm_route_summary %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material() %>%
  scroll_box(width = "150%")


### Deep-diving on out of zone students

# The 54 'Non-Transported Zone' routes are probably the trickiest part of the data to evaluate. Presumably, these routes serve out of zone magnet school students. This represents about \~8,000 students or somewhere around 20% of the county's bus riders.

# However, the way these routes are represented in the PDFs makes them tricky to evaluate. The majority do not include departure times, arrival times, or stops. This is likely to protect the privacy of students who are picked up near their homes to be bused to out of zone magnet schools. However, this means that we can only factor about half of these routes (25 have at least a minute gap between the first and last stop) into our average commute time calculations. It also means we don't know anything about how many stops are made along these routes or indeed if stops are made along these routes at all. There are several that apparently carry hundreds of students for literally one minute, which obviously doesn't make sense.

# In our system-wide summaries above, we've eliminated routes that we either cannot determine the length of, or have an impossibly low travel time. In effect, this moves our morning and afternoon averages up by about 2 minutes.

# Ultimately, I think there's probably an argument to be made for just eliminating all of these routes from consideration (I'm not even convinced that many of these are real bus routes), but I'd prefer to keep as many as we can given they represent a not-insignificant portion of the county's bus riders.


# All non-transported zone routes

# AM
ooz_am_routes <-
  county_bus_routes_parsed %>%
  filter(
    str_detect(route, " AM"),
    str_detect(route, "NON-TRANSPORTED ZONE"),
    !(stop == 1 & students == 0),
    !(stop == max(stop) & students == 0),
    location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**"
  ) %>%
  group_by(route, source_file) %>%
  summarise(n = n(),
            students = max(students),
            min_time = as_hms(min(time)),
            max_time = as_hms(max(time))
            ) %>%
  mutate(net_time = as.numeric(difftime(max_time, min_time, units = "mins"))) %>%
  # distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T) %>%
  ungroup()
#
# ooz_am_routes %>%
#   sample_n(10) %>%
#   kbl() %>%
#   kable_material()




# PM
ooz_pm_routes <-
  county_bus_routes_parsed %>%
  filter(
    str_detect(route, " PM"),
    str_detect(route, "NON-TRANSPORTED ZONE"),
    !(stop == 1 & students == 0),
    !(stop == max(stop) & students == 0),
    location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**"
  ) %>%
  group_by(route, source_file) %>%
  summarise(n = n(),
            students = max(students),
            min_time = as_hms(min(time)),
            max_time = as_hms(max(time))
            ) %>%
  mutate(net_time = as.numeric(difftime(max_time, min_time, units = "mins"))) %>%
  # distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T) %>%
  ungroup()




# We only have 8 OOZ morning routes that we can evaluate and I remain deeply unconvinced that these are real bus routes. The average time spent on these routes is about 39 minutes, which seems plausible, but the average number of students on these routes is about 500, which seems impossible. However, these routes, to say nothing of the 20 others that we can't say anything about, represent over 3500 students, about 10% of the county's bus riders.

# NTZ routes summary
ooz_am_route_summary <-
  county_bus_routes_parsed %>%
  filter(
  str_detect(route, " AM"),
  !(stop == 1 & students == 0),
  !(stop == max(stop) & students == 0),
  location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**",
  str_detect(route, "NON-TRANSPORTED ZONE")) %>%
  left_join(county_bus_route_summaries, by = c("route", "source_file")) %>%
  mutate(net_time = as.numeric(difftime(max_time, time, units = "mins"))) %>%
  # calculate average time spent riding the bus weighted by students at each stop
  group_by(route, source_file) %>%
  summarise(
    avg_time = weighted.mean(net_time[students > 0],
                             w = students[students > 0]),
    unweighted_avg_time = mean(net_time[students > 0], na.rm = T),
    avg_boarding_time = weighted.mean(time[students > 0],
                                      w = students[students > 0]),
    avg_alighting_time = weighted.mean(max_time[students > 0],
                                       w = students[students > 0]),
    students = sum(students[students > 0], na.rm = T)
  ) %>%
  ungroup() %>%
  # distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T) %>%
  filter(avg_time > 1) %>%
  summarise(
    n = n(),
    avg_time = weighted.mean(avg_time, w = students),
    unweighted_avg_time = mean(unweighted_avg_time, na.rm = T),
    avg_boarding_time = as_hms(mean(avg_boarding_time, na.rm = T)),
    avg_alighting_time = as_hms(mean(avg_alighting_time, na.rm = T)),
    students = sum(students),
    students_per_route = students / n
  )

ooz_am_route_summary %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material() %>%
  scroll_box(width = "150%")


# Afternoon OOZ routes are fewer and shorter than morning routes. There are only 5 of these routes with an average travel time over 1 minute. The average commute time for students on these routes is 7 minutes, which, again, seems impossible. These routes, again, to say nothing of the ones we cannot evaluate, represent nearly 1500 students.


# NTZ routes summary
ooz_pm_route_summary <-
  county_bus_routes_parsed %>%
  filter(
  str_detect(route, " PM"),
  !(stop == 1 & students == 0),
  !(stop == max(stop) & students == 0),
  location != "**RAILROAD CROSSING - PROCEED WITH CAUTION**",
  str_detect(route, "NON-TRANSPORTED ZONE")) %>%
  left_join(county_bus_route_summaries, by = c("route", "source_file")) %>%
  mutate(net_time = as.numeric(difftime(max_time, time, units = "mins"))) %>%
  # calculate average time spent riding the bus weighted by students at each stop
  group_by(route, source_file) %>%
  summarise(
    avg_time = weighted.mean(net_time[students > 0],
                             w = students[students > 0]),
    unweighted_avg_time = mean(net_time[students > 0], na.rm = T),
    avg_boarding_time = weighted.mean(time[students > 0],
                                      w = students[students > 0]),
    avg_alighting_time = weighted.mean(max_time[students > 0],
                                       w = students[students > 0]),
    students = sum(students[students > 0], na.rm = T)
  ) %>%
  ungroup() %>%
  # distinct here eliminates duplicate routes that are in multiple source files
  distinct(route, .keep_all = T) %>%
  filter(avg_time > 1) %>%
  summarise(
    n = n(),
    avg_time = weighted.mean(avg_time, w = students),
    unweighted_avg_time = mean(unweighted_avg_time, na.rm = T),
    avg_boarding_time = as_hms(mean(avg_boarding_time, na.rm = T)),
    avg_alighting_time = as_hms(mean(avg_alighting_time, na.rm = T)),
    students = sum(students)
  )

ooz_pm_route_summary %>%
  kbl() %>%
  kable_styling(full_width = FALSE) %>%
  kable_material() %>%
  scroll_box(width = "150%")

