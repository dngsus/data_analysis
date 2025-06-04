use bikeshare 
go

with one as(
select availability_group, sum(duration_seconds) duration_seconds
from dbo.station_status_by_day where datepart(month, report_date) = 05
group by availability_group
),
two as (select one.*, (select sum(duration_seconds) from one) summation from one)
, three as
(select two.*, 100 * (1.0 * duration_seconds / summation) percentage from two)
select *  from three