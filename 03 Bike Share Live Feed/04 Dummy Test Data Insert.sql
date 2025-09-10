--delete from  dbo.station_info
--where station_id = '000_test'

insert into dbo.station_info
(station_id, name, short_name, capacity, region_id, lat, lon, valid_from, valid_to)
values
('000_test', 'test_name', 'test_name_short', 10, '41', 1000, 1000, '2025-05-01', NULL)

select * from dbo.station_info where station_id = '000_test'


--delete from  dbo.station_status where station_id = '000_test'

insert into dbo.station_status -- overnight edge case
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-30', '23:55:00.0000000', '2025-05-30 23:56:00.000')

insert into dbo.station_status -- overnight edge case
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 3, 1, 2, 1, 7, 1, '2025-05-31', '00:10:00.0000000', '2025-05-31 00:11:00.000')

insert into dbo.station_status -- reading right before overnight edge case
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 4, 2, 2, 1, 6, 1, '2025-05-30', '23:50:00.0000000', '2025-05-30 23:51:00.000')

select * from dbo.station_status where station_id = '000_test' order by report_date, report_time


insert into dbo.station_status -- rush hour = yes
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,

ilable, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-30', '19:00:00.0000000', '2025-05-30 19:00:00.000')

insert into dbo.station_status -- rush hour = yes
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-30', '18:45:00.0000000', '2025-05-30 18:45:00.000')

insert into dbo.station_status -- rush hour = no
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-30', '21:00:00.0000000', '2025-05-30 21:00:00.000')

insert into dbo.station_status -- rush hour = no
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-30', '20:45:00.0000000', '2025-05-30 20:45:00.000')

insert into dbo.station_status -- duration gap too large
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-27', '21:00:00.0000000', '2025-05-27 21:00:00.000')

insert into dbo.station_status -- duration gap too large
(station_id, is_installed, num_bikes_any_available, num_bikes_pedal_available, num_bikes_elec_available, is_renting,
num_docks_available, is_returning,
report_date, report_time, retrieved_at 
)
values
('000_test', 1, 5, 3, 2, 1, 5, 1, '2025-05-25', '20:45:00.0000000', '2025-05-25 20:45:00.000')

select * from dbo.station_status where station_id = '000_test'
order by station_id, report_datetime
