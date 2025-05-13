/*
use bank_marketing
go
drop trigger trg_protect_campaigns_schema on database;

use bank_marketing
go
drop trigger trg_protect_campaigns_data
*/

use bank_marketing
go

/*
-- 1) csv import of raw data into dbo.campaigns
-- Take a look:
select * from dbo.campaigns_iungest;
select count(*) from dbo.campaigns_ingest;
*/

-- 2) Protect source table against edits

-- 2a) DDL trigger protection against schema edits

create trigger trg_protect_campaigns_ingest_schema
on database
for DROP_TABLE, ALTER_TABLE--, TRUNCATE_TABLE -- not a recognised cmd
as
begin
    declare @event XML = eventdata();

    if (
        @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME') = 'campaigns_ingest' AND
        @event.value('(/EVENT_INSTANCE/SchemaName)[1]', 'SYSNAME') = 'dbo'
    )
    begin
        raiserror ('Schema changes to dbo.campaigns_ingest are not allowed.', 16, 1);
        rollback;
    end
end;
go

-- 2b) DML trigger protection against data edits


create trigger trg_protect_campaigns_ingest_data
on dbo.campaigns_ingest
after insert, update, delete
as
begin
	raiserror ('Modifying data in dbo.campaigns_ingest is not allowed.', 16, 1);
    rollback;
end;