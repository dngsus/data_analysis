use bank_marketing
go

--drop table if exists dbo.campaign_insertion_flag

create table dbo.campaign_insertion_flag
(
flag_name VARCHAR(100) PRIMARY KEY,
flag_value BIT
);

insert into dbo.campaign_insertion_flag (flag_name, flag_value)
values ('Insertion into staging', 0);