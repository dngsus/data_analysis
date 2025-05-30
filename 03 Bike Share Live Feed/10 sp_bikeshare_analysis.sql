use bikeshare
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Dan>
-- Create date: <2025-05-29>
-- Description:	<Combined actions of files '02 Insert into station_info from station_info_stg' and '04 Shaping for Data Analysis>
-- =============================================

CREATE PROCEDURE sp_bikeshare_analysis
as

insert into dbo.station_info
(
station_id, name, short_name, capacity, region_id, lat, lon, valid_from, valid_to
)
select stg.station_id, stg.name, stg.short_name, stg.capacity, stg.region_id, stg.lat, stg.lon, stg.valid_from, null -- default valid_to is null := indefinitely true
from station_info_stg stg
left join station_info info
	on stg.station_id = info.station_id
	and info.valid_to is null -- specifically comparing SCD of API call vs latest saved entry. I.e. that particular row
where
	info.station_id is null -- totally new station_id
	or ( -- or, any new information about the station_id
       info.name <> stg.name
	   or info.short_name <> stg.short_name
       or info.capacity <> stg.capacity
       or info.region_id <> stg.region_id
       or info.lat <> stg.lat
       or info.lon <> stg.lon
   );

/*
If indeed there is new entry, the valid_to of the now outdated entry needs to equal the valid_from of the incoming new entry
*/

update info
set info.valid_to = stg.valid_from
from station_info info
join station_info_stg stg
    on info.station_id = stg.station_id
where info.valid_to IS NULL
  and (
       info.name <> stg.name
	   or info.short_name <> stg.short_name
       or info.capacity <> stg.capacity
       or info.region_id <> stg.region_id
       or info.lat <> stg.lat
       or info.lon <> stg.lon
  );

---------------------- Part 2: Transform Table for Analysis ----------------------

delete from dbo.station_status where report_date = '1970-01-01';

-- 1a) Helper column: combine report date and report time into single date-time to facilitate accurate calculations across dates

-- window funcs only acceptable in select, order by, and some other cases
-- need CTE as wrapper to enable update values

with temp as 
(
select
	*,
	CONVERT(DATETIME2,CONVERT(VARBINARY(6),report_time)+CONVERT(BINARY(3),report_date)) new_col
from dbo.station_status
)
update temp
set report_datetime = new_col;

-- 1b) Helper column to order station_id reports by date-time

with temp as 
(
select
	*,
	ROW_NUMBER() over (partition by station_id order by report_datetime) rown
from dbo.station_status
)
update temp
set instance = rown;

-- 1c) Helper column: lag function to retrieve previous reading from station

with temp as 
(
select
	*,
	lag (report_datetime) over (partition by station_id order by station_id, report_datetime) checker
from dbo.station_status
)
update temp
set prev_report_datetime = checker;

-- 1d) Final column: calculate the difference in report date-times

update dbo.station_status
set status_duration_seconds = datediff(second, prev_report_datetime, report_datetime)
where instance > 1; -- if instance = 1, then this is first ever record of the station_id, so the datediff will be null
-- leave as null

-- 2a) Retrieve capacity from station_info, noting correct valid_from and to

update stat
set stat.capacity = info.capacity
from dbo.station_info info
join station_status stat
on info.station_id = stat.station_id
and stat.report_datetime >= info.valid_from
and
(info.valid_to is null or info.valid_to >= stat.report_datetime)

-- 2b) Calculate % of docks which are available

update dbo.station_status
set pc_docks_available = (1.0 * num_docks_available / capacity)

-- 2c) Categorical definitions of (2b)

update dbo.station_status
set availability_group = case
	when num_docks_available = 0 then 'full'
	when (pc_docks_available > 0 and pc_docks_available < 0.2) or num_docks_available <= 2 then 'near full'
	when pc_docks_available >= 0.2 and pc_docks_available < 0.8 then 'in use'
	when (pc_docks_available >= 0.8 and pc_docks_available < 1) or num_bikes_any_available <= 2 then 'near empty'
	when pc_docks_available = 1 then 'empty'
end;

-- 2d) The proportion of time spent in each categorical status is [time in status] / [total time available]

-- 2d-i) wipe the output table
truncate table [dbo].[station_status_analysis];

-- 2d-ii) generate data for output table
with one as
(
select
	ss.station_id,
	info.region_id,
	info.lat,
	info.lon,
	availability_group,
	sum(status_duration_seconds) total_status_duration_seconds
from dbo.station_status ss
	left join dbo.station_info info
		on ss.station_id = info.station_id
where
	status_duration_seconds <= 1800 -- half hour max. Otherwise void from analysis
	and status_duration_seconds is not null
group by ss.station_id, availability_group, info.region_id, info.lat, info.lon -- eliminates dupes
),
two as
(
select
	station_id,
	sum(status_duration_seconds) total_seconds_available
from dbo.station_status
where
	status_duration_seconds <= 1800 -- half hour max. Otherwise void from analysis
	and status_duration_seconds is not null
group by station_id -- does not eliminate dupes. Need cte 'three'
),
three as
(
select
	station_id,
	max(total_seconds_available) total_seconds_available -- otherwise, will have dupes because earlier entries for that station have a different (lower) total than later ones
from two
group by station_id
),
four as
(
select one.*, three.total_seconds_available
from one join three on one.station_id = three.station_id
)
--select * from four where total_seconds_available = 0

-- select * from dbo.station_status where station_id = 'abd8bd04-94ec-4818-baf5-7f79742e982c'
-- select * from dbo.station_info where station_id = 'abd8bd04-94ec-4818-baf5-7f79742e982c'
-- select * from dbo.station_status_analysis where station_id = 'abd8bd04-94ec-4818-baf5-7f79742e982c'

insert into [dbo].[station_status_analysis]
(
station_id, availability_group, region_id, lat, lon, total_status_duration, total_seconds_available, pc_time_status
)
select
	station_id, availability_group, region_id, lat, lon, total_status_duration_seconds, total_seconds_available,
	(1.0 * four.total_status_duration_seconds / four.total_seconds_available) pc_time_status
from four
where four.total_seconds_available > 0
-- divide by zero error will occur when total_seconds_available = 0.
-- This itself is due to the emergence of either a totally new station_id,
-- or a station_id which has previously been introduced but time_gap was always > 1800 seconds so no record kept

