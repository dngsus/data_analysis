use bikeshare
go

with regional_status_duration as
(
select
region_name, availability_group, sum(total_status_duration) sum_status_duration
from dbo.station_status_analysis 
group by region_name, availability_group
),
regional_total_duration as
(
select
region_name, sum(total_seconds_available) sum_seconds_available
from
	(
	select region_name, station_id, max(total_seconds_available) total_seconds_available
	from dbo.station_status_analysis 
	group by region_name, station_id
	) dedupe
group by region_name
),
regional_lat_lon as
(
select
	region_name, avg(lat) lat, avg(lon) lon
	from 
	(
	select ssa.region_name, ssa.station_id, max(info.lat) lat, max(info.lon) lon
	from
		dbo.station_status_analysis ssa
			join dbo.regions reg
				on ssa.region_name = reg.name
			join dbo.station_info info
				on reg.region_id = info.region_id
	group by ssa.region_name, ssa.station_id
	) dedupe
group by region_name
)

insert into [dbo].[regional_status_analysis]
(lat, lon, region_name, availability_group, total_status_duration, total_seconds_available, pc_time_status)

select rll.lat, rll.lon, rsd.*, rtd.sum_seconds_available, (1.0 * rsd.sum_status_duration / rtd.sum_seconds_available)
from regional_status_duration rsd
	join regional_total_duration rtd on rsd.region_name = rtd.region_name
	join regional_lat_lon rll on rsd.region_name = rll.region_name


select * from dbo.regional_status_analysis
