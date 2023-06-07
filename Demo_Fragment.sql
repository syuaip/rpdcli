-----Sample code for exploring RPDCLI / Performance Counters / Performance Insight
--This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
--This posting is provided "AS IS" with no warranties, and confers no rights. 


--- #1 Create DB for demo and use the DB 
CREATE DATABASE [DemoFragment]
GO

USE [DemoFragment]
GO

---------------------------
--- #2 Create Demo Tables  
----- create a sample table
CREATE TABLE [dbo].[tbl_SAMPLE](
       [USERID] [nchar](10) NULL,
       [TIMEINSERTED] [datetime] NOT NULL,
       [TOKENS] [numeric](18, 0) NULL
) ON [PRIMARY]

GO

----- create another sample table
CREATE TABLE [dbo].[tbl_SAMPLE2](
       [USERID] [nchar](10) NULL,
       [TIMEINSERTED] [datetime] NOT NULL,
       [TOKENS] [numeric](18, 0) NULL,
	   [FILLER1] [nchar](255) NULL,
	   [FILLER2] [nchar](255) NULL,
	   [FILLER3] [nchar](255) NULL,
	   [FILLER4] [nchar](255) NULL,
	   [FILLER5] [nchar](255) NULL,
	   [FILLER6] [nchar](255) NULL,
	   [FILLER7] [nchar](255) NULL,
	   [FILLER8] [nchar](255) NULL,
	   [FILLER9] [nchar](255) NULL,
	   [FILLER10] [nchar](255) NULL,
	   [FILLER11] [nchar](255) NULL,
	   [FILLER12] [nchar](255) NULL,
	   [FILLER13] [nchar](255) NULL,
	   [FILLER14] [nchar](255) NULL
) ON [PRIMARY]

GO


----------------------------
--- #2 Add Tables Constraints
----- with below constraints for table 1
ALTER TABLE [dbo].[tbl_SAMPLE] ADD  CONSTRAINT [DF_Table_1_INSERTED]  DEFAULT (getdate()) FOR [TIMEINSERTED]
GO

ALTER TABLE [dbo].[tbl_SAMPLE] ADD  CONSTRAINT [DF_tbl_SAMPLE_TOKENS]  DEFAULT ((99999)*rand()) FOR [TOKENS]
GO

----- and with below constraints for table 2
ALTER TABLE [dbo].[tbl_SAMPLE2] ADD  CONSTRAINT [DF_Table_2_INSERTED]  DEFAULT (getdate()) FOR [TIMEINSERTED]
GO

ALTER TABLE [dbo].[tbl_SAMPLE2] ADD  CONSTRAINT [DF_tbl_SAMPLE2_TOKENS]  DEFAULT ((99999)*rand()) FOR [TOKENS]
GO


---------------------------
--- #2 Insert Sample Data. This usually going to take a while. 
----- insert sample data
SET NOCOUNT ON
GO
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Rhoma')
GO 100000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Gaby')
GO 10000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Albert')
GO 5000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Dina')
GO 1000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Randy')
GO 2500
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Dody')
GO 1500
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Farhat')
GO 5000


----- insert sample data onto Table 2 also. This could take some time to finish
SET NOCOUNT ON
GO
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Rhoma')
GO 100000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Gaby')
GO 10000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Albert')
GO 5000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Dina')
GO 1000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Randy')
GO 2500
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Dody')
GO 1500
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Farhat')
GO 5000


-------------------------------------------------------
--- #3 Create a Stored Procedure for randomized load intro 
CREATE PROCEDURE TypicalLoadSample 
AS
BEGIN
SET NOCOUNT ON;
-- Insert statements for procedure here
DECLARE @Load AS INT;
SET @Load = FLOOR(RAND()*100);
--PRINT @Load
IF @Load >= 95 AND @Load < 100 SELECT * FROM [dbo].[tbl_SAMPLE];
IF @Load >= 90 AND @Load < 95  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS = @Load * 100;
IF @Load >= 80 AND @Load < 90  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 10000 and TOKENS < 15500;
IF @Load >= 70 AND @Load < 80  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 20000 and TOKENS < 25500;
IF @Load >= 60 AND @Load < 70  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 30000 and TOKENS < 35500;
IF @Load >= 55 AND @Load < 60  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 40000 and TOKENS < 45500;
IF @Load >= 50 AND @Load < 55  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 50000 and TOKENS < 55500;
IF @Load >= 45 AND @Load < 50  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 60000 and TOKENS < 65500;
IF @Load >= 40 AND @Load < 45  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 70000 and TOKENS < 75500;
IF @Load >= 30 AND @Load < 40  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 80000 and TOKENS < 85500;
IF @Load >= 20 AND @Load < 30  SELECT * FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 90000 and TOKENS < 95500;
IF @Load >= 15 AND @Load < 20  INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('TypLoad');
IF @Load >= 10 AND @Load < 15  DELETE FROM [dbo].[tbl_SAMPLE] WHERE TOKENS = @Load * @Load;
IF @Load <10 SELECT USERID FROM [dbo].[tbl_SAMPLE] WHERE TOKENS = @Load * @Load;
END

--- Stored Procedure for randomized load intro for Table 2
CREATE PROCEDURE TypicalLoadSample2 
AS
BEGIN
SET NOCOUNT ON;
-- Insert statements for procedure here
DECLARE @Load AS INT;
SET @Load = FLOOR(RAND()*100);
--PRINT @Load
IF @Load >= 95 AND @Load < 100 SELECT * FROM [dbo].[tbl_SAMPLE2];
IF @Load >= 90 AND @Load < 95  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS = @Load * 100;
IF @Load >= 80 AND @Load < 90  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 10000 and TOKENS < 15500;
IF @Load >= 70 AND @Load < 80  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 20000 and TOKENS < 25500;
IF @Load >= 60 AND @Load < 70  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 30000 and TOKENS < 35500;
IF @Load >= 55 AND @Load < 60  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 40000 and TOKENS < 45500;
IF @Load >= 50 AND @Load < 55  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 50000 and TOKENS < 55500;
IF @Load >= 45 AND @Load < 50  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 60000 and TOKENS < 65500;
IF @Load >= 40 AND @Load < 45  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 70000 and TOKENS < 75500;
IF @Load >= 30 AND @Load < 40  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 80000 and TOKENS < 85500;
IF @Load >= 20 AND @Load < 30  SELECT * FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 90000 and TOKENS < 95500;
IF @Load >= 15 AND @Load < 20  INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('TypLoad');
IF @Load >= 10 AND @Load < 15  DELETE FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS = @Load * @Load;
IF @Load <10 SELECT USERID FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS = @Load * @Load;
END



-------------------------------------------------------
--- #4 Get baseline query performance data
---- Demo SELECT using specific values. Note the number of page reads. It should be big (close to the number of pages above)
SET STATISTICS IO ON
SET STATISTICS XML ON
SET STATISTICS TIME ON
SELECT [USERID]
      ,[TIMEINSERTED]
      ,[TOKENS]
  FROM [dbo].[tbl_SAMPLE]
  WHERE TOKENS > 60000 and TOKENS < 60500
  ORDER BY TOKENS
GO
SET STATISTICS IO OFF
SET STATISTICS XML OFF
SET STATISTICS TIME OFF

---- Demo SELECT using specific values. Note the number of page reads. It should be big (close to the number of pages above)
SET STATISTICS IO ON
SET STATISTICS XML ON
SET STATISTICS TIME ON
SELECT [USERID]
      ,[TIMEINSERTED]
      ,[TOKENS]
  FROM [dbo].[tbl_SAMPLE2]
  WHERE TOKENS > 60000 and TOKENS < 60500
  ORDER BY TOKENS
GO
SET STATISTICS IO OFF
SET STATISTICS XML OFF
SET STATISTICS TIME OFF



-------------------------------------------------------
--- #5 Improve performance by creating indexes
----- Create indexes to improve query performance
CREATE CLUSTERED INDEX [idx_TIMEINSERTED] ON [dbo].[tbl_SAMPLE] 
(
       [TIMEINSERTED] ASC,
       [TOKENS] ASC,
       [USERID] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_TOKENS] ON [dbo].[tbl_SAMPLE] 
(
       [TOKENS] ASC,
       [TIMEINSERTED] ASC,
       [USERID] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_NAME] ON [dbo].[tbl_SAMPLE] 
(
       [USERID] ASC,
       [TOKENS] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO



-------------------------------------------------------
--- verify space being used by table and indexes. note the row numbers, data and index size
sp_spaceused tbl_Sample
sp_spaceused tbl_Sample2



-------------------------------------------------------
----- Create indexes to improve query performance on Table 2
CREATE CLUSTERED INDEX [idx_TIMEINSERTED] ON [dbo].[tbl_SAMPLE2] 
(
       [TIMEINSERTED] ASC,
       [TOKENS] ASC,
       [USERID] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_TOKENS] ON [dbo].[tbl_SAMPLE2] 
(
       [TOKENS] ASC,
       [TIMEINSERTED] ASC,
       [USERID] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_NAME] ON [dbo].[tbl_SAMPLE2] 
(
       [USERID] ASC,
       [TOKENS] ASC
)WITH (STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO



-------------------------------------------------------
--- #6 Verify of having no fragmentation yet
--- SHOW FRAGMENTATION. Should be very minimum. Note the number of pages
DBCC SHOWCONTIG ('tbl_Sample') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 
DBCC SHOWCONTIG ('tbl_Sample2') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 


-------------------------------------------------------
--- #7 Verify no fragmentation yet
---- Demo SELECT using same query as above. Note the number of page reads. It has less page reads / faster due to created indexes
---- note the time for processing
SET STATISTICS IO ON
SET STATISTICS XML ON
SET STATISTICS TIME ON
SELECT [USERID]
      ,[TIMEINSERTED]
      ,[TOKENS]
  FROM [dbo].[tbl_SAMPLE]
  WHERE TOKENS > 60000 and TOKENS < 60500
  ORDER BY TOKENS
GO
SET STATISTICS IO OFF
SET STATISTICS XML OFF
SET STATISTICS TIME OFF

---- #8 Get improved query performance data
---- Demo SELECT using same query as above. Note the number of page reads. It has less page reads / faster due to created indexes
---- note the time for processing
SET STATISTICS IO ON
SET STATISTICS XML ON
SET STATISTICS TIME ON
SELECT [USERID]
      ,[TIMEINSERTED]
      ,[TOKENS]
  FROM [dbo].[tbl_SAMPLE2]
  WHERE TOKENS > 60000 and TOKENS < 60500
  ORDER BY TOKENS
GO
SET STATISTICS IO OFF
SET STATISTICS XML OFF
SET STATISTICS TIME OFF


---- #9 Storage compression
-------------------------------------------------------
--- Review potential disk space saving by compression

EXEC sp_estimate_data_compression_savings 'DemoFragment', 'tbl_SAMPLE', NULL, NULL, 'ROW' ;  
GO
EXEC sp_estimate_data_compression_savings 'DemoFragment', 'tbl_SAMPLE', NULL, NULL, 'PAGE' ;  
GO
EXEC sp_estimate_data_compression_savings 'DemoFragment', 'tbl_SAMPLE2', NULL, NULL, 'ROW' ;  
GO
EXEC sp_estimate_data_compression_savings 'DemoFragment', 'tbl_SAMPLE2', NULL, NULL, 'PAGE' ;  
GO

-------------------------------------------------------
---- #10 Enable compression
	---- Compress table
		USE [DemoFragment]
		ALTER TABLE [dbo].[tbl_SAMPLE] REBUILD PARTITION = ALL
			WITH 
				(DATA_COMPRESSION = PAGE
			)

		--- verify space being used by table and indexes. note the row numbers, data and index size. they are smaller.
		sp_spaceused tbl_Sample

		---- Compress table
		USE [DemoFragment]
			ALTER TABLE [dbo].[tbl_SAMPLE2] REBUILD PARTITION = ALL
			WITH 
				(DATA_COMPRESSION = PAGE
			)

		--- verify space being used by table and indexes. note the row numbers, data and index size. they are smaller.
		sp_spaceused tbl_Sample2


-------------------------------------------------------
							---- Demo SELECT using same query as above. Same number of page reads but less physical page reads / possibly faster due to compression (need verification)
							---- note the time for processing
							SET STATISTICS IO ON
							SET STATISTICS XML ON
							SET STATISTICS TIME ON
							SELECT [USERID]
								  ,[TIMEINSERTED]
								  ,[TOKENS]
							  FROM [dbo].[tbl_SAMPLE2]
							  WHERE TOKENS > 60000 and TOKENS < 60500
							  ORDER BY TOKENS
							GO
							SET STATISTICS IO OFF
							SET STATISTICS XML OFF
							SET STATISTICS TIME OFF


							---- Demo SELECT using same query as above. Same number of page reads but less physical page reads / possibly faster due to compression (need verification)
							---- note the time for processing
							SET STATISTICS IO ON
							SET STATISTICS XML ON
							SET STATISTICS TIME ON
							SELECT [USERID]
								  ,[TIMEINSERTED]
								  ,[TOKENS]
							  FROM [dbo].[tbl_SAMPLE]
							  WHERE TOKENS > 60000 and TOKENS < 60500
							  ORDER BY TOKENS
							GO
							SET STATISTICS IO OFF
							SET STATISTICS XML OFF
							SET STATISTICS TIME OFF


-------------------------------------------------------
---- #11 Remove and insert some data to introduce fragmentation (table 1)
DELETE FROM [dbo].[tbl_SAMPLE] WHERE TOKENS > 20000 AND TOKENS < 55000
GO
SET NOCOUNT ON
GO
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Siti')
GO 5000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Didi')
GO 1000
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Ruly')
GO 500
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Dina')
GO 250
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Edo')
GO 200
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Yani')
GO 150
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Badu')
GO 100
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Budi')
GO 50
INSERT INTO [dbo].[tbl_SAMPLE] (USERID) VALUES ('Randy')
GO 10

--- #12 
-- SHOW FRAGMENTATION.. Should be high
DBCC SHOWCONTIG ('tbl_Sample') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 


--- #13 
---- Remove and insert some data to introduce fragmentation (table 2)
DELETE FROM [dbo].[tbl_SAMPLE2] WHERE TOKENS > 20000 AND TOKENS < 55000
GO
SET NOCOUNT ON
GO
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Siti')
GO 5000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Didi')
GO 1000
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Ruly')
GO 500
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Dina')
GO 250
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Edo')
GO 200
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Yani')
GO 150
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Badu')
GO 100
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Budi')
GO 50
INSERT INTO [dbo].[tbl_SAMPLE2] (USERID) VALUES ('Randy')
GO 10
  
--- #14 
-- SHOW FRAGMENTATION.. Should be high
DBCC SHOWCONTIG ('tbl_Sample2') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 


-------------------------------------------------------
--- #15 SHRINK Database. This will fragment the data even more.
							DBCC SHRINKFILE (DemoFragment, 1);
							GO

							-- SHOW FRAGMENTATION.. Most likely be even higher
							DBCC SHOWCONTIG ('tbl_Sample') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
							GO 
							-- SHOW FRAGMENTATION.. Most likely be even higher
							DBCC SHOWCONTIG ('tbl_Sample2') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
							GO 




-------------------------------------------------------
--- #16 Defrag TABLE to fix the fragmentation issue
ALTER INDEX idx_TOKENS ON tbl_SAMPLE REBUILD ---WITH ( ONLINE = ON ) ---Online only on Enterprise Edition
ALTER INDEX idx_NAME ON tbl_SAMPLE REBUILD ---WITH ( ONLINE = ON )
ALTER INDEX idx_TIMEINSERTED ON tbl_SAMPLE REBUILD ---WITH ( ONLINE = ON )

ALTER INDEX idx_TOKENS ON tbl_SAMPLE2 REBUILD ---WITH ( ONLINE = ON )
ALTER INDEX idx_NAME ON tbl_SAMPLE2 REBUILD ---WITH ( ONLINE = ON )
ALTER INDEX idx_TIMEINSERTED ON tbl_SAMPLE2 REBUILD ---WITH ( ONLINE = ON )



-------------------------------------------------------
--- #17 
-- SHOW FRAGMENTATION AGAIN.. Should be much lower after index rebuild
DBCC SHOWCONTIG ('tbl_Sample') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 
-- SHOW FRAGMENTATION AGAIN.. Should be much lower after index rebuild
DBCC SHOWCONTIG ('tbl_Sample2') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS
GO 

-------------------------------------------------------
							--- #18 Explore statistics
							-- Get statistics metadata from the table --- notice of one auto_created stats exist
							SELECT * from sys.stats where object_id IN (select object_id from sys.stats where name = N'idx_TIMEINSERTED')
							GO
							-- Get last updated date of Statistics using a new function on SQL 2012 SP1
							SELECT * from sys.dm_db_stats_properties (OBJECT_ID(N'tbl_Sample'),2)
							GO
							SELECT * from sys.dm_db_stats_properties (OBJECT_ID(N'tbl_Sample2'),2)
							GO
							-- Get last updated date of Statistics -- notice that the auto created stats does not get updated by alter index
							sp_autostats N'tbl_SAMPLE'
							GO
							sp_autostats N'tbl_SAMPLE2'
							GO



-------------------------------------------------------
										-- #19 Update statistics 
										UPDATE STATISTICS tbl_Sample
											WITH FULLSCAN, NORECOMPUTE;
										GO
										-- Check the auto created stats now
										sp_autostats N'tbl_SAMPLE'
										GO

										-- Update statistics 
										UPDATE STATISTICS tbl_Sample2
											WITH FULLSCAN, NORECOMPUTE;
										GO
										-- Check the auto created stats now
										sp_autostats N'tbl_SAMPLE2'
										GO

							SELECT STATS_DATE (Object_ID(N'tbl_SAMPLE'), 1) As LastStatUpdateDate
							GO

							SELECT STATS_DATE (Object_ID(N'tbl_SAMPLE2'), 1) As LastStatUpdateDate
							GO


							-- #20 Get statistical details from the table within the index
							DBCC SHOW_STATISTICS (tbl_SAMPLE, idx_NAME)
							GO
							DBCC SHOW_STATISTICS (tbl_SAMPLE, idx_TIMEINSERTED)
							GO
							DBCC SHOW_STATISTICS (tbl_SAMPLE, idx_TOKENS)
							GO


							-- Get statistical details from the table within the index
							DBCC SHOW_STATISTICS (tbl_SAMPLE2, idx_NAME)
							GO
							DBCC SHOW_STATISTICS (tbl_SAMPLE2, idx_TIMEINSERTED)
							GO
							DBCC SHOW_STATISTICS (tbl_SAMPLE2, idx_TOKENS)
							GO


-------------------------------------------------------
-- #21
-- Drop table 
--- DROP TABLE [dbo].[tbl_SAMPLE] 
--- GO
--- DROP TABLE [dbo].[tbl_SAMPLE2] 
--- GO

-- #22
--Drop Database
--- DROP DATABASE [DemoFragment]

----EOF


