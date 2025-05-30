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