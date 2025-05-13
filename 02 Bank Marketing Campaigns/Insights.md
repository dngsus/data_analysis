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

age_band	band_size	success	success_rate
[01] 18 - 25	1336	320	0.239520958083832
[02] 26 - 39	22026	2521	0.114455643330609
[03] 40 - 64	21038	2107	0.100152105713471
[04] 65+	810	341	0.420987654320988

2) **
