/*
https://github.com/new-horizons/mf-mfox/issues/280
Help Field Techs Troubleshoot Bad Time and Using Incorrect FridgeID

select * from [Eng].[getBadDate] (2886308049855709337, '2020-05-20', '2020-05-31','Day')   
select * from [Eng].[getBadDate] (2946809776685711543, '2020-05-20', '2020-05-31','Day')  
select * from [Eng].[getBadDate] (2892675317397192824, '2020-05-20', '2020-05-31','All')   
*/



CREATE FUNCTION [eng].[getBadDate] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5) ='Day')  

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
	DECLARE @range int = 120 * 10  -- 20 minutes for fridge Mfox Web UI link (to show in UI 20 minutes before and after the event)
	declare @RawData TABLE
      (
		 EventTime datetime2(0) 
		, ct int
       )  
	declare @DayData TABLE
      (
	    EventTime datetime2(0) ,
		measuredDay datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  
	declare @WeekData TABLE
      (
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  
 
    INSERT INTO @RawData

	SELECT createddtm
	     , count(*) as ct
	  FROM [dbo].[IncomingErrorsTime]
	 where fridgeid = @fridgeid
	   AND createddtm >= @startDate
       AND createddtm <  @endDate
	--   AND code = 'FFEF' -- 6/8/20 All records in this table are FFEF
	 GROUP by  createddtm
--	HAVING count(*) > 100
 
    IF @MessageInterval = 'All'
	BEGIN
	   INSERT INTO @results
	   SELECT 'All' AS [MessageInterval]
	        , 'Bad Time '[Message]
			, 'Help Field Techs Troubleshoot Bad Time and Using Incorrect FridgeID' AS [Detail] 
			, NULL AS [value]  
			, ct AS RecCount 
			, EventTime
            , [Eng].[getFridgeLink] (@fridgeid, EventTime, @range) AS link 
	     FROM @RawData
    END

    IF @MessageInterval = 'Day'
	BEGIN
	   INSERT INTO @DayData
	   SELECT EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
	        , 'Bad Time '[Message]
			, 'Help Field Techs Troubleshoot Bad Time and Using Incorrect FridgeID' AS [Detail] 
			, NULL AS [value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT  EventTime
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
				 HAVING count(*) > 100
		      ) AS t3
		    ON t1.measuredDay = t3.measuredDay
    END

	IF @MessageInterval = 'Week'
	BEGIN
	   INSERT INTO @WeekData
	   SELECT EventTime
		    , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Week' AS [MessageInterval]
	        , 'Bad Time '[Message]
			, 'Help Field Techs Troubleshoot Bad Time and Using Incorrect FridgeID' AS [Detail] 
			, NULL AS [value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT  EventTime
					 , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMin = 1
              ) AS t1
	     JOIN ( SELECT EventTime
					 , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMax = 1
              ) AS t2
		    ON t1.measuredWeek = t2.measuredWeek

         JOIN ( SELECT count(*) as RowCnt
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY measuredWeek
				 HAVING count(*) > 100
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek
    END

	return 

END
