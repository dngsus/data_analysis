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

7) Edit month column to be as a number rather than abbreviation

Justification: simpler filtering, cleaner look, easier to sequence
*/

use bank_marketing
go

-- 1) Create staging table 

/*
Option 1: do not explicitly create staging table first, but simply select * into staging from ingested,
then apply edits to add identity column and change column names.
Possibly wrap these edits in transaction statements to enable rollback / explicit commits

Rejected:
- Loss of control or at least awareness over datatypes and nullability

Option 2: create table anew 

Accepted.

*/

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
	[default] [nvarchar](50) NOT NULL,
	[balance] [int] NOT NULL,
	[housing] [nvarchar](50) NOT NULL,
	[loan] [nvarchar](50) NOT NULL,
	[contact] [nvarchar](50) NOT NULL,
	[day] [tinyint] NOT NULL,
	[month] [nvarchar](50) NOT NULL,
	[duration] [smallint] NOT NULL,
	[contacts_current] [tinyint] NOT NULL,
	[days_since_prev] [smallint] NOT NULL,
	[contacts_total_prev] [smallint] NOT NULL,
	[poutcome] [nvarchar](50) NOT NULL,
	[success] [nvarchar](50) NOT NULL
) ON [PRIMARY]
GO

-- 2) Insert into staging from ingested

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

-- 2a) Create log table for insertion of items from ingested into staging:

-- Table must be created in separate script to prevent 'aready exists' error.
-- Below in comments for reference:

/*
create table dbo.campaign_insertion_flag
(
flag_name VARCHAR(100) PRIMARY KEY,
flag_value BIT
);

insert into dbo.campaign_insertion_flag (flag_name, flag_value)
values ('Insertion into staging', 0);
*/

-- 2b) Logic to lock staging from further insertions after the initial one:

if not exists
(
select 1 from dbo.campaign_insertion_flag
where flag_name = 'Insertion into staging' and flag_value = 1
)

begin
	insert into dbo.campaigns_stg
	select * from dbo.campaigns_ingest;

	update dbo.campaign_insertion_flag
	set flag_value = 1
	where flag_name = 'Insertion into staging';
end

select count(*) count_rows from [dbo].[campaigns_stg]; -- fixed to 45,211

-- 3) Edit columns to be binary 1/0 instead of y/n:

/*
Option 1: could have simply embedded this logic into the insertion

Rejected: overly-verbose code block for insertion, less explicit clarity over each column change

Option 2: edit columns after insertion

Accepted: opportunity to practice transaction statements...
*/


-- i) transaction

begin transaction;

update dbo.campaigns_stg
set "default" = case when "default" = 'yes' then 1 when "default" = 'no' then 0 else 99 end;

update dbo.campaigns_stg
set housing = case when housing = 'yes' then 1 when housing = 'no' then 0 else 99 end;

update dbo.campaigns_stg
set loan = case when loan = 'yes' then 1 when loan = 'no' then 0 else 99 end;

update dbo.campaigns_stg
set success = case when success = 'yes' then 1 when success = 'no' then 0 else 99 end;

-- ii) validate

select distinct "default" from dbo.campaigns_stg;
select distinct housing from dbo.campaigns_stg;
select distinct loan from dbo.campaigns_stg;
select distinct success from dbo.campaigns_stg;


-- iii) confirm

-- commit;

-- 4) Edit month to be as number not abbreviation

/*
Manually convert each month to valid datetime format 'dd-month-yyyy' and extract month datepart
*/

begin transaction;

update dbo.campaigns_stg
set "month" = month(cast('01-' + "month" + '-2000' as date)) from dbo.campaigns_stg;

select distinct month from dbo.campaigns_stg;

-- commit;