use bikeshare 
go

exec sp_bikeshare_analysis;

select * from dbo.station_info where station_id = '0099b016-32c9-4536-ac4c-dcc1a117bd95';

select top 100 * from dbo.station_status order by case when station_id = '0099b016-32c9-4536-ac4c-dcc1a117bd95' then 0 else 1 end, retrieved_at desc, station_id;

select top 100 * from dbo.station_status_by_day order by case when station_id = '0099b016-32c9-4536-ac4c-dcc1a117bd95' then 0 else 1 end, retrieved_at desc, station_id;
