/*
-- https://github.com/new-horizons/mf-mfox/issues/318
--
	drop table if exists #fridge

	select l.fridgeid
	into #fridge
	from latestFridgeLocation3_view l
	where l.Country = 'Nigeria' 
	and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
	--and fridgeid in (2919283236796367032, 2910809566969069806)

	SELECT *
	FROM #fridge f
	CROSS APPLY [Eng].[getMechThermTrippedAll](f.fridgeid, '2020-4-19', '2040-4-26','All') u
	order by 1,2

	2929263765834694672	2020-04-21 09:56:32
	2929263765834694672	2020-04-21 10:00:52

	-------------------------------------------------------------------

	drop table if exists #fridge

	select l.fridgeid
	into #fridge
	from latestFridgeLocation3_view l
	where l.Country = 'Nigeria' 
	and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
	and fridgeid in (2919283236796367032, 2910809566969069806)

	SELECT *
	FROM #fridge f
	CROSS APPLY [Eng].[getMechThermTrippedAll](f.fridgeid, '2019-11-1', '2019-11-18') u
	order by 1,2

	-- test cases

	-- will trip with either algorithm, should return three results
	select * from [Eng].[getMechThermTrippedAll] (2910809566969069806, '2019-11-5 3:30', '2019-11-5 6:00','All') 
	2019-11-05 03:43:32
	2019-11-05 05:08:21
	2019-11-05 03:51:13

	-- only trips with first
	select * from [Eng].[getMechThermTrippedAll] (2919283236796367032, '2019-11-4 17:00', '2019-11-4 17:30') 

	-- only trips with second
	select * from [Eng].[getMechThermTrippedAll] (2935511813690753220, '2020-2-8 13:00', '2020-2-9 13:30') 

	select * from [Eng].[getMechThermTrippedAll] (2907236149883830276, '2019-12-28 14:30', '2019-12-28 15:00') 

	select * from [Eng].[getMechThermTrippedAll] (2909254591239422000, '2020-4-28','2020-4-29','All')
	select * from [Eng].[getMechThermTrippedAll] (2909254591239422000, '2020-4-28','2020-4-29','Hour')
	select * from [Eng].[getMechThermTrippedAll] (2909254591239422000, '2020-4-28','2020-4-29','Day')
	select * from [Eng].[getMechThermTrippedAll] (2909254591239422000, '2020-4-28','2020-4-29','Week')

*/

CREATE FUNCTION [Eng].[getMechThermTrippedAll] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)  )  
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
begin  

	----------------------------------------------------------------------------------------------------------------------
	-- Mech Thermostat engaged
	-- closed when temperature is 2 deg +- 1.5
	-- opens when temp drops to -1.5 +- 1.5
	-- breaks the ac power connection to compressor
	-- thermostat tends to stick, events may be disassociated
	----------------------------------------------------------------------------------------------------------------------

	----------------------------------------------------------------------------------------------------------------------
	-- first case is when the thermostat trips when compressor is running
	-- compressor is supposed to be running, has enough EVLN, SLNX = 1 just before shutdown
	----------------------------------------------------------------------------------------------------------------------
	declare @range int = 120 * 10 -- 20 Minutes
		  , @FridgeType char(1)
		  , @hourCnt  int

    SELECT @FridgeType =  case when @fridgeid in (select fridgeid 
	                                  from GroupFridge where GroupName = 'solar') then 'S' 
							   else 'M' 
			               end

	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		EventTime datetime2(0) 
       )  

	declare @HourData TABLE
      (	[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		EventTime datetime2(0) ,
	  	measuredHour datetime2(0) ,
		RowNumber int
       )  
	declare @DayData TABLE
      ( [Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		EventTime datetime2(0) ,
	  	measuredDay datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  
	declare @WeekData TABLE
      ( [Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  
	declare @SolarWeekData TABLE
      ( HoursCount int,
	    measuredWeek datetime2(0) ,
		[Detail]  [varchar](255)  NULL
       )  

  ---------------------------------------------------------------------------------
  --mech thermostat for solar fridges ( SCPS>=1000 but EWCP<1)
  ----------------------------------------------------------------------------------
    IF @FridgeType = 'S'
	BEGIN
	    insert into @RawData
	    select 'solar compressor not running' --'Mech Thermostat Engaged (Solar Fridge) : '
	         , 'Event Time of thermostat trips when compressor is running' AS Detail
	         , NULL AS [Value]
		     , measuredDtm AS EventTime
         from sensorSolarData_view    
        where FRIDGEID    = @fridgeid
          and measuredDtm >= @startDate 
		  and measuredDtm < @endDate
          and SCPS = 2000 and ICPS=0
   		  and (EWDCA>60 or SLNX=1)
 	END

	-- SCPX compressor running = 1, off = 0, look for transitions from running to off
	;with a as
	(
		select
		measureddtm as dtm,
		scpx as s1,
		lead(scpx) over (order by measureddtm) as s2
		from sensordata_view v 
		where v.FRIDGEID = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
		  and @FridgeType = 'M' 
	)

	-- filter to just get the compressor shut down events
	,b as
	(
		SELECT 
		dtm
		FROM a
		where (s1 = 1 and s2 != 1) 
	)

	-- get the average EWCP in time window before compressor shuts down
	,c as
	(
		select 
		dtm,
		avg(EWCP2) as avgEWCP
		from b
		inner join sensordata_view s 
		on s.FRIDGEID = @fridgeid and measuredDtm >= dateadd(SECOND,-60,b.dtm) and measuredDtm <= DATEADD(second,-30,dtm) and scpx = 1 and ewcp2 != 0 
		group by b.dtm
	)

	insert into @RawData
	select  'Mech Thermostat Engaged'
	     , 'Event Time of thermostat trips when compressor is running' AS Detail
	     , NULL AS [Value]
		 , dtm AS EventTime
	  from c where avgEWCP < 1

	----------------------------------------------------------------------------------------------------------------------
	-- case where thermostat trips before compressor is supposed to start but doesn't
	----------------------------------------------------------------------------------------------------------------------

	-- SCPX compressor running = 1, off = 0, look for transitions from running to off
	;with a as
	(
		select
		measureddtm as dtm,
		scpx as s1,
		lead(scpx) over (order by measureddtm) as s2
		from sensordata_view v 
		where v.FRIDGEID = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
		  and @FridgeType = 'M' 
	)

	-- filter to just get the compressor shut down events
	,b as
	(
		SELECT 
		dtm
		FROM a
		where (s1 != 1 and s2 = 1) 
	)

	-- get the average EWCP in time window before compressor shuts down
	,c as
	(
		select 
		dtm,
		avg(EWCP2) as avgEWCP
		from b
		inner join sensordata_view s 
		on s.FRIDGEID = @fridgeid and measuredDtm >= dateadd(SECOND, 30,b.dtm) and measuredDtm <= DATEADD(second,60,dtm) and scpx = 1 and ewcp2 != 0 
		group by b.dtm
	)

	insert into @RawData
	select 'Mech Thermostat Engaged'
	     , 'Event Time of thermostat trips before compressor is supposed to start but doesn''t' AS Details
	     , NULL AS [Value] --dtm AS [Value]  05/19/2020 No need to repeat same in both columns ([Value] & EventTime)
		 , dtm AS EventTime
	  from c where avgEWCP < 1

   IF @MessageInterval = 'All'
	BEGIN
	   INSERT INTO @results
	   SELECT 'All' AS [MessageInterval]
	        , [Message]
			, [Detail] 
			, [value]  
			, 1 AS RecCount 
			, EventTime
            , [Eng].[getFridgeLink] (@fridgeid, EventTime, @range) AS link 
	     FROM @RawData
    END
 	ELSE IF (@MessageInterval = 'Day' AND @FridgeType = 'S') -- Solar fridge, Row count > 5
	BEGIN
	   INSERT INTO @DayData
	   SELECT [Message]
			, [Detail] 
	        , [value]
			, EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
         FROM @RawData
	   
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
		             , [Detail]
		             , measuredDay
		          FROM @DayData
                 GROUP BY measuredDay , [Detail]
		      ) AS t3
		    ON t1.measuredDay = t3.measuredDay
		   AND t1.[Detail]  = t3.Detail
		   AND t3.RowCnt > 5
    END
 	ELSE IF (@MessageInterval = 'Day' AND @FridgeType = 'M') -- Main Fridge
	BEGIN
	   INSERT INTO @DayData
	   SELECT [Message]
			, [Detail] 
	        , [value]
			, EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
         FROM @RawData
	   
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
		             , [Detail]
		             , measuredDay
		          FROM @DayData
                 GROUP BY measuredDay , [Detail]
		      ) AS t3
		    ON t1.measuredDay = t3.measuredDay
		   AND t1.[Detail]  = t3.Detail
    END
	--06/01/20 Solar fridges Looking for events where there are at least 5 counts per hour, for 4 such hours within a week
	ELSE IF (@MessageInterval = 'Week' AND @FridgeType = 'S') -- Solar fridge, Row count > 5
	BEGIN
	  
	   INSERT INTO @SolarWeekData
	        ( HoursCount
			, measuredWeek
			, Detail
			)
	   SELECT count(ISNULL(t2.measuredHour,0)) as HoursCount 
	        , t2.measuredWeek
			, 'Event Time of thermostat trips when compressor is running' AS Detail
	     FROM ( select count(*) as CountByHour, t1.measuredHour ,t1.measuredWeek
	              from ( select dateadd(hour,  (datediff(hour, '20160101', EventTime)  ), '20160101') as measuredHour
				              , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek 
	                       from @RawData
                       ) as t1
	              group by t1.measuredHour,t1.measuredWeek
	              having count(*) > 5
               ) as t2
         group by t2.measuredWeek
        having count(ISNULL(t2.measuredHour,0)) >=4

 
	   INSERT INTO @WeekData
	   SELECT [Message]
			, [Detail] 
	        , [value]
			, EventTime
		    , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek 
			, RowNumberMin = ROW_NUMBER() over (partition by  [Detail],dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime ASC )
			, RowNumberMax = ROW_NUMBER() over (partition by  [Detail],dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	
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
		             , [Detail]
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY measuredWeek, [Detail]
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek
           AND t1.[Detail]  = t3.[Detail]
	
	    JOIN ( SELECT distinct measuredWeek
		            , [Detail]
		         FROM @SolarWeekData
		      ) AS t4
		    ON t1.measuredWeek = t4.measuredWeek
           AND t1.[Detail]     = t4.[Detail]
   
    END

	ELSE IF (@MessageInterval = 'Week' AND @FridgeType = 'M') -- Main fridge
	BEGIN
	   INSERT INTO @WeekData
	   SELECT [Message]
			, [Detail] 
	        , [value]
			, EventTime
		    , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek 
			, RowNumberMin = ROW_NUMBER() over (partition by  [Detail],dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime ASC )
			, RowNumberMax = ROW_NUMBER() over (partition by  [Detail],dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)

        FROM @RawData
	   
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
		             , [Detail]
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY measuredWeek, [Detail]
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek
           AND t1.[Detail]  = t3.[Detail]
    END

	return 

end