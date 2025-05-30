@echo off
d:
cd "D:\Code\Data Analysis\03 Bike Share\
echo %date% %time%: Starting script >> run_log.txt

python "01 API Request Status, Info, Region.py" >> run_log.txt 2>&1
echo %date% %time%: Python script finished >> run_log.txt

sqlcmd -S DANIEL\SQLEXPRESS -d bikeshare -E -Q "EXEC dbo.sp_bikeshare_analysis" >> run_log.txt 2>&1
echo %date% %time%: SQL procedure finished >> run_log.txt
