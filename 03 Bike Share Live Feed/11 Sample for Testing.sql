use bikeshare
go

select * from dbo.station_status
where station_id in
(
'000_test',
'0099b016-32c9-4536-ac4c-dcc1a117bd95',
'0136af02-2670-4042-b5cd-18b46c15c0c1',
'0248fa3b-6df4-4fdc-ae31-ee2e4d177da8',
'0541e06c-642c-4f31-9f24-19bfcbb8811d',
'0627dc3c-5c62-4ab1-a6f0-3635c6f80d23',
'065defed-8e90-46b9-a106-28d590704cf8',
'066fd95e-0d37-4eea-a027-88c04277bb9d',
'068e6359-1741-4240-9ed1-07a9038bc319',
'06a14329-dedb-4152-b237-e59afccd8d42',
'071dcbf5-3f1e-45e0-a4a5-8717adb8743f',
'07a453e5-2e14-4276-85df-49e0d6144e54'
)
order by station_id, retrieved_at

select * from dbo.station_status_by_day
where station_id in
(
'000_test',
'0099b016-32c9-4536-ac4c-dcc1a117bd95',
'0136af02-2670-4042-b5cd-18b46c15c0c1',
'0248fa3b-6df4-4fdc-ae31-ee2e4d177da8',
'0541e06c-642c-4f31-9f24-19bfcbb8811d',
'0627dc3c-5c62-4ab1-a6f0-3635c6f80d23',
'065defed-8e90-46b9-a106-28d590704cf8',
'066fd95e-0d37-4eea-a027-88c04277bb9d',
'068e6359-1741-4240-9ed1-07a9038bc319',
'06a14329-dedb-4152-b237-e59afccd8d42',
'071dcbf5-3f1e-45e0-a4a5-8717adb8743f',
'07a453e5-2e14-4276-85df-49e0d6144e54'
)
order by station_id, retrieved_at