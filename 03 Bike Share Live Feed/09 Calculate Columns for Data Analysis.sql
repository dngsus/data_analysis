/*
Further transformations of tables to enable analysis, displayed in table dbo.station_status_by_day
*/

use bikeshare
go

declare @today date = cast(getdate() as date);

delete from dbo.station_status where report_date = '1970-01-01';

/*
(1) Populate columns

-- window funcs only acceptable in select, order by, and some other cases
-- need CTE as wrapper to enable update values
*/

-- Need this one first as stn_info_id UPDATE is dependent
with temp as 
(
select
	*,
	CONVERT(DATETIME2,CONVERT(VARBINARY(6),report_time)+CONVERT(BINARY(3),report_date)) new_col
from dbo.station_status
)
update temp
set report_datetime = new_col
where cast(retrieved_at as date) = @today; -- once up and running, only want to use compute to update a limited set of rows
-- where station_id = '000_test' and capacity is null

-- Populate stn_info_key to enable match between status.stn_info_id = info.info_id
-- Since info.station_id is not unique, as there may be SCD

-- Need this here as future UPDATE statements are dependent
update stat
set stat.stn_info_id = info.info_id
from dbo.station_status stat
join dbo.station_info info
	on stat.station_id = info.station_id
	and stat.report_datetime >= info.valid_from
	and (stat.report_datetime < info.valid_to or info.valid_to is null)
where cast(stat.retrieved_at as date) = @today; -- once up and running, only want to use compute to update a limited set of rows

-- Helper column: lag function to retrieve previous reading from station

with temp as 
(
select
	*,
	lag (report_datetime) over (partition by station_id order by station_id, report_datetime) checker
from dbo.station_status
)
update temp
set prev_report_datetime = checker
where cast(retrieved_at as date) = @today; 
-- where station_id = '000_test' and capacity is null

-- Final column: calculate the difference in report date-times

update dbo.station_status
set status_duration_seconds =
case when prev_report_datetime is not null then datediff(second, prev_report_datetime, report_datetime)
else 0 end
where cast(retrieved_at as date) = @today; 
-- and station_id = '000_test' and capacity is null;
-- if null, then this is first ever record of the station_id, so status_duration_seconds is null

-- Flag entries where duration too long (can't safely assume dock availability changes)
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
where cast(retrieved_at as date) = @today; 

-- Edge case - overnight reading: need attribute partial duration to last night and partial duration to today morning
-- Requires split into two rows (yday vs today report_date)

update dbo.station_status
set status_duration_yday = 
case when report_date = dateadd(d, 1, cast(prev_report_datetime as date)) 
then 
  DATEDIFF(SECOND, prev_report_datetime, report_date)
  else NULL end
 where cast(retrieved_at as date) = @today; 
 -- where station_id = '000_test' and capacity is null

update dbo.station_status
set [status_duration_today] = case when status_duration_yday is not null then status_duration_seconds - status_duration_yday
else status_duration_seconds end
where cast(retrieved_at as date) = @today; 
 -- where station_id = '000_test' and capacity is null

-- Move this here because will be wiping report_time in next steps
-- Categorise readings based on day of week + time of day
-- Weekend vs weekday
-- Rush-hour := (0700 - 0900; 1700 - 1900) on weekdays only
-- Would depend on hypothetical business standards
-- If wanting even more end-user customisability over times of interest, probably need to do as measures in PBI

update dbo.station_status
set [weekday] = case when datepart(dw, report_date) in (1, 7) then 0 else 1 end
where cast(retrieved_at as date) = @today; 
--where station_id = '000_test' and capacity is null

-- For this hypothetical business, rush_hour is accepted to be 7am - 9am, 5pm - 7pm
-- Noting that report_time from station appears to be typically 5 minutes before the API request,
-- and API requests are scheduled for every 1/4 hour,
-- then we can approximate a rule-time for 7.10am and 5.10pm.
-- There will be slightly errant data due to imperfect timings, but should be good enough.
-- Notice: a reading with report_time = 07:01:00 is essentially 6.45-7am, so basically not rush hour

update dbo.station_status
set rush_hour =
	case
		when ((report_time >= '07:10:00.000' and report_time <= '09:05:00.000') or (report_time >= '17:10:00.000' and report_time <= '19:05:00.000'))
		and weekday = 1
		then 1 else 0
	end
where cast(retrieved_at as date) = @today; 
--where station_id = '000_test' and capacity is null

-- Retrieve capacity from station_info

update stat
set stat.capacity = info.capacity
from dbo.station_info info
join station_status stat
on info.info_id = stat.stn_info_id
where cast(retrieved_at as date) = @today; -- once up and running, only want to use compute to update a limited set of rows
--where stat.station_id = '000_test' and stat.capacity is null

-- Calculate % of docks which are available

update dbo.station_status
set pc_docks_available = (1.0 * num_docks_available / capacity)
where cast(retrieved_at as date) = @today; -- or station_id = '000_test'; 

-- Categorical definitions of above percentages

--select distinct capacity from dbo.station_info order by 1
-- 8 to 55
-- If smaller stations emerge, might have to adapt logic, as num_docks / num_bikes available <= 2 is somewhat expected, arguably not 'near full/empty'

update dbo.station_status
set availability_group = case
	when is_installed + is_returning + is_renting < 3 then 'not functional'
	when num_docks_available = 0 then 'full'
	when (pc_docks_available > 0 and pc_docks_available < 0.2) or num_docks_available between 1 and 2 then 'near full'
	when pc_docks_available >= 0.2 and pc_docks_available < 0.8 then 'in use'
	when (pc_docks_available >= 0.8 and pc_docks_available < 1) or num_bikes_any_available between 1 and 2 then 'near empty'
	when num_docks_available = capacity then 'empty'
end
where cast(retrieved_at as date) = @today; -- or station_id = '000_test';

/*
Generate fact table which accounts for edge cases (overnights),
whereby an overnight entry has a portion attributed to yesterday (yday), and also today.

As we split edge cases into two rows, also replace original report_date column, and drop report_time (won't make sense anymore in the case of overnights),
and prev_report_datetime has served its purpose as a helper column.

--> Define new table dbo.station_status_by_day to encompass this data - technically not necessarily 'by day' if there is a > 24hr gap in recordings
(there would be no rows with the interim date(s)).
*/

-- truncate table dbo.station_status_by_day

insert into dbo.station_status_by_day
(stn_info_id, station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
report_date, weekday, rush_hour, retrieved_at, duration_seconds,
--duration_flag,
capacity, pc_docks_available, availability_group)

select
    stn_info_id, station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
	-- report_date, report_time,
	DATEADD(DAY, -1, report_date), -- report_date
	weekday, rush_hour, retrieved_at, -- prev_report_datetime,
	status_duration_yday, -- duration_seconds
	capacity, pc_docks_available, availability_group
from dbo.station_status ss
where
	status_duration_yday is not null
	and duration_flag = 0 -- we can exclude these now. Only point to keep them in station_status is to ensure prev_report_datetime is accurate
	and not exists (select 1 from dbo.station_status_by_day byday where ss.station_id = byday.station_id and ss.retrieved_at = byday.retrieved_at)

union all

select
    stn_info_id, station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting, num_docks_available, is_returning,
	-- report_date, report_time,
	report_date,
	weekday, rush_hour, retrieved_at, -- prev_report_datetime,
	status_duration_today, -- duration_seconds
	capacity, pc_docks_available, availability_group
from dbo.station_status ss
where
	duration_flag = 0 -- we can exclude these now. Only point to keep them in station_status is to ensure prev_report_datetime is accurate
	and not exists (select 1 from dbo.station_status_by_day byday where ss.station_id = byday.station_id and ss.retrieved_at = byday.retrieved_at)
-- If an overnight entry was split Sunday/Monday, it would have read as weekday = 0, as today = monday,
-- but now with the new Sunday entry, there needs to be weekday = 1 for that --> reset weekday flag accordingly

update dbo.station_status_by_day
set [weekday] = case when datepart(dw, report_date) in (1, 7) then 0 else 1 end
where cast(retrieved_at as date) = @today -- or station_id = '000_test';

-- No need correct rush hour, as overnights will always have rush_hour = 0