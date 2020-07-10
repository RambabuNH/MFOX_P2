/*
-- https://github.com/new-horizons/mf-mfox/issues/292

For a given fridge each day- the first measuredDtm instance for EVLN > 350 , total such records  

select * from [Eng].[getHighVoltageEvents](2906363618721267897,'2020-04-20','2020-04-24','All') 
 
select * from [Eng].[getHighVoltageEvents](2906363618721267897,'2020-04-20','2020-04-24','Day') 

select * from [Eng].[getHighVoltageEvents](2924524080478552203,'2020-04-12','2020-04-24','Day') 

select * from [Eng].[getHighVoltageEvents](2918223883146362992,'2020-06-14','2020-06-21','Day') 



-- 05/13/2020 Per latest requirements specified in Issue 292

link should go to the entire time span when EVLN>350 V

yes time span will cut off at midnight if the event spans multiple days
if there are multiple instances when EVLN is high during the day (voltages go back and forth across 350) show from an hour
before the first >350V event to an hour after the last >350V event
could also show [timespan - 5% of event duration] to [timespan + 5% of event duration ] with a minimum of 10 minutes on 
either side?

-- 05/18/2020  Removed Hour/Week aggregation per Jenny. Only Aggregation by Day 
*/



CREATE FUNCTION [eng].[getHighVoltageEvents] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5) )  

RETURNS  @results 
TABLE
(       [MessageInterval]  [VARCHAR] (5) NULL,
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		RecCount  int Null,
		EventTime datetime2(0),
		link      [varchar](2048) null
)  

AS  
BEGIN  
	--DECLARE @range int = 120 * 10  -- for fridge Mfox Web UI link (to show in UI 20 minutes before and after the event)
	DECLARE @range int = 60 * 10  --5/13/2020 for fridge Mfox Web UI link (to show in UI 10 minutes before and after the event)
	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   float  NULL, 
		EventTime datetime2(0) 
       )  
 
	declare @DayData TABLE
      (
		[value]   float  NULL, 
	    EventTime datetime2(0) ,
		measuredDay datetime2(0) ,
		RowNumber int,
		RowNumberMin int,
		RowNumberMax int
       )  
 

   ;with hvEvents_CTE as
	   (SELECT measuredDtm
			 , EVLN
          from sensordata_view
         where FRIDGEID    =  @fridgeid
	       and measuredDtm >= @startDate
	       and measuredDtm <  @endDate 
	       and EVLN > 350
       )
   
   INSERT INTO @RawData
   SELECT 'High voltage event' AS [Message]
        , 'measuredDtm of the first high voltage event' AS Detail
        , EVLN AS [value]
		, measuredDtm AS EventTime
     FROM hvEvents_CTE
    --WHERE rn = 1

    IF @MessageInterval = 'All'
	BEGIN
	   INSERT INTO @results
	   SELECT 'All' AS [MessageInterval]
	        , [Message]
			, [Detail] 
			, [value]  
			, 1 AS RecCount 
			, EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, EventTime, dateadd(hour,1,EventTime), @range) AS link 
	     FROM @RawData
    END

    IF @MessageInterval = 'Day'
	BEGIN
	   INSERT INTO @DayData
	   SELECT [value]
	        , EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumber = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Desc)

			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
	        , 'High voltage event' AS [Message]
	        , 'EventTime of the first high voltage event ' AS [Detail]
			, t4.[value] -- get the Maximum value during that day
			, t3.RowCnt  
			, t4.EventTime -- Time of the max value 
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT EventTime
					 , measuredDay
		          FROM @DayData
                 WHERE RowNumberMin = 1
              ) AS t1
	     JOIN ( SELECT EventTime
					 , measuredDay
		          FROM @DayData
                 WHERE RowNumberMax = 1
              ) AS t2
		    ON t1.measuredDay = t2.measuredDay

         JOIN ( SELECT count(*) as RowCnt
		             , measuredDay
		          FROM @DayData
                 GROUP BY measuredDay
		      ) AS t3
		    ON t1.measuredDay = t3.measuredDay

         JOIN ( SELECT [value]
		             , EventTime
		             , measuredDay
		          FROM @DayData
                 WHERE RowNumber = 1
		      ) AS t4
		    ON t1.measuredDay = t4.measuredDay
    END


   return 

END


 
