- [Get the data](#data)
- [Trip routing](#routing)
- [On-time percentage](#otp)
- [Helpers/Functions](#helpers)


## Introduction

This repo will allow you to recreate the data findings from the Baltimore Banner's investigation TK.

You will use the instructions in this document to download the data that you'll need to perform the analysis, model thousands of routes to Baltimore middle and high schools and assess performance and capacity of the Maryland Transit Administration's bus system in and around Baltimore city.

Read carefully and pay attention to the annotation in every script. The code is designed to be relatively forgiving, but a missing piece or unfollowed direction could lead to errors or mistakes. 

If you run into difficulties or you can email [Greg Morton](sendto:greg.morton@thebaltimorebanner.com)

<a id="routing"></a>
## Trip routing

The code for this lives inside the `/routing` subirectory in this repo. You can begin with `Routing_fact_check.qmd` if you want to get straight to the findings. You can use `routing_analysis.qmd` to run our code yourself or model your own routes from scratch. You'll use `baltCo_bus_routes.qmd` to get commute times for Baltimore County schools.

<a id="otp"></a>
## On-Time Percentage/capacity 

The code for this analysis lives in the `on-time-percentage/` subdirectory. You have a few options here. You can skip straight to `otp_fact_check.qmd` to get directly to findings. If you've already downloaded the data folders associated with this repo and want to recreate them yourself, I recommend skipping straight to `combine_stops_and_schedules.qmd` file. This script combines schedule data with processed bus location data to calculate on-time percentage, headway, and other performance statistics referred to in the story. You can process the JSON files from `s3://s3-tbb-data-dev/school-transportation-public/` with `preparing_otp_data.qmd` and download MTA schedule data with `prepare_schedule_data.qmd` (although schedule data through 1/14 is included in the data folders). Once you've run `combine_stops_and_schedules.qmd`, you can recreate our findings on transit capacity at each school with `grab_bus_arrivals_by_school.qmd`.

<a id="helpers"></a>
## Helpers/Functions

This repo includes several 'helper' scripts that will speed up the process of processing data so we can get straight to the code that gets us to the findings in the story. However, it is important to remember that for  `mta_api_functions.R`, a script containing functions that will make it easier for you to download data from the Swiftly API, you'll need to obtain your own API key.