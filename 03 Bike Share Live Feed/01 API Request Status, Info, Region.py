# Need to request station_info at same time/call as station_status, otherwise foreign key dependency liable to fail
# Though region foreign key far less likely to fail, still possible, so also call that here

import requests
import json
import pandas as pd
from datetime import datetime
import pytz
# from zoneinfo import ZoneInfo
from sqlalchemy import create_engine, text
import pyodbc

baseurl = "https://gbfs.lyft.com/gbfs/2.3/dca-cabi/en/"

def request(baseurl, endpoint):
    r = requests.get(baseurl + endpoint)
    return r.json()

# --- REGIONS ---

regions_json = request(baseurl, "system_regions.json")

regions = {}
all_regions = {}

num_regions = len(regions_json["data"]["regions"])

for x in range(0, num_regions):
    region = regions_json["data"]["regions"][x] # e.g. {"region_id": "40", "name": "Alexandria, VA"}
    # regions = {key : region.get(key) for key in region_keys}
    regions = region.get("name")
    all_regions[region.get("region_id")] = regions

df_regions = pd.DataFrame.from_dict(all_regions, orient = "index")
df_regions.reset_index(inplace=True)
df_regions.rename(columns = {"index" : "region_id", 0 : "name"}, inplace=True)

#  --------- Load into SQL Server:

server = 'DANIEL\\SQLEXPRESS'
database = 'bikeshare'

driver = 'ODBC Driver 18 for SQL Server'

connection_string = (
    f"mssql+pyodbc://@{server}/{database}?trusted_connection=yes&driver={driver.replace(' ', '+')}&TrustServerCertificate=yes"
)

engine = create_engine(connection_string)

# Consider potential outcomes of API request for regions:
# Potential that existing region_id has an update e.g. renamed
# Potential that a new station_id emerges (new region clasified)
# Potential that an existing region_id is no longer being pulled - has been declassified or merged into another pre-existing one.
    # However, a record of this information is still valuable

# To facilitate 'update/insert if new, keep existing' logic, require staging table then merge to working table if conditions met

df_regions.to_sql(
    name='regions_stg',
    con=engine,
    if_exists='replace',  # Each (new) API pull replaces the last in staging
    index=False
)

# Create structure of actual working table to load selected data from staging into
# Comment out - create once and done ... although 'replace' probably covers this anyway? ... Later figure out

# df_regions.head(0).to_sql(
#     name="regions",
#     con=engine,
#     if_exists="replace",
#     index=False
# )

# 3. Run MERGE into permanent table

merge_sql = """
MERGE regions AS target
USING regions_stg AS source
ON target.region_id = source.region_id
WHEN MATCHED THEN
    UPDATE SET
        [name] = source.[name]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([region_id], [name])
 VALUES (source.[region_id], source.[name]);
 """

with engine.begin() as conn:
    conn.execute(text(merge_sql))

# --- STATION INFO ---

stn_info_json = request(baseurl, "station_information.json")

# Will need to find information from every station --> loop.
# How many stations are there?

num_stations_info = len(stn_info_json["data"]["stations"])

# We only care about the station information from certain values in the dicts:

info_values = ["name", "short_name", "capacity", "region_id", "lat", "lon"]

# Collect information of interest in dict(s):

stn_info = {} # stn info per stn_id
all_info = {} # collection of all stn_info (stn_id defined by their statuses)

for x in range(0, num_stations_info):

    # stn = all status variables for the station_id at position 'x'.
    stn = stn_info_json["data"]["stations"][x]
    
    # Each 'stn' is a dict of all status variables pertaining to a stn_id, but we want to shorten this dict to contain only certain variables of interest:
    stn_info = {key: stn.get(key) for key in info_values}
   
    # Each 'stn_status' (of x in range) needs to be assigned as the value corresponding to the 'stn_id' (of x in range)
    all_info[stn.get("station_id")] = stn_info

# Since the 'station_ids' are the keys in all_stations, i.e. not values, they are taken as the index.
# But, dataframe in PBI needs this to instead be a column to query off of 
df_station_info = pd.DataFrame.from_dict(all_info, orient = "index")

# Since the 'station_ids' are the keys in all_stations, i.e. not values, they are taken as the index.
# But, dataframe in PBI needs this to instead be a column to query off of 
df_station_info.reset_index(inplace=True)

df_station_info.rename(columns = {"index" : "station_id"}, inplace=True)


