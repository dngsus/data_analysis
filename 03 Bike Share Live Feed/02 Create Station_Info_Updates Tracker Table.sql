use bikeshare
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create table dbo.station_info_updates
(
    max_info_id int,
    updated datetime
)