/*
Version changes:
- Convert column datatypes
- Place into working table dbo.campaigns
- Protect staging table against edits
*/

/*
Apply transformations to staging table to produce usable working table upon which analysis may be conducted.
*/

/*
Actions:

1) Introduce id column 'campaign_round_id'.
Justification: standard table structure.

Avoid naming 'campaign_id' as this may mistakenly be thought to represent internal terminology referencing an overall 'campaign'.
However, each row actually represents a particular 'round' within a campaign, within which a particular customer is targeted,
potentially multiple times, as displayed in column 'campaign' - to be renamed 'contacts_current'.

2) Rename column: pdays --> days_since_prev.
3) Rename column: campaign --> contacts_current.
4) Rename: previous --> contacts_total_prev.
5) Rename: y --> success.

Justification (2 - 5): enhance clarity of column purpose; more aptly match data dictionary.

6) Edit columns to be binary 1/0 when ingested table displays them as 'yes'/'no'.

Justification: enable aggregations, easier filtering

7) Ensure datatype of columns in (6) is explicitly tinyint, so that mathematical operations may be carried out on them.
I.e. as they have been brought in as type nvarchar, and '0' and '1' are admitted by nvarchar, the datatype will not automatically change.

8) Edit month column to be as a number rather than abbreviation.

Justification: simpler filtering, cleaner look, easier to sequence.
*/

use bank_marketing
go
--drop table dbo.campaigns_stg

-- 1) Create staging table - with newly chosen column names and datatypes and data values

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[campaigns_stg](
	[campaign_round_id] [int] IDENTITY (1,1) not null,
	[age] [tinyint] NOT NULL,
	[job] [nvarchar](50) NOT NULL,
	[marital] [nvarchar](50) NOT NULL,
	[education] [nvarchar](50) NOT NULL,
	[default] [tinyint] NOT NULL,
	[balance] [int] NOT NULL,
	[housing] [tinyint] NOT NULL,
	[loan] [tinyint] NOT NULL,
	[contact] [nvarchar](50) NOT NULL,
	[day] [tinyint] NOT NULL,
	[month] [tinyint] NOT NULL,
	[duration] [smallint] NOT NULL,
	[contacts_current] [tinyint] NOT NULL,
	[days_since_prev] [smallint] NOT NULL,
	[contacts_total_prev] [smallint] NOT NULL,
	[poutcome] [nvarchar](50) NOT NULL,
	[success] [tinyint] NOT NULL
) ON [PRIMARY]
GO

-- 2) Insert into staging from ingested, and into working from staging

/*
Whilst extremely unlikely, cannot technically guarantee that (hypothetical) new entries into campaigns are unique/not on the basis of existing columns provided.
I.e. even if a new row were to have exact same age, job, marital, etc. as an already existing row, this might not be a duplicate.

So, cannot apply protections against dupes using e.g. where not exists (columns all match), or constraint command etc.

Option 1: wipe staging table each time and re-create + re-insert.

Example: drop table if exists dbo.campaigns_stg;

Rejected: workable for this small personal project, but not best practice as historic tracking is made difficult (impossible),
potential of errors introduced if this were a production environment with other users querying this table at the same moment it were dropped, etc.

Option 2: create flag that logs script run (insertion into table) and prevents future runs (future insertions into table).

Example: see code block

Accepted: whilst this totally forbids future insertions into staging, which is inflexible, this is acceptable for this context,
in which there will in fact be no future insertions.
Technically then, option 1 is also valid. However this seems at least closer to a production-level workaround, even if it is not so in actuality.
*/

-- 2a) Create log table for insertion of items from ingested into staging and insertion from staging into working:

-- Flag table must be created in separate script to prevent 'aready exists' error.
-- See Staging Insertion Flag.sql

-- 2b) Logic to lock staging and working from further insertions after the initial one.
-- Therefore, must rebuild this flag table each time in the other script, to force value = 0 and enable insertion

if not exists
(
select 1 from dbo.campaign_insertion_flag
where flag_name = 'Insertion into staging' and flag_value = 1
)

begin
	insert into dbo.campaigns_stg
		(age, job, marital, education, [default], balance, housing, loan, contact, day, month, duration, contacts_current, days_since_prev, contacts_total_prev, poutcome, success)
	select
		
		[age],
		[job],
		[marital],
		[education],
		case when [default] = 'yes' then 1 when [default] = 'no' then 0 else 99 end,
		[balance],
		case when [housing] = 'yes' then 1 when [housing] = 'no' then 0 else 99 end,
		case when [loan] = 'yes' then 1 when [loan] = 'no' then 0 else 99 end,
		[contact],
		[day],
		month(cast('01-' + [month] + '-2000' as date)),
		[duration],
		[campaign],
		[pdays],
		[previous],
		[poutcome],
		case when [y] = 'yes' then 1 when [y] = 'no' then 0 else 99 end
	from dbo.campaigns_ingest;

	select * into dbo.campaigns from dbo.campaigns_stg

	update dbo.campaign_insertion_flag
	set flag_value = 1
	where flag_name = 'Insertion into staging';
end

select count(*) count_rows from [dbo].[campaigns_stg]; -- fixed to 45,211
select count(*) count_rows from [dbo].[campaigns]; -- fixed to 45,211

go

-- 3) Protect staging table against edits

-- 3a) DDL trigger protection against schema edits

create trigger trg_protect_campaigns_stg_schema
on database
for DROP_TABLE, ALTER_TABLE--, TRUNCATE_TABLE -- not a recognised cmd
as
begin
    declare @event XML = eventdata();

    if (
        @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME') = 'campaigns_stg' AND
        @event.value('(/EVENT_INSTANCE/SchemaName)[1]', 'SYSNAME') = 'dbo'
    )
    begin
        raiserror ('Schema changes to dbo.campaigns_stg are not allowed.', 16, 1);
        rollback;
    end
end;
go

-- 3b) DML trigger protection against data edits

create trigger trg_protect_campaigns_stg_data
on dbo.campaigns_stg
after insert, update, delete
as
begin
	raiserror ('Modifying data in dbo.campaigns_stg is not allowed.', 16, 1);
    rollback;
end;