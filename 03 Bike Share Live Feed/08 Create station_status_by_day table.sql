USE [bikeshare]
GO
--drop table dbo.station_status_by_day
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[station_status_by_day](
	[stn_info_id] [int] NULL,
	[station_id] [varchar](50) NOT NULL,
	[is_installed] [tinyint] NULL,
	[num_bikes_any_available] [tinyint]  NULL,
	[num_bikes_pedal_available] [tinyint]  NULL,
	[num_bikes_elec_available] [tinyint]  NULL,
	[is_renting] [tinyint] NULL,
	[num_docks_available] [tinyint] NULL,
	[is_returning] [tinyint] NULL,
	[report_date] [date] NULL,
	[weekday] [tinyint] NULL,
	[rush_hour] [tinyint] NULL,
	[retrieved_at] [datetime] NULL,
	[duration_seconds] [int] NULL,
	-- [duration_flag] [tinyint] NULL, -- only used in station_status
	[capacity] [tinyint]  NULL,
	[pc_docks_available] [float] NULL,
	[availability_group] [varchar](50) NULL
) ON [PRIMARY]
GO