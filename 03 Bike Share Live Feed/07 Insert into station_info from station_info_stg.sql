/*
station_info_stg is from .py script.

Need do insertion logic into station_info table here, including formation of valid_to column
*/

use bikeshare
go

/*
Insert into final from staging if:
- Totally new station_id
- Existing station_id, but information e.g. capacity has changed (SCD)

Retain (station_id + info) in final even if does not exist in staging
*/

insert into dbo.station_info
(
station_id, name, short_name, capacity, region_id, lat, lon, valid_from, valid_to
)
select stg.station_id, stg.name, stg.short_name, stg.capacity,
case when stg.region_id is not null then stg.region_id else 0 end,
stg.lat, stg.lon, stg.valid_from, null -- default valid_to is null := indefinitely true
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

/*
For map visual, we want the 'average latitude/longitude of stations within respective regions' to represent the singular 'location' of each region for visual purposes.
Can alternatively use auto locator in PBI, but this gives a more true-to-business view of where stations are.
Ultimately rather minor cosmetics...

It is known that stations can change due to changes to capacity: 
select * from dbo.station_info where station_id = '08265124-1f3f-11e7-bf6b-3863bb334450'

Assume lat/long however won't change.
Therefore, only time the regional lat/lon needs updating is when there is a totally new station inserted into dbo.station_info.
As of now, there is no way to tell if new insertion is for totally new station, or just updated pre-existing one.
Nevertheless, both types of update are so infrequent, so doesn't really matter. So, if ever PK 'info_id' increase --> run update
*/

if
	(select max(info_id) from dbo.station_info) -- as the PK, info_id automatically updates (increases) when new row inserted
	> (select max(max_info_id) from dbo.station_info_updates)
begin
	with unique_info as -- station_info contains possible dupes of station_id.
	-- If duplicates remained, then the final lat/lon would gravitate towards more severely duplicated stations.
	(
	select min(lat) lat, min(lon) lon, station_id, region_id
	from dbo.station_info
	group by station_id, region_id
	),
	two as
	(
	select reg.region_id, reg.name, avg(un.lat) lat, avg(un.lon) lon
	from dbo.regions reg join unique_info un on reg.region_id = un.region_id
	group by reg.region_id, reg.name
	) 
	update dbo.regions
	set lat = two.lat,
	lon = two.lon
	from dbo.regions reg
	join two on reg.region_id = two.region_id

	-- Insert new entry into tracker
	insert into dbo.station_info_updates
	(max_info_id, updated)
	values
	((select max(info_id) from dbo.station_info), getdate())
end