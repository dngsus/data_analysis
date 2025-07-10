# Sources

Definitions and background:
https://www.sciencedirect.com/science/article/pii/S2352340918315191#s0005

Data 2018 - 2020:
https://absentdata.com/data-analysis/where-to-find-data/
Uploaded as "hotel_revenue_historical-full-2.csv"

Data 2015 - 2017:
https://github.com/rfordatascience/tidytuesday/blob/main/data/2020/2020-02-11/readme.md

# Brief

EDA to clean and process data to derive insights into cancellation rates, propose actions:
1) Cancellation volume and rate are rising 'recently' 2018 - 2020.
2) (1) is driven mostly by bookings from 'Online TA' segment and bookings with longer lead times.
3) (2) is an outcome of Online TA being the largest booking segment/channel, and long lead times being the most popular type of lead time. Plus, these two groupings having relatively high inherent cancellation rates.
4) Furthermore, these qualities and therefore their impact on cancellations is rising. I.e. the volume of bookings originating from Online TA and long lead time bookings is rising, as is their cancellation rate.
5) We observe too that the average lead time of bookings from Online TA is itself increasing, so these are not isolated booking patterns: bookings are 'worsening' on two joint fronts.
6) Overall, offering online channels and long lead-times is still beneficial, as they are popular means of making bookings, and ultimately >50% of bookings from these sources are fulfiled, so it is worthwhile to stick to them. Vice versa it would be backward-thinking to get rid of them. Instead, focus should be on mitigation/management, e.g. discouraging cancellations through locking-in of favourable prices, perhaps more aggressiveness with pushing deposits, sending timely reminders to keep prospective bookings in mind (encourage customers to actually realise their plans made on a whim), etc.

# Detail

## Cancellation Trends Over Time

Rising Cancellations per Month and Cancellation Rate per Year 2018 - 2020:

![Cancellations Over Time](01_cancellations_over_time.png)

YYD Cancellations in 2020 Exceed Those of 2019:

![YTD Cancellations 2020 vs 2019](02_YTD_cancellations_2020_vs_2019.png)

Whilst there are weak signs of certain seasonal effects influencing cancellation rates,<br>
overall we can diagnose a year-on-year issue with cancellation rates:

![03 Seasonal Level](03_seasonal_level.png)

## Drivers

### Bookings with Lengthy Lead Times

... to be completed




