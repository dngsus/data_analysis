/*
Begin Analysis - Definitions

Queries to validate and confirm understanding of columns as per data dictionary (https://archive.ics.uci.edu/dataset/222/bank+marketing),
justifying interpretations in the case of uncertainty.
*/

use bank_marketing
go

select top 1000 * from dbo.campaigns_stg;

-- Duration = 0 --> necessarily outcome was 'no' := fail
select distinct duration, success from dbo.campaigns_stg where duration = 0;

/*
First contact for a customer --> days_since_prev = - 1
Therefore previous outcome ("success") necessarily 'unknown',
and contacts_total_prev necessarily = 0
*/

select count(*) from dbo.campaigns_stg where days_since_prev = -1 and poutcome <> 'unknown';
select count(*) from dbo.campaigns_stg where days_since_prev = -1 and contacts_total_prev <> 0;

/*
Regarding creation of id column in staging to identify each 'round' per 'campaign':

Assuming the customers highlighted below are truly the same distinct person (*),
we can confirm that col 'contacts_current', aka 'campaign' in source, is indeed the number of contacts to the customer made during the present (round of the) 'campaign',
and 'contacts_total_prev', aka 'previous' in source, i.e. previous number of contacts to that customer in total in history,
responds accordingly (contacts_total_prev = [contacts_total_prev of previous entry] + contacts_current)

(*) Technically it is possible that these are in fact different persons, so the above logic wouldn't be confirmed.
This would arise from multiple persons having identical attributes, and certain missing entries for one or all cuasing respective contacts_total_prev, days_since_prev
aligning perfectly. Highly unlikely...

Overall then, the id column identifies the particular 'campaign', within which the customer in question might be contacted multiple times,
and this customer may be represented in multiple rows, having been the target of multiple campaigns.
*/

select * from dbo.campaigns_stg
where age between 70 and 76 and job = 'retired' and marital = 'married' and education = 'secondary' and [default] = 0 and loan = 0 and housing = 0 and contact = 'cellular' --and balance = 608 and age = 19
order by case when balance in (2850, 935) then 0 else 1 end, balance, contacts_total_prev

select * from dbo.campaigns_stg
where age between 16 and 22 and job = 'student' and marital = 'single' and education = 'primary' and [default] = 0 and loan = 0 and housing = 0 --and contact = 'cellular' --and balance = 608 and age = 19
order by case when balance in (103, 608) then 0 else 1 end, balance, contacts_total_prev

/*
Investigate rows with poutcome = 'other'.
*/

-- 1840 rows:
select count(*), poutcome from dbo.campaigns_stg group by poutcome;

-- 0 / 1840 rows are associated with first-ever contact (days_since_prev = -1)
select min(days_since_prev) from dbo.campaigns_stg where poutcome = 'other'

-- Since the only possible results for success are 1 or 0, which are obviously associated with 'success' or 'failure', there is nothing to be said about how 'other' arises as a poutcome.
-- Ideally we would backtrace at least one example of a previous outcome being '0' and another being '1',
-- therefore proving it impossible to conclude anything definitively about the previous outcome if poutcome = 'other'.
select distinct success from dbo.campaigns_stg

-- There is the possibility that poutcome = 'other' necessarily means previous outcome was 1 or was 0, but this can't easily be proved due to lack of customer_id column,
-- which could be used in a lead/lag func. Plus, wouldn't be logically fool-proof anyway.

-- In any case, can see in the example below that the previous entry for this customer doesn't even exist, so that precludes the above (all 1 or all 0)

-- In the absence of a customer_id or such to track the history of a given customer, need to reverse engineer.
-- I.e. look for customers with 'unknown' and trace their previous reading

select * from dbo.campaigns_stg where poutcome = 'other'
order by days_since_prev asc,  contacts_total_prev

-- Example 1: campaign_round_id = 33570
-- select * from dbo.campaigns_stg where campaign_round_id = 33570
-- Notice contact was made 04-Aug, and days_since_prev = 1. Therefore, previous contact 03-Aug

-- Look for previous reading.
-- Do not filter on balance, contact (method), in case these are treated as slowly-changing dimensions per customer (unclear)
-- It is known that age does update, so allow for possibility that birthday has passed

select * from dbo.campaigns_stg
where age between 41 and 42-- and job = 'admin.' and marital = 'married' and education = 'secondary'-- and [default] = 0 and loan = 0 and housing = 0
and day = 3 and month = 8 -- and campaign_round_id < 33570
order by balance, contacts_total_prev

-- There is no previous contact on record for this customer prior to campaign_round_id = 33570

-- At this point we can already conclude that salvaging the 'other' entries is impossible. E.g. we cannot replace all 'other' with 'success' or 'failure',
-- since there is at least one entry (the one above) for which the previous outcome was unknown.