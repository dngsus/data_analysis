USE [bikeshare]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[station_status](
	[station_id] [varchar](50) NOT NULL,
	[is_installed] [tinyint] NULL,
	[num_bikes_any_available] [tinyint] NULL,
	[num_bikes_pedal_available] [tinyint] NULL,
	[num_bikes_elec_available] [tinyint] NULL,
	[is_renting] [tinyint] NULL,
	[num_docks_available] [tinyint] NULL,
	[is_returning] [tinyint] NULL,
	[report_date] [date] NULL,
	[report_time] [time](7) NULL,
	[weekday] [tinyint] NULL,
	[rush_hour] [tinyint] NULL,
	[retrieved_at] [datetime] NULL,
	[report_datetime] [datetime] NULL,
	--[next_report_date] [date] NULL,
	[prev_report_datetime] [datetime] NULL,
	[status_duration_seconds] [int] NULL,
	[duration_flag] [tinyint] NULL,
	[status_duration_yday] [int] NULL,
	[status_duration_today] [int] NULL,
	[capacity] [smallint] NULL,
	[pc_docks_available] [float] NULL,
	[availability_group] [varchar](50) NULL
) ON [PRIMARY]
GO