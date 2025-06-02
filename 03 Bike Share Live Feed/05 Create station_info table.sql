use bikeshare
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[station_info](
	[station_id] [varchar](50) NOT NULL,
	[name] [varchar](100) NULL,
	[short_name] [varchar](50) NULL,
	[capacity] [smallint] NULL,
	[region_id] [varchar](10) NULL,
	[lat] [float] NULL,
	[lon] [float] NULL,
	[valid_from] datetime NOT NULL,
	[valid_to] datetime NULL
	)