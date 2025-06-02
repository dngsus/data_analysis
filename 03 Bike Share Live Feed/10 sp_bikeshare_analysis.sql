use bikeshare
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Dan>
-- Create date: <2025-06-02>
-- Description:	<Combined actions of files '04 Insert into station_info from station_info_stg' and '08 Shaping for Data Analysis>
-- =============================================


CREATE PROCEDURE sp_bikeshare_analysis
as
BEGIN

---------------------- Part 1: insert into station_info from station_info_stg ----------------------

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

---------------------- Part 2: transform table for analysis ----------------------

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
set report_datetime = new_col
where cast(retrieved_at as date) = cast(getdate() as date); -- once up and running, only want to use compute to update a limited set of rows
-- where station_id = '000_test' and capacity is null

-- 1b) Helper column: lag function to retrieve previous reading from station

with temp as 
(
select
	*,
	lag (report_datetime) over (partition by station_id order by station_id, report_datetime) checker
from dbo.station_status
)
update temp
set prev_report_datetime = checker
where cast(retrieved_at as date) = cast(getdate() as date); 
-- where station_id = '000_test' and capacity is null

-- 1d) Final column: calculate the difference in report date-times

update dbo.station_status
set status_duration_seconds =
case when prev_report_datetime is not null then datediff(second, prev_report_datetime, report_datetime)
else 0 end
where cast(retrieved_at as date) = cast(getdate() as date); 
-- and station_id = '000_test' and capacity is null;
-- if null, then this is first ever record of the station_id, so status_duration_seconds is null

-- 1e) Flag entries where duration too long (can't safely assume dock availability changes)
-- Can't delete, as this would break dataflow - after a single missed API call, and subsequent deletion of incoming rows,
-- new rows could never again 'survive'

/*
Delete from table where status_duration > 1800 seconds (30 mins)
-- Or is NULL --> first reading ever for that stn_id
-- Not conducive towards record-keeping, but for a project with this scope and context, will proceed

delete from dbo.station_status
where
--(
status_duration_seconds > 1800
or status_duration_seconds is null;
--) and station_id = '000_test' and capacity is null
*/

update dbo.station_status
set duration_flag =
case when status_duration_seconds <= 1800 then 0 else 1 end
where cast(retrieved_at as date) = cast(getdate() as date); 

-- 1f) Edge case - overnight reading: need attribute partial duration to last night and partial duration to today morning
-- Requires split into two rows (yday vs today report_date)

update dbo.station_status
set status_duration_yday = 
case when report_date = dateadd(d, 1, cast(prev_report_datetime as date)) 
then 
  DATEDIFF(SECOND, prev_report_datetime, report_date)
  else NULL end
 where cast(retrieved_at as date) = cast(getdate() as date); 
 -- where station_id = '000_test' and capacity is null

-- Noting that in an extreme case of missing API call, the gap could be >1 day.
-- Later, insertion of 'by_day' table filters by 'by_day is null / not null', so need to avoid populating in that case

update dbo.station_status
set [status_duration_today] = case when status_duration_yday is not null then status_duration_seconds - status_duration_yday
else status_duration_seconds end
where cast(retrieved_at as date) = cast(getdate() as date); 
 -- where station_id = '000_test' and capacity is null

-- 2) Move this here because will be wiping report_time in next steps
-- Categorise readings based on day of week + time of day
-- Weekend vs weekday
-- Rush-hour := (0700 - 0900; 1700 - 1900) on weekdays only
-- Would depend on hypothetical business standards
-- If wanting even more end-user customisability over times of interest, probably need to do as measures in PBI

update dbo.station_status
set [weekday] = case when datepart(dw, report_date) in (1, 7) then 0 else 1 end
where cast(retrieved_at as date) = cast(getdate() as date); 
--where station_id = '000_test' and capacity is null

update dbo.station_status
set rush_hour =
	case
		when ((report_time >= '07:10:00.000' and report_time <= '09:05:00.000') or (report_time >= '17:10:00.000' and report_time <= '19:05:00.000'))
		and weekday = 1
		then 1 else 0
	end
where cast(retrieved_at as date) = cast(getdate() as date); 
--where station_id = '000_test' and capacity is null


-- For this hypothetical business, rush_hour is accepted to be 7am - 9am, 5pm - 7pm
-- Noting that report_time from station appears to be typically 5 minutes before the API request,
-- and API requests are scheduled for every 1/4 hour,
-- then we can approximate a rule-time for 7.10am and 5.10pm.
-- There will be slightly errant data due to imperfect timings, but should be good enough.
-- Notice: a reading with report_time = 07:01:00 is essentially 6.45-7am, so basically not rush hour

-- 3a) Retrieve capacity from station_info, noting correct valid_from and to

update stat
set stat.capacity = info.capacity
from dbo.station_info info
join station_status stat
on info.station_id = stat.station_id
and stat.report_datetime >= info.valid_from
and
(info.valid_to is null or info.valid_to >= stat.report_datetime)
where cast(retrieved_at as date) = cast(getdate() as date);
--where stat.station_id = '000_test' and stat.capacity is null

-- 3b) Calculate % of docks which are available

update dbo.station_status
set pc_docks_available = (1.0 * num_docks_available / capacity)
where cast(retrieved_at as date) = cast(getdate() as date); -- or station_id = '000_test'; 

-- 3c) Categorical definitions of (2b)

update dbo.station_status
set availability_group = case
	when num_docks_available = 0 then 'full'
	when (pc_docks_available > 0 and pc_docks_available < 0.2) or num_docks_available <= 2 then 'near full'
	when pc_docks_available >= 0.2 and pc_docks_available < 0.8 then 'in use'
	when (pc_docks_available >= 0.8 and pc_docks_available < 1) or num_bikes_any_available <= 2 then 'near empty'
	when pc_docks_available = 1 then 'empty'
end
where cast(retrieved_at as date) = cast(getdate() as date); -- or station_id = '000_test';

-- 1g) If edge case, need this reading represented across two rows: one for portion yesterday (report_date - 1), one for today (report_date)

/*
As we split edge cases into two rows, also replace original report_date column, and drop report_time (won't make sense anymore in the case of overnights),
and prev_report_datetime has served its purpose as a helper column.
--> Define new table dbo.station_status_by_day to encompass this data - technically not necessarily 'by day' if there is a > 24hr gap in recordings.
*/

-- truncate table dbo.station_status_by_day

insert into dbo.station_status_by_day
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
report_date, weekday, rush_hour, retrieved_at, duration_seconds, duration_flag, capacity, pc_docks_available, availability_group)

select
    station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
	-- report_date, report_time,
	DATEADD(DAY, -1, report_date), -- report_date
	weekday, rush_hour, retrieved_at, -- prev_report_datetime,
	status_duration_yday, -- duration_seconds
	duration_flag, capacity, pc_docks_available, availability_group
from dbo.station_status ss
where status_duration_yday is not null
and not exists (select 1 from dbo.station_status_by_day byday where ss.station_id = byday.station_id and ss.retrieved_at = byday.retrieved_at)

union all

select
    station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
	-- report_date, report_time,
	report_date,
	weekday, rush_hour, retrieved_at, -- prev_report_datetime,
	status_duration_today, -- duration_seconds
	duration_flag, capacity, pc_docks_available, availability_group
from dbo.station_status ss
where not exists (select 1 from dbo.station_status_by_day byday where ss.station_id = byday.station_id and ss.retrieved_at = byday.retrieved_at)

-- If an overnight entry was split Sunday/Monday, it would have read as weekday = 0, as today = monday,
-- but now with the new Sunday entry, there needs to be weekday = 1 for that --> reset weekday flag

update dbo.station_status_by_day
set [weekday] = case when datepart(dw, report_date) in (1, 7) then 0 else 1 end
where cast(retrieved_at as date) = cast(getdate() as date); -- or station_id = '000_test';

-- No need to correct for rush_hour, as overnights will not be rush hour

END