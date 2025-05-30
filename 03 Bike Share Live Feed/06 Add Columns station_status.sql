use bikeshare
go

alter table dbo.station_status
add report_datetime datetime,
instance INT,
prev_report_datetime datetime,
status_duration_seconds INT,
capacity smallint,
pc_docks_available float,
availability_group varchar(50);