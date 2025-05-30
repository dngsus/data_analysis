/*
Apply transformations to ingested data.
First basic, e.g. datatypes and formatting. Then, more complex and notable changes like add columns for analysis.
In another context, might consider first staging table then prod-ready table, upon which further views etc. might be made.
But for this project, am only doing a single self-contained project, and all transformations will serve this, so apply changes straight to source data table
*/

/*
In this script, just apply the basic transformations mentioned above. More complex changes in next script
*/

use bikeshare
go

-- 1) Want to set foreign keys for data quality, but can't do so before addressing:
	-- Can't establish FK on VARCHAR(MAX) type;
	-- datatype of dependent table must match that of reference

--SELECT MIN(LEN(station_id)), MAX(LEN(station_id)) AS max_station_id_length FROM dbo.station_info;
-- 19, 36
--SELECT MIN(LEN(region_id)), MAX(LEN(region_id)) AS max_region_id_length FROM dbo.regions;
-- 2, 3

--ALTER TABLE station_info
--ALTER COLUMN station_id VARCHAR(50) NOT NULL;

ALTER TABLE station_status
ALTER COLUMN station_id VARCHAR(50) NOT NULL;

ALTER TABLE regions
ALTER COLUMN region_id VARCHAR(10) NOT NULL;

--ALTER TABLE station_info
--ALTER COLUMN region_id VARCHAR(10); -- NULL is accepted

-- Add PK: not NULL and is unique

ALTER TABLE regions
ADD CONSTRAINT PK_regions_region_id PRIMARY KEY (region_id);

-- station_id in station_info will possibly _not_ be unique, to accomodate SCD

-- region_id in station_info must exist as a region_id in regions
-- Acceptable for a region_id in station_info to be NULL
ALTER TABLE station_info
ADD CONSTRAINT FK_station_info_region_id FOREIGN KEY (region_id)
REFERENCES regions(region_id);

-- station_id in station_status must exist as a station_id in stationInfo
-- Can't do this because station_id is not PK of station_info
--ALTER TABLE station_status
--ADD CONSTRAINT FK_station_status_station_id FOREIGN KEY (station_id)
--REFERENCES station_info(station_id);

-- Change some column types that we know are binary:

ALTER TABLE station_status
ALTER COLUMN is_installed TINYINT;

ALTER TABLE station_status
ALTER COLUMN is_renting TINYINT;

ALTER TABLE station_status
ALTER COLUMN is_returning TINYINT;