# To handle slowly changing dimensions in station_info, create valid_from and valid_to timestamps
# valid_ stamps need to be in Eastern timezone to enable sensible joins for analysis (station reporting datetime vs valid timestamp)

eastern_time = pytz.timezone("US/Eastern")

df_station_info["valid_from"] = pd.to_datetime(datetime.now(eastern_time)).tz_localize(None)

# Need to explicitly cast as datetime to avoid problems arising from SQL Server autocasting as 'timestamp' type, which causes insertion issues
# Technically, the information was probably valid from a datetime earlier than 'now', but there is no native column diplaying this.
# Using now() is mostly functional for this project, although slight issue due to report datetime in station_status tending to be earlier than now(),
# i.e. we request API at time t, but the report from station is typically at t minus 5 mins.
# Therefore, first/initial join of station_status to station_info in SQL will yield no hits, so column 'capacity' in stn_status will be null.
# Workaround: after very first script run, truncate station_status in SQL, wait 5+ mins, and rerun script,
# thereby forcing acceptable time windows.
# Next issue will be that if/when the SCD in station_info does change in a future script run,
# the information for that particular station_id for that particular time will not update properly.
# This should be negligible, but worth considering 

# valid_to default to NULL and iff new info emerges, is to be changed to next valid_from = 'now'.
# Need to do in SQL script


#  --------- Load into SQL Server:

df_station_info.to_sql(
    name='station_info_stg',
    con=engine,
    if_exists='replace',  # Each (new) API pull replaces the last in staging
    index=False
)

# --- STATION STATUS ---

stn_status_json = request(baseurl, "station_status.json")

# Will need to find information from every station --> loop.
# How many stations are there?

num_stations_status = len(stn_status_json["data"]["stations"])

# We only care about the station information from certain values in the dicts:

status_values = ["is_installed", "num_bikes_available", "num_ebikes_available", "is_renting", "num_docks_available", "is_returning", "last_reported"]

# Collect information of interest in dict(s):

stn_status = {} # stn status per stn_id
all_status = {} # collection of all stn_status (stn_id defined by their statuses)

# Loop logic to capture that information of interest:

for x in range(0, num_stations_status):
    # stn = all status variables for the station_id at position 'x'.
    stn = stn_status_json["data"]["stations"][x]
    
    # Each 'stn' is a dict of all status variables pertaining to a stn_id, but we want to shorten this dict to contain only certain variables of interest:
    stn_status = {key : stn.get(key) for key in status_values}
   
    # Each 'stn_status' (of x in range) needs to be assigned as the value corresponding to the 'stn_id' (of x in range)
    all_status[stn.get("station_id")] = stn_status

# print(all_status)

df_station_status = pd.DataFrame.from_dict(all_status, orient = "index")

# Since the 'station_ids' are the keys in all_stations, i.e. not values, they are taken as the index.
# But, dataframe in PBI needs this to instead be a column to query off of 
df_station_status.reset_index(inplace=True)

df_station_status.rename(columns = {
    "index" : "station_id",
    "num_bikes_available" : "num_bikes_any_available",
    "num_ebikes_available" : "num_bikes_elec_available"},
    inplace=True)

# Split bikes by human-powered vs elec
df_station_status["num_bikes_pedal_available"] = df_station_status['num_bikes_any_available'] - df_station_status['num_bikes_elec_available']

# last_reported column is in timestamp format i.e. seconds since January 1, 1970 (UTC)
# Washington DC is EDT/EST timezone
# Convert to conventional format and split into date and time separate cols

df_station_status["last_reported"] = pd.to_datetime(df_station_status["last_reported"], unit="s"
                                                    ).dt.tz_localize("UTC").dt.tz_convert("America/New_York")

df_station_status["report_date"] = df_station_status["last_reported"].dt.date
df_station_status["report_time"] = df_station_status["last_reported"].dt.time

df_station_status.drop(columns=["last_reported"], inplace=True)

# For audit:
df_station_status["retrieved_at"] = datetime.now()

# Reorder columns for ease of viewing

df_station_status = df_station_status.iloc[:, [0, 1, 2, 7, 3, 4, 5, 6, 8, 9, 10]]

# print(df_station_status.head())

# print(df_station_status["report_date"].head())
# print(df_station_status["report_time"].head())

#  --------- Load into SQL Server:

df_station_status.to_sql(
    name = "station_status",
    con = engine,
    if_exists = "append", # Want to continuously add history of station status, not replace it each time
    index = False
)