PART 1 -Create a Table
------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE [dbo].[IO_Stats](
	[capture_time] [datetime] NULL,
	[database_id] [int] NULL,
	[file_id] [int] NULL,
	[file_type] [varchar](10) NULL,
	[number_of_reads] [bigint] NULL,
	[bytes_read] [bigint] NULL,
	[number_of_writes] [bigint] NULL,
	[bytes_written] [bigint] NULL,
	[io_stall_read_ms] [bigint] NULL,
	[io_stall_write_ms] [bigint] NULL,
	[sample_ms] [bigint] NULL,
	[avg_read_latency_ms]  AS (case when [number_of_reads]>(0) then CONVERT([float],[io_stall_read_ms])/[number_of_reads] else (0) end),
	[avg_write_latency_ms]  AS (case when [number_of_writes]>(0) then CONVERT([float],[io_stall_write_ms])/[number_of_writes] else (0) end)
) ON [PRIMARY]
GO

PART 2 -Create a SQL server Agent Job
------------------------------------------------------------------------------------------------------------------------------------------------------

USE [msdb]
GO


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA-CaptureIO', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Capture-IO', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO dbo.IO_Stats 
    (capture_time, database_id, file_id, file_type, number_of_reads, bytes_read, number_of_writes, bytes_written, 
     io_stall_read_ms, io_stall_write_ms, sample_ms)
SELECT 
    GETDATE() AS capture_time,
    vfs.database_id,
    vfs.file_id,
    CASE 
        WHEN mf.type_desc = ''ROWS'' THEN ''DATA''
        WHEN mf.type_desc = ''LOG'' THEN ''LOG''
        ELSE ''OTHER'' 
    END AS file_type,
    vfs.num_of_reads,
    vfs.num_of_bytes_read,
    vfs.num_of_writes,
    vfs.num_of_bytes_written,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    vfs.sample_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf 
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;
', 
		@database_name=N'DBATools', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every30seconds', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240418, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'743c63a3-8811-4d38-9805-00495b077760'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


PART 3 -Read the DELTA information for any Database that concerns
------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    capture_time,
    database_name,
    file_id,
    file_type,
    NumberofReadDelta,
    WriteDelta AS NumberofWriteDelta,
    io_stall_read_ms_delta,
    io_stall_write_ms_delta,
    -- Calculating change in read latency
    (io_stall_read_ms_delta / NULLIF(NumberofReadDelta, 0)) AS Read_Latency_Delta,
    -- Calculating change in write latency
    (io_stall_write_ms_delta / NULLIF(WriteDelta, 0)) AS Write_Latency_Delta
FROM (
    SELECT
        capture_time,
        DB_NAME(database_id) AS database_name,
        file_id,
        file_type,
        number_of_reads - LAG(number_of_reads, 1, number_of_reads) OVER (PARTITION BY file_id ORDER BY capture_time) AS NumberofReadDelta,
        number_of_writes - LAG(number_of_writes, 1, number_of_writes) OVER (PARTITION BY file_id ORDER BY capture_time) AS WriteDelta,
        io_stall_read_ms - LAG(io_stall_read_ms, 1, io_stall_read_ms) OVER (PARTITION BY file_id ORDER BY capture_time) AS io_stall_read_ms_delta,
        io_stall_write_ms - LAG(io_stall_write_ms, 1, io_stall_write_ms) OVER (PARTITION BY file_id ORDER BY capture_time) AS io_stall_write_ms_delta
    FROM [DBATools].[dbo].[IO_Stats]
    WHERE DB_NAME(database_id) = ''  -- Your Database Name here
) AS DerivedTable
ORDER BY file_id, capture_time;


