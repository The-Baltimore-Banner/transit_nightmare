# Transit nightmare: Thousands of Baltimore kids can’t get to school on time

### by [Greg Morton](mailto:greg.morton@thebaltimorebanner.com)

- [Overview](#overview)
- [Data](#data)
- [Methodology](#method)
- [Limitations](#limitations)
- [License](#license)

## Overview
Baltimore city is the only school district in Maryland to offer middle and high school students the chance to attend a school of their choosing. It is also the only district in the state not to provide most students a yellow school bus ride after elementary school.

For students without parents or others who can drive them or the means to hire private transportation, the opportunity to attend a school with the kinds of programs needed to meet their academic goals can mean a long and sometimes unpredictable commute on public transit. The Banner spoke to dozens of students, many of whom described early alarms and arduous journeys on public transit.

To investigate their claims, we used modeling techniques to estimate every city student’s quickest route to school and analyzed tens of millions of rows of live transit data to evaluate MTA buses’ reliability.

Our final determination: Baltimore’s public transit makes it impossible for middle and high school students to get to school on time consistently.


[Read the story](https://www.thebaltimorebanner.com/education/k-12-schools/baltimore-city-school-buses-HF3HHWC67ZF7BCRJ66WMB3VWDI/)

<a id="data"></a>

## Data 

[Download the data folder for this project here](https://s3-tbb-data-dev.s3.us-east-1.amazonaws.com/school-transportation-public/data.tar.gz). Make sure that you put it in the root directory of this repo. This folder contains many of the pieces that you'll need to recreate the analysis from scratch, as well as the results from our work. You'll need to allocate about 40 GB of hard drive space for this folder.

[Download live bus position data here](https://s3-tbb-data-dev.s3.us-east-1.amazonaws.com/school-transportation-public/bus-positions.tar.xz). You will need about 350 GB of local hard drive space for this. We recommend storing this on your desktop to avoid changing some of the filepaths in this repo. You only need this if you're planning on processing raw JSON bus location data.

The analysis also involves downloading data from two external sources: the U.S. Census Bureau (via the tidycensus package) and the MTA (via the Swiftly API). Both will require that you obtain an API key.


<a id="method"></a>

## Methodology

### How we modeled over 4,000 routes to school
We began our search for what constitutes a typical Baltimore city commute to school with a public records request that provided us with the number of students at each school by home census tract for the 2023-2024 school year. There were 4,210 unique school-tract combinations, representing as many as 25,000 students’ journeys.

To model each of those unique trips, we used the open-source r5 routing model developed by researchers at Conveyal, a transit consulting firm. The model combined OpenStreetMaps data detailing Baltimore’s road network, General Transit Feed Specification (GTFS) schedule and route data provided by the Maryland Transit Administration, .tif elevation data, departure times and origin and destination points for each trip to calculate the fastest route from every census tract in the city to each of the city’s middle and high schools.

To determine a representative point of origin from students’ anonymized home census tracts, we used the E.U.’s Global Human Settlement Layer, a database meant to provide extremely granular info about population distribution around the world. We chose a single origin point for each tract through a random geographic sample that excluded parks, schools and industrial zones. We also imposed a minimum estimated population density. This method allowed us reasonable certainty that we were choosing points where people actually lived. To build a street network, we began with the OSM.pbf file for the entire state of Maryland and cropped it to an area that included the entire city and extended slightly into the county. This meant we could allow for trips that diverted students’ trips into Baltimore County before ultimately returning to their final destination in Baltimore City.

Since r5 requires a departure time, and that naturally varies with where a student lives and where they go to school, we used the `travel_times_matrix` function in `r5r` (r5’s R interface) to estimate the latest departure time that would get a student to school on time on public transit. To that end, we built a loop to iterate over departure times for each of our 4,210 tract-school combos, in 10- minute intervals, until one would get a student to school five or more minutes before the school’s opening bell. For each trip, we kept the latest departure time that the model estimated would get a student to school on time.

For the specifics of each route we used `r5r`’s `detailed_iteneraries` function, which provided us with important details such as which transit lines each trip relies on, how many transfers are involved in each trip, the number of legs and length of each leg, and waiting times.

We built another loop to run the `detailed_iteneraries` function on every tract/route combination in our data and combined the results to generate summary statistics for each trip including total length in terms of both time and distance, modes of transit used, routes used, and number of transfers. To find the average commute time, we weighed each trip by the number of students served by each route (i.e. the number of students from a certain census tract that went to a certain school) and calculated average and median commute statistics citywide, by school and by census tract.

Next, to compare the length of commute on public transit to the commute in a private vehicle, we used Google’s routing API to model trips between each of the same origin and destination pairs using a car. Finally, we compared the average length of commutes on public transit to the average trip time on yellow school buses in Baltimore County. Through another public information act request, we obtained data on all middle and high school bus routes in the county, including their stops and the number of students boarding at each stop. We then calculated the average time students spend on the bus, weighting our calculation by the number of students boarding at each stop.



### How we tracked every MTA Bus for the first 6 months of school 

For answers on how often things go wrong for students during their daily commutes, we decided on writing our own scripts to pull live bus location data and track bus reliability during students’ commuting windows.

While the [MTA](https://www.mta.maryland.gov/performance-improvement) and third-party services like [Aries for Transit](https://aries.dcmetrohero.com/) have compiled and published similar data, we had a few specific goals in mind that existing data sets could not accomplish: 

-   It was imporant to us to determine how often the bus is not on time within a specified time period. MTA's data provides an on-time percentage by date and by line, but since our reporting focused on hours during which students are commmuting, we felt that it was appropriate to focus our analyis on that same time period.

-   MTA's public data defines "on time" as between two minutes early and seven minutes late. While it is not unusual for a transit agency to provide a window during which a bus is considered "on time", collecting our own data allowed us the freedom to adjust that window and evaluate performance at different threshholds. We ultimately made the decision to calculate on-time percentage not just at MTA's -2/+7 window, but also -1/+5 (the standard for public transit in New York City during off-peak hours), and -2/+4. The logic here being that students needs may dictate a narrower on-time window than other kinds of commuters because of schools' fixed start times and that MTA's measure for what is considered on-time is not universal among U.S. public transit systems.

-   We wanted to be able to estimate total capacity of all buses arriving within half a mile of a school each morning and afternoon. The point here was to make an informed estimate on whether MTA had enough buses in circulation to accomodate all of the students who are eligible for public transit.

To build our dataset, we collected GTFS-realtime bus data from MTA’s API via an Amazon Web Services EC2 instance that ran every 5 seconds from 4 a.m. to 12 a.m. every day.

Next, we pulled daily bus schedule data from the MTA’s API and saved it locally.
The real time data was then de-duplicated (because of the frequency of our API calls, our data contained many duplicate observations), cleaned, and filtered to remove non-commuting hours (i.e. any hours not including the 5 a.m. to 9 a.m. hours in the morning or the 2 p.m. to 4 p.m. hours in the afternoon).

We calculated on-time percentage, headway, and other transit statistics by joining our schedule and real time data on the variables `route_ID`, `trip_ID`, `start_date`, and `stopID`. Joining by multiple variables ensured that our calculations were accurate and that we were not mis-assigning buses. Our data collection and join methods were reviewed by several transit experts.

We determined total capacity for each middle and high school by using the `sf` package in R to draw a half mile buffer around each school’s land parcel and using the same package to determine how many buses in our data arrived at stops within that buffer zone. To determine whether there was adequate bus capacity to meet a school’s potential need. We used student home tract data to estimate what % of a school’s enrollment lived far enough from school to make them eligible for a transit pass provided by city schools (1.5 miles). We assumed each bus arriving within that half-mile buffer zone would fit 60 students, the full capacity of an average MTA bus.

<a id="limitations"></a>

## Limitations

### Starting point granularity 

All information on where students live was provided to us at the census tract level to protect students’ right to privacy. This necessarily imposed limitations on the granularity of our routing analysis. Our solution, detailed in part above, was trying to choose a representative starting point within each census tract. Our method for deciding on that point is detailed above.

### Route preferances 

While analysis provides the most detailed ever estimate of each student’s trip to school on public transit, it is still an estimate. There is no precise route each student takes to school because, as we found out from our reporting, students’ methods of getting to school often differ day-to-day based on factors like travel conditions and access to a ride.

While r5 allows some flexibility, its preference is generally for the fastest route by travel time. While `r5r` allows multiple options for each route, we felt it would be inappropriate to make value judgements on which route was the most “realistic”. In reality, a student may opt for a longer trip than the model proposes because it is more direct, more reliable or simply because they prefer that route.

### Accounting for transit reliability in the model

Since the r5 models routes based on the street network and transit schedule, it is unable to account for system-wide reliability. This means common inconveniences like delays or missing buses cannot be accounted for in our routing analysis.

Put simply, travel time estimates generated by r5 should be understood as a best-case scenario.



### Ghost buses 

About 10% of scheduled trips are missing from MTA’s GTFS-realtime data. These so-called “ghost buses” make it more difficult to ascertain on-time percentage because it is impossible to be certain whether these buses made their planned trips or not. The reality is probably a mix of cancelled trips and broken transponders (the tool that buses use to transmit live location data). The on-time percentage numbers that appear in our story include only observed buses, but our data analysis includes “optimistic” and “pessimistic” estimates for on-time, inspired by Aries for Transit. The “optimistic” estimate assumes that all of these missing buses arrived on time while the “pessimistic” estimate assumes none of them did. The truth is probably somewhere in the middle and can vary significantly day-to-day.

### Why only track real time bus data?

Limitations on our API usage forced us into a difficult decision about which and how much transit data we could collect. Since both the routing model, many of the students we interviewed and prior research all indicated to us that buses were the most-used form of public transit for city students, that is where we decided to focus. While pulling real time data from Baltimore’s subway and light rail systems would have been possible, it would’ve necessitated less frequent API calls, which would introduce the possibility of missing observations across all three modes of transit

<a id="license"></a>

## License

Copyright 2025, The Venetoulis Institute for Local Journalism

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

