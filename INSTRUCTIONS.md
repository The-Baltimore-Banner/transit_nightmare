- [Get the data](#data)
- [Trip routing](#routing)
- [On-time percentage](#otp)
- [Transit system capacity](#capacity)


## Introduction

This repo will allow you to recreate the data findings from the Baltimore Banner's investigation TK.

You will use the instructions in this document to download the data that you'll need to perform the analysis, model thousands of routes to Baltimore middle and high schools and assess performance and capacity of the Maryland Transit Administration's bus system in and around Baltimore city.

Read carefully and pay attention to the annotation in every script. The code is designed to be relatively forgiving, but a missing piece or unfollowed direction could lead to errors or mistakes. 

If you run into difficulties or you can email [Greg Morton](sendto:greg.morton@thebaltimorebanner.com)



<a id="data"></a>

## Get the data

[Begin by downloading this repo's data folder from Amazon S3. Before you download, make sure you reserve enough hard drive space.]()

You'll be relying on a few different types of data for each analysis.

<a id="routing"></a>

## Trip routing

For route modeling, you will use Conveyal's open-source r5 model and its `r5r` interfce in R. The data folder.

The scripts you'll need for the routing analysis can be found in the `routing/` folder.

Before you begin routing, you'll need to make sure you have you run the `setup.R` script which includes school locations, and various Baltimore city shapes (for which you'll need a tidycensus API key). 

You'll have the option to generate your own origin points or use the ones we generated on Jan. 27, 2025.

Next, load tract-school combos and enrollment by school from the `student_info.R` file and info on MTA stops and routes from `mta_info.R`.

Before you start `r5r`, you'll need to make sure that you meet its [software requirements](https://ipeagit.github.io/r5r/articles/r5r.html#:~:text=You%20can%20install%20r5r%20from,the%20development%20version%20from%20github.&text=Please%20bear%20in%20mind%20that,need%20to%20install%20one%20JDK.). Namely, you'll want to ensure that you have installed Java Development Kit 21. Since `r5r` is Java-based, it will not work without the right version.

When you instantiate your `r5r_core` transit network object, make you'll have to make sure that you set aside enough RAM to run the routing functions. We use 24, but feel free to adjust based on your computer's specs.

We begin our analysis by estimating the latest departure time for each tract-school combination that would allow a student to arrive at school on time. 

Next, we'll save our results and prepare to model detailed routes.

We'll use a similar loop to model detailed trips from tract to school based on the departure times we've just modeled. 

