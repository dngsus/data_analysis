USE [bikeshare]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[station_status_analysis](
	[station_id] [varchar](50) NOT NULL,
	[availability_group] varchar(50),
	[region_name] [varchar](MAX) NULL,
	[lat] [float] NULL,
	[lon] [float] NULL,
	[total_status_duration] INT,
	[total_seconds_available] INT,
	[pc_time_status] FLOAT
)

