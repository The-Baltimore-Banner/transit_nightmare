import time
import json
import requests
from datetime import datetime
import boto3
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
import pytz
import os
from dotenv import load_dotenv

load_dotenv("env_variables.env")



# Define the headers and URL for the API request
headers = {
    'Authorization': os.environ.get('SWIFTLY_AUTHORIZATION_TOKEN'),
    'Content-Type': 'application/octet-stream',
    'Accept': 'application/json'
}

# MTA vehicle positions data 
positions_url = 'https://api.goswift.ly/real-time/mta-maryland-light-rail/gtfs-rt-vehicle-positions'

positions_queryString = {
    'format': 'json',
    'enable-feature': 'deleted-trips'
}

# Define slack stuff
SLACK_BOT_TOKEN = os.environ.get('SLACK_BOT_TOKEN')
client = WebClient(token=SLACK_BOT_TOKEN)
channel_id = "mta-updates"

# Initialize the S3 client
s3_client = boto3.client('s3')
S3_BUCKET = 's3-tbb-data-dev'

# Function to fetch vehicle positions
def fetch_vehicle_positions():
    # Generate a unique filename with a timestamp
    utc_now = datetime.now(pytz.utc)
    et_timezone = pytz.timezone('US/Eastern')
    et_now = utc_now.astimezone(et_timezone)
    timestamp = et_now.strftime("%Y%m%d%H%M%S")
    hour_folder = et_now.strftime("%Y-%m-%d-%H")
    day_folder = et_now.strftime("%Y-%m-%d")
    JSON_FOLDER_PATH = f'school-transportation/vehicle-positions/json/{day_folder}/{hour_folder}_lr/'
    filename = f"{JSON_FOLDER_PATH}positions_data_{timestamp}.json"

    # Fetch vehicle positions
    positions_response = requests.get(positions_url, params=positions_queryString, headers=headers)
    if positions_response.status_code != 200:
        error_date = datetime.now().astimezone(et_timezone).strftime('%Y-%m-%d %H:%M:%S')
        error_message = f'<!channel> Failed to fetch bus locations at {error_date}. Status: {positions_response.status_code} :rotating_light:'

        try:
            response = client.chat_postMessage(
                channel=channel_id,
                text=error_message
            )
            print(response)
        except SlackApiError as e:
            print(f"Error sending message: {e.response['error']}")
    else:
        positions_data = positions_response.json()
        json_data = json.dumps(positions_data)

        # Check if folder exists, if not, create it
        hour_folder_exists = s3_client.list_objects_v2(Bucket=S3_BUCKET, Prefix=f"{JSON_FOLDER_PATH}")
        if not hour_folder_exists.get('Contents'):
            s3_client.put_object(Bucket=S3_BUCKET, Key=f"{JSON_FOLDER_PATH}")
            finish_time_utc = datetime.now(pytz.utc)
            finish_time_et = finish_time_utc.astimezone(et_timezone)
            finish_timestamp = finish_time_et.strftime('%Y-%m-%d %H:%M:%S')
            s3_link = f"https://us-east-1.console.aws.amazon.com/s3/buckets/s3-tbb-data-dev?prefix={JSON_FOLDER_PATH}&region=us-east-1&bucketType=general"
            new_folder_message = f':white_check_mark:  <{s3_link}|New Lightrail folder.>\n\nCreated at {finish_timestamp}'

            try:
                response = client.chat_postMessage(
                    channel=channel_id,
                    text=new_folder_message
                )
                print(response)
            except SlackApiError as e:
                print(f"Error sending message: {e.response['error']}")

        # Upload the JSON data to S3
        s3_client.put_object(Bucket=S3_BUCKET, Key=filename, Body=json_data)

# Function to check if the current time is within the specified schedule
def is_within_schedule():
    start_time = 4  # 4 AM ET
    end_time = 25  # 1 AM ET (next day, so 25th hour of the same day)
    eastern = pytz.timezone('US/Eastern')
    current_time = datetime.now(eastern).hour + datetime.now(eastern).minute / 60

    if end_time < start_time:
        end_time += 24

    return start_time <= current_time < end_time

# Main function
def main():
    while True:
        if is_within_schedule():
            start_time = time.time()
            fetch_vehicle_positions()
            elapsed_time = time.time() - start_time
            sleep_time = max(0, 5 - elapsed_time)
            time.sleep(sleep_time)
        else:
            time.sleep(300)  # Sleep for 5 minutes

if __name__ == '__main__':
    main()




