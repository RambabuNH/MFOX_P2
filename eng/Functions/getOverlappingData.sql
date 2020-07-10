/*
select * from [Eng].[getOverlappingData] (2908746088619966487,	'2019-11-03', '2019-11-05','Hour')

-- 05/11/2020 https://github.com/new-horizons/mf-mfox/issues/320
query for overlapping data/FridgeID 

Run a count by hour of the number of records. There should be no more than 360 measurements every hour. 
If there are over 360 flag the problem. Give it a little extra, say 362 or 363 to allow for a little slop in normal timing.

Hourly Aggregation

*/

CREATE FUNCTION [Eng].[getOverlappingData] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)='Hour')  
RETURNS  @results 
TABLE
(		[MessageInterval]  [VARCHAR] (5) NULL,
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		RecCount  int Null,
		EventTime datetime2(0),
		link      [varchar](2048) null
)  

AS  
begin  
	declare @range int = 120 * 100

	declare @RawData TABLE
      ( measureddth datetime2(0)  -- Date and Hour Part 
	  , ct int -- Record count
      )  
 
	declare @HourData TABLE
     (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
 		EventTime datetime2(0) ,
	  	measuredHour datetime2(0) ,
		RowNumber int
       )  
		; with a as
		(   -- Get the data aggregated by Hour
			SELECT dateadd(hour, 1 * (datediff(hour, '20160101', measureddtm) / 1), '20160101') as measureddth
			     , count(measureddtm) as ct
              from sensordata_view
			 where fridgeid = @fridgeid
			   and measureddtm >= @startDate 
			   and measureddtm < @endDate
		      group by dateadd(hour, 1 * (datediff(hour, '20160101', measureddtm) / 1), '20160101')
    	)

		INSERT INTO @RawData 
		SELECT *
		  FROM a


        IF @MessageInterval = 'All'
		BEGIN
		   INSERT INTO @results
		   SELECT 'All' AS [MessageInterval]
		        ,  'Overlapping data/FridgeID' AS [Message]
				, NULL AS [Detail] 
				, NULL AS [value]  
				, ct AS RecCount 
				, measureddth as measuredHour
				, [Eng].[getFridgeLink] (@fridgeid, measureddth, @range) AS link 
		     FROM @RawData
        END
        ELSE IF @MessageInterval = 'Hour'
		BEGIN
		   INSERT INTO @results
		   SELECT 'Hour' AS [MessageInterval]
		        , 'Overlapping data/FridgeID' AS [Message]
				, 'More than 370 measurements in this hour' AS [Detail] 
				, NULL AS [value]  
				, ct AS RecCount 
				, measureddth as EventTime
				, [Eng].[getFridgeLink] (@fridgeid, measureddth, @range) AS link 
		     FROM @RawData
            WHERE ct >= 370
        END
      

 	return 
end
