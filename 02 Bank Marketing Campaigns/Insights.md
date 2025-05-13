Business insights and recommendations emergent from analysis.

1) **Prioritise age bands 18 - 25 and 65+:** higher likelihood of successful campaign as compared to the age bands in between. However, do not abandon those other age bands, as they represent a larger overall population and therefore source of successful campaigns, in absolute amounts.

```SQL 
select
	age_band,
	count(*) band_size,
	sum(success) success,
	sum(success) / cast(count(*) as float) success_rate
from dbo.campaigns
group by age_band
order by 1
```

 age_band     | band_size | success | success_rate      
--------------|-----------|---------|-------------------
 [01] 18 - 25 | 1336      | 320     | 0.239520958083832 
 [02] 26 - 39 | 22026     | 2521    | 0.114455643330609 
 [03] 40 - 64 | 21038     | 2107    | 0.100152105713471 
 [04] 65+     | 810       | 341     | 0.420987654320988 


2) **Focus on outreach to fresh customers rather than repeated outreach to the same customers:** in general, the success rates of campaigns is quite low - probably expected. Past 15 instances of contact in total though, this gets even worse.

```SQL 
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
```
 num_contacts | group_size | successes | success_rate          
--------------|------------|-----------|-----------------------
 10           | 446        | 58        | 0.1300448430493273542 
 11           | 321        | 47        | 0.1464174454828660436 
 12           | 247        | 28        | 0.1133603238866396761 
 13           | 209        | 22        | 0.1052631578947368421 
 14           | 145        | 16        | 0.1103448275862068965 
 15           | 134        | 15        | 0.1119402985074626865 
 16           | 115        | 8         | 0.0695652173913043478 
 17           | 97         | 6         | 0.0618556701030927835 
 18           | 77         | 3         | 0.0389610389610389610 
 19           | 60         | 1         | 0.0166666666666666666 
 20           | 62         | 3         | 0.0483870967741935483 

 Likewise, within a single round of a marketing campaign, irrespective of total number of contacts to that customer up to that point, it is best to avoid making too many contacts. Exact hard-stop, if any, best deferred to further decision-making. Main point is the concept - don't chase a lead too long.

```SQL 
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
```
 contacts_total_prev_band | contacts_current_band | group_size | successes | success_rate   
--------------------------|-----------------------|------------|-----------|----------------
 [0] 0                    | [01] 1 - 2            | 23758      | 2419      | 0.101818334876 
 [0] 0                    | [02] 3 - 4            | 7705       | 643       | 0.083452303698 
 [0] 0                    | [03] 5 - 6            | 2636       | 174       | 0.066009104704 
 [0] 0                    | [04] 7 - 9            | 1427       | 88        | 0.061667834618 
 [0] 0                    | [05] 10+              | 1428       | 60        | 0.042016806722 
 [01] 1 - 3               | [01] 1 - 2            | 4803       | 1114      | 0.231938371850 
 [01] 1 - 3               | [02] 3 - 4            | 880        | 182       | 0.206818181818 
 [01] 1 - 3               | [03] 5 - 6            | 232        | 31        | 0.133620689655 
 [01] 1 - 3               | [04] 7 - 9            | 87         | 6         | 0.068965517241 
 [01] 1 - 3               | [05] 10+              | 18         | 0         | 0.000000000000 
 [02] 4 - 6               | [01] 1 - 2            | 1017       | 285       | 0.280235988200 
 [02] 4 - 6               | [02] 3 - 4            | 281        | 68        | 0.241992882562 
 [02] 4 - 6               | [03] 5 - 6            | 97         | 17        | 0.175257731958 
 [02] 4 - 6               | [04] 7 - 9            | 45         | 4         | 0.088888888888 
 [02] 4 - 6               | [05] 10+              | 10         | 1         | 0.100000000000 
 [03] 7 - 9               | [01] 1 - 2            | 269        | 88        | 0.327137546468 
 [03] 7 - 9               | [02] 3 - 4            | 96         | 24        | 0.250000000000 
 [03] 7 - 9               | [03] 5 - 6            | 38         | 5         | 0.131578947368 
 [03] 7 - 9               | [04] 7 - 9            | 23         | 0         | 0.000000000000 
 [04] 10+                 | [01] 1 - 2            | 201        | 56        | 0.278606965174 
 [04] 10+                 | [02] 3 - 4            | 81         | 18        | 0.222222222222 
 [04] 10+                 | [03] 5 - 6            | 52         | 4         | 0.076923076923 
 [04] 10+                 | [04] 7 - 9            | 20         | 2         | 0.100000000000 
 [04] 10+                 | [05] 10+              | 6          | 0         | 0.000000000000 


