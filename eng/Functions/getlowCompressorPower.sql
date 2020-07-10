/*
-- https://github.com/new-horizons/mf-mfox/issues/222
   does not apply to solar fridges
   low charge condition, measured by checking compressor power just before shutdown, problems show up here first
   gets 5 minute average power, 2 minutes prior to shutdown, must meet minimum record count


select * from [Eng].[getlowCompressorPower](2900161106125259006,'2020-05-29','2020-05-30','All') 
 
select * from [Eng].[getlowCompressorPower](2885977410421915833,'2020-05-29','2020-05-30','Day') 
select * from [Eng].[getlowCompressorPower](2906363618721267897,'2020-05-29','2020-05-30','Day') 

select * from [Eng].[getlowCompressorPower](2947297169608016007,'2020-05-24','2020-05-31','Week') 


-- 06/22/2020  change those thresholds to 170W for high ambient and 160W otherwise.
*/



CREATE FUNCTION [eng].[getlowCompressorPower] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5) )  

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
		 , @count int = 8


	declare @RawData TABLE
      (
		EventTime datetime2(0) , -- sp shutdown time
		ct        int,
		avgEWCP   float,
		avgTAMDAQ float
       )  
	declare @DayData TABLE
      ( 
	  	[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
	    [value] float,
	    EventTime datetime2(0) ,
		measuredDay datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  
	declare @WeekData TABLE
      ( [Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
	    [value] float,
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  

  	;with a as
	(
		select fridgeid
         	 , scpx as s1
		     , lead(measureddtm) over (partition by fridgeid order by measureddtm) as t2 
		     , lead(scpx) over (partition by fridgeid order by measureddtm) as s2
		  from sensordata_view  
	     where fridgeid    =  @fridgeid
		   and fridgeid not in (select fridgeid from GroupFridge where GroupName = 'solar')
	       and measuredDtm >= @startDate
	       and measuredDtm <  @endDate 
	)
	
	,b as
	(
		SELECT fridgeid
		     , DATEADD(minute,-2,t2) as sp 
			  -- need a minute or two before shutdown to eliminate artificially low readings
		  FROM a
		 WHERE (s1 = 1 and s2 != 1) 
	)

	,c as
	(  	SELECT b.fridgeid
	         , b.sp
			 , count(*) as ct
			 , avg(EWCP2) as avgEWCP
			 , avg(TAMDAQ) as avgTAMDAQ
		  FROM b
		 INNER join sensordata_view s 
		    on b.FridgeID = s.FRIDGEID 
		   and measuredDtm > dateadd(minute,-2,b.sp) 
		   and measuredDtm < b.sp 
		   and scpx = 1 and ewcp2 != 0 
		  group by b.FridgeID,   b.sp
	)

   
   INSERT INTO @RawData
   SELECT sp AS EventTime
        , ct
		, avgEWCP
		, avgTAMDAQ
     FROM c
 

    IF @MessageInterval = 'All'
	BEGIN
	   INSERT INTO @results
	   SELECT 'All' AS [MessageInterval]
	        , 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 160 watts , low ambient'AS [Detail] 
			, avgEWCP AS [value]  
			, ct AS RecCount 
			, EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, EventTime, dateadd(hour,1,EventTime), @range) AS link 
	     FROM @RawData
	    where avgEWCP >= 1 and avgEWCP < 160
	      and ct > @count  
	      and avgTAMDAQ < 30 

     UNION ALL

	   SELECT 'All' AS [MessageInterval]
	        , 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 170 watts, high ambient'AS [Detail] 
			, avgEWCP AS [value]  
			, ct AS RecCount 
			, EventTime
            , [Eng].[getFridgeLink] (@fridgeid, EventTime, @range) AS link 
	     FROM @RawData
	    where avgEWCP >= 160 and avgEWCP < 170
		  and ct > @count 
		  and avgTAMDAQ >= 30 

    END

    IF @MessageInterval = 'Day'
	BEGIN
	   INSERT INTO @DayData
	   SELECT 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 160 watts, low ambient'AS [Detail] 
	        , avgEWCP AS [value]  
	        , EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   where avgEWCP >= 1 and avgEWCP < 160
	     and ct > @count  
	     and avgTAMDAQ < 30 
		
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
	        , t1.[Message]
			, t1.[Detail] 
			, t1.[value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT [Message]
			         , [Detail] 
		             , [value] 
		             , EventTime
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

       DELETE @DayData
       INSERT INTO @DayData
	   SELECT 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 170 watts, high ambient'AS [Detail] 
	        , avgEWCP AS [value]  
	        , EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	    where avgEWCP >= 160 and avgEWCP < 170 
		  and ct > @count 
		  and avgTAMDAQ >= 30 

	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
	        , t1.[Message]
			, t1.[Detail] 
			, t1.[value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT [Message]
			         , [Detail] 
		             , [value] 
		             , EventTime
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
    END

    IF @MessageInterval = 'Week'
	BEGIN
	   INSERT INTO @WeekData
	   SELECT 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 160 watts, low ambient'AS [Detail] 
	        , avgEWCP AS [value]  
	        , EventTime
		    , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   where avgEWCP >= 1 and avgEWCP < 160
	     and ct > @count  
	     and avgTAMDAQ < 30 
		  
	   INSERT INTO @results
	   SELECT 'Week' AS [MessageInterval]
	        , t1.[Message]
			, t1.[Detail] 
			, t1.[value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT [Message]
		             , [Detail]
		             , [value] 
		             , EventTime
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
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek
       
	   DELETE @WeekData
	   INSERT INTO @WeekData
	   SELECT 'Low compressor power, check for low charge' AS [Message]
			, '2 minute average < 170 watts, high ambient'AS [Detail] 
	        , avgEWCP AS [value]  
	        , EventTime
		    , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   where avgEWCP >= 160 and avgEWCP < 170
		 and ct > @count 
		 and avgTAMDAQ >= 30 

	   INSERT INTO @results
	   SELECT 'Week' AS [MessageInterval]
	        , t1.[Message]
			, t1.[Detail] 
			, t1.[value] 
			, t3.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
	     FROM ( SELECT [Message]
		             , [Detail]
		             , [value] 
		             , EventTime
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
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek


    END

   return 

END


 
