# Source, data dictionary

https://archive.ics.uci.edu/dataset/222/bank+marketing
Uploaded as "bank-full.csv"

# Project files run-through

## 01 Raw SQL Data Ingestion

Following import of csv data into SSMS, triggers created as protections against edits.

## 02 Staging Insertion Flag

Building of a helper table to prevent additional insertions of data into the staging table in file 03.

## 03 Staging Table

Transformation of source data to enable analysis.

## 04 Analysis - Definitions

Preliminary analysis to confirm and validate aspects of the data dictionary which were not immediately clear.

## 05 Analysis Proper

Insights into ways of optimising market campaign approach(es).

### Business Insights / Recommendations

1) Prioritise age bands 18 - 25 and 65+:

> select
	age_band,
	count(*) band_size,
	sum(success) success,
	sum(success) / cast(count(*) as float) success_rate
from dbo.campaigns
group by age_band
order by 1
