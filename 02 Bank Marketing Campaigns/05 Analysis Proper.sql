use bank_marketing
go

select top 1000 * from dbo.campaigns;

-- As per below, there is/was an entry with anomalously high contacts_total_prev = 275. Hence deleted.

/*
-- Get a feel of distribution:
select distinct contacts_total_prev from dbo.campaigns order by 1;

-- There is an entry with abnormally high contacts_total_prev = 275
select * from dbo.campaigns where contacts_total_prev = 275;

/*
age	job			marital		education	default	balance	housing	loan	contact		day	month	duration	contacts_current	days_since_prev	contacts_total_prev	poutcome
40	management	married		tertiary	0		543		1		0		cellular	2	2		349			2					262				275					other
*/

-- Look for the previous entry for this customer:

select * from dbo.campaigns
where age between 39 and 40 and job = 'management' and marital = 'married' and education = 'tertiary' and "default" = 0 and housing = 1 and loan = 0
and day = 16 and month = 5;

-- Previous entry is non-existant. Whilst hard to be certain, seems too far out of range to be explainable, so delete
*/

-- delete from dbo.campaigns where contacts_total_prev = 275;

/*
1) Success rates across contact methods
*/

-- drop table if exists #contact_analysis1;

select contact, count(*) group_size, sum(success) successes
into #contact_analysis1
from dbo.campaigns
group by contact

-- drop table if exists #contact_analysis2;

select
	*,
	cast(successes as numeric) / cast(group_size as numeric) success_rate
into #contact_analysis2
from #contact_analysis1;

			select * from #contact_analysis2
			order by success_rate desc;


/*
Telephone and cellular have similar success rates.
Recommend improving data collection to classify 'unknowns', which amount to a large population that can't be analysed further.
Overall, unknown is non-productive, but there might be contact method(s) within it worth salvaging.
*/

/*
2) Success rates across customer ages
*/

-- Age range 18 to 95
select min(age), max(age) from dbo.campaigns;


-- Add age_band column to working table.
-- As this seems a useful column for future users or analysis, embed this change into the actual table itself (dbo.campaigns),
-- rather than exclusively on a temp table or in CTE.

/*
alter table dbo.campaigns
add age_band nvarchar(50);

update dbo.campaigns
set age_band =
	case
		when age between 18 and 25 then '[01] 18 - 25'
		when age between 26 and 39 then '[02] 26 - 39'
		when age between 40 and 64 then '[03] 40 - 64'
		when age >= 65 then '[04] 65+'
		else NULL
	end;

select top 100 age_band, age, * from dbo.campaigns;
*/

select
	age_band,
	count(*) band_size,
	sum(success) success,
	sum(success) / cast(count(*) as float) success_rate
from dbo.campaigns
group by age_band
order by 1

/*
age_band		band_size	success		success_rate
[01] 18 - 25	1336		320			0.239520958083832
[02] 26 - 39	22026		2521		0.114455643330609
[03] 40 - 64	21039		2107		0.10014734540615
[04] 65+		810			341			0.420987654320988
*/

-- Age analysis in custom bands. Not much new information revealed.

/*
select
	round(cast(age as float)/5,0)*5 Nearest5,
	count(*) group_size,
	sum(success) successes,
	sum(success) / cast(count(*) as float) success_rate
from dbo.campaigns
group by round(cast(age as float)/5,0)*5
order by 1
*/

/*
Best success rate 18 - 25 and 65+. Prioritise these.
However, as the other bands represent such a large population and in absolute terms amount to the most successes, don't discard them completely.
I.e. take relatively easier wins first.
*/

/*
(3) Within a campaign round (singular row in table), how many contacts (contacts_current) is ideal?
Suspect that this depends on historic number of contacts to customer up to that point (contacts_total_prev).
E.g. the first 'win' (contacts_total_prev = 0) probably takes multiple contacts, and perhaps very mature relationships require very few
(at this point, only enthusiastic customers remain, and those fed up will have blocked the campaigns).
*/

-- (3a) Simple analysis: number of contacts to date versus success

-- New column 'num_contacts' := total contacts up to point of decision (success or not)
-- - probably not worth inserting as permanent column in dbo.campaigns, a bit too task-specific (?)

select distinct (contacts_current + contacts_total_prev) num_contacts
from dbo.campaigns
order by 1;

-- drop table if exists #num_analysis1;

select
	(contacts_current + contacts_total_prev) num_contacts,
	count(*) group_size,
	sum(success) successes
into #num_analysis1
from dbo.campaigns
group by (contacts_current + contacts_total_prev)

-- drop table if exists #num_analysis2;

select
	*,
	cast(successes as numeric) / cast(group_size as numeric) success_rate
into #num_analysis2
from #num_analysis1;

			select * from #num_analysis2
			order by num_contacts asc;

/*
Diminishing returns on making >15 contacts. Not worth the resource. Prioritise outreach to new customers over pursuing this.
We are already doing a good job of avoiding >15 contacts, make sure to monitor against this creeping up.
*/

-- (3b) Simple analysis: per round, number of contacts_current versus success.
-- I.e. without discrimination for number of contacts made to the customer up to that point

select distinct contacts_current
from dbo.campaigns
order by 1;

-- drop table if exists #round_analysis1;

select
	contacts_current,
	count(*) group_size,
	sum(success) successes
into #round_analysis1
from dbo.campaigns
group by contacts_current

			select * from #num_analysis1

-- drop table if exists #round_analysis2;

select
	*,
	cast(successes as numeric) / cast(group_size as numeric) success_rate
into #round_analysis2
from #round_analysis1;

			select * from #round_analysis2
			order by contacts_current asc;

select
	round(cast(contacts_current as float)/5,0)*5 Nearest5,
	sum(group_size) group_size,
	sum(successes) successes,
	sum(successes) / cast(sum(group_size) as float) success_rate
from #round_analysis2
group by round(cast(contacts_current as float)/5,0)*5
order by 1

/*
There are diminishing returns on multiple contacts per campaign round.
Exact point at which to stop best decided by subject matter experts, but overall point is to warn against chasing the same lead too much - not worthwhile.
Also see next code block for more nuanced analysis.
*/

-- (3c) Detailed analysis: conditional on contacts_total_prev up to this point, the ideal number of contacts_current versus success

select distinct contacts_total_prev, contacts_current
from dbo.campaigns
order by 1, 2;

-- If ungrouped, there will be excessive rows to make meaningful conclusions easily.
-- Bands for contacts_total_prev:
	-- [0], [1, 3], [4, 6], [7, 9], [10, 15], [16, 20], [21, 30], [>30]
-- Bands for contacts_current:
	-- [0], [1, 3], [4, 6], [7, 9], [10, 12], [13, 15], [16, 20], [>20]

-- drop table if exists #level_analysis1;

with bands as
(
select
	case
		when contacts_total_prev = 0 then '[0] 0'
		when contacts_total_prev between 1 and 3 then '[01] 1 - 3'
		when contacts_total_prev between 4 and 6 then '[02] 4 - 6'
		when contacts_total_prev between 7 and 9 then '[03] 7 - 9'
		else '[04] 10+'
	end contacts_total_prev_band,
	case
		when contacts_current = 0 then '[0] 0'
		when contacts_current between 1 and 2 then '[01] 1 - 2'
		when contacts_current between 3 and 4 then '[02] 3 - 4'
		when contacts_current between 5 and 6 then '[03] 5 - 6'
		when contacts_current between 7 and 9 then '[04] 7 - 9'
		else '[05] 10+'
	end contacts_current_band,
	success
from dbo.campaigns
)
select
	contacts_total_prev_band, -- given this
	contacts_current_band, -- does this vary in successes / success rate generated?
	count(*) group_size,
	sum(success) successes
into #level_analysis1
from bands
group by contacts_total_prev_band, contacts_current_band

	select * from #level_analysis1
	order by 1, 2

select
	*, 
	1.0 * successes / group_size success_rate
from #level_analysis1
order by 1, 2

/*
Again, even conditional on contacts_total_prev, there is little point in adding to contacts_current.
The success rate generally falls.
*/