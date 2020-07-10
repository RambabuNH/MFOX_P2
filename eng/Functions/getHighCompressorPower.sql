/*
-- https://github.com/new-horizons/mf-mfox/issues/312

all non-consecutive occurrences of EWCP > 600 W for mains and EWCP > 100 W for solar.
 
select * from [Eng].[getHighCompressorPower](2927167315021660373,'2019-11-01','2019-11-02','Day') 

select * from [Eng].[getHighCompressorPower](2951796057622708459,'2020-05-31','2020-06-01','day') 


select * from [Eng].[getHighCompressorPower](2948795228397502521,'2019-12-08','2019-12-09','Day') -- above 600 Just one

select * from [Eng].[getHighCompressorPower](2904381036047630343,'2019-11-03','2019-11-04','Day')  -- Above 1000 just one record

select * from [Eng].[getHighCompressorPower](2894612171570806822,'2020-02-03','2020-02-04','Day') 


select * from [Eng].[getHighCompressorPower](2904059978652319929,'2019-12-20','2019-12-21','Day')  -- No output as one record above 600

select * from [Eng].[getHighCompressorPower](2943549501371056246,'2020-01-16','2020-01-17','Day') -- Solar fridge

-- 05/18/2020 Refer to Issue 312 : for mains fridges criteria: during the week there are either >=2 records of EWCP>600W or >=1 record with EWCP > 1000W
                                   record count: # of records above 600 or 1000 (if both criteria are met use the 600 count)

					 --let's keep this as daily aggregation for now. may switch to weekly after I see how the full report goes.
*/

CREATE FUNCTION [eng].[getHighCompressorPower] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5) ='Day')  
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
	DECLARE @range int = 120 * 10  -- 20 minutes. for fridge Mfox Web UI link
	      , @FridgeType char(1)

    SELECT @range = @range * 6 -- To make 2 hours
   
    SELECT @FridgeType =  case when @fridgeid in (select fridgeid 
	                                  from GroupFridge where GroupName = 'solar') then 'S' 
							   else 'M' 
			               end
	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   float  NULL, 
		Above600Cnt  int null,
		Above1000Cnt int null,
		measuredDay  datetime2(0) null,
		measuredWeek datetime2(0) null,
		EventTime datetime2(0) 
       )  
	declare @DayData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   float  NULL, 
		EventTime datetime2(0) ,
		measuredDay datetime2(0) ,
		RowNumber int,
	    RowNumDateMin int,
		RowNumDateMax int
       )  
	declare @WeekData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   float  NULL, 
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumber int,
		RowNumDateMin int,
		RowNumDateMax int
       )  

    IF @FridgeType = 'S'
	BEGIN
	    insert into @RawData
	    select 'high compressor power (Solar Fridge)'
	         , 'EWCP > 130 threshold was met' AS Details
	         , EWCP AS [Value]
			 , NULL
			 , NULL
			 , NULL
			 , NULL
		     , measuredDtm AS EventTime
         from sensorSolarData_view    
        where FRIDGEID    = @fridgeid
          and measuredDtm >= @startDate 
		  and measuredDtm < @endDate
          and EWCP > 130 -- W for solar
 	END

    IF @FridgeType = 'M'
	BEGIN
	    insert into @RawData
	    select 'high compressor power (Main Fridge)'
	         , CASE WHEN (EWCP2 > 600 AND EWCP2 < 1000)  THEN 'EWCP > 600 threshold was met' 
			        WHEN EWCP2 > 1000 THEN 'EWCP > 1000 threshold condtions met' 
					ELSE NULL
			    END AS Detail
	         , EWCP2 AS [Value]
			 , CASE WHEN (EWCP2 > 600 AND EWCP2 < 1000) THEN 1 
			        ELSE 0
				END AS Above600Cnt
			 , CASE WHEN EWCP2 > 1000 THEN 1 
			        ELSE 0
				END AS Above1000Cnt
			 , dateadd(Day,  (datediff(Day, '20160101', measuredDtm)  ), '20160101') AS measuredDay
			 , dateadd(Week,  (datediff(Week, '20160101', measuredDtm)  ), '20160101') AS measuredWeek
		     , measuredDtm AS EventTime
         from sensorData_view    
        where FRIDGEID    = @fridgeid
          and measuredDtm >= @startDate 
		  and measuredDtm < @endDate
          and EWCP2 > 600 -- W for mains
 	END	
	
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

    IF (@MessageInterval = 'Day' AND @FridgeType = 'S')
	BEGIN
	   INSERT INTO @DayData
	   SELECT [Message]
			, [Detail] 
	        , [value]
	        , EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNumber = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Desc)
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] ASC)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Desc)

        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
            , t1.[Message]
	        , t1.[Detail]			
			, t1.[value] 
			, t2.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t3.EventTime, t4.EventTime, @range) AS link
	     FROM ( SELECT [Message]
	                 , [Detail]
			         , [value] 
		             , EventTime
					 , measuredDay
		          FROM @DayData
                 WHERE RowNumber = 1
              ) AS t1
         JOIN ( SELECT count(*) as RowCnt
		             , measuredDay
		          FROM @DayData
                 GROUP BY measuredDay
		      ) AS t2
		    ON t1.measuredDay = t2.measuredDay
          JOIN ( SELECT EventTime
					   , measuredDay
		          FROM @DayData
                 WHERE RowNumDateMin = 1
                ) AS t3
             ON t1.measuredDay = t3.measuredDay
 	       JOIN ( SELECT EventTime
					   , measuredDay
		          FROM @DayData
                 WHERE RowNumDateMax = 1
                ) AS t4
             ON t1.measuredDay = t4.measuredDay
    END

	IF (@MessageInterval = 'Day' AND @FridgeType = 'M')
	BEGIN
	   INSERT INTO @DayData
	   SELECT [Message]
			, [Detail] 
	        , [value]
	        , EventTime
		    , measuredDay
			, RowNumber = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Desc)
			, RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] ASC)
			, RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Desc)

        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
            , t1.[Message]
	        , t2.[Detail]			
			, t1.[value] 
			, t2.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t3.EventTime, t4.EventTime, @range) AS link
	     FROM ( SELECT [Message]
			         , [value] 
		             , EventTime
					 , measuredDay
		          FROM @DayData
                 WHERE RowNumber = 1
              ) AS t1
         JOIN ( SELECT CASE WHEN Above600Cnt >= 2  THEN Above600Cnt
		                    WHEN Above1000Cnt >= 1 THEN Above1000Cnt
		                    WHEN (Above600Cnt >= 2  AND Above1000Cnt >= 1) THEN Above600Cnt + Above1000Cnt
		                END AS RowCnt
                     ,  CASE WHEN Above600Cnt >= 2  THEN 'EWCP > 600 threshold was met( 2 or more such records exists)' 
		                     WHEN Above1000Cnt >= 1 THEN 'EWCP > 1000 threshold condition was met(with 1 or more such records).'
		                     WHEN (Above600Cnt >= 2  AND Above1000Cnt >= 1) THEN 'Both conditions met (EWCP > 600 with more than 2 records  and EWCP > 1000 threshold with 1 or more records) '
		                END AS [Detail]
		             , t20.measuredDay
		        FROM (
					SELECT SUM(Above600Cnt) as Above600Cnt
						 , SUM(Above1000Cnt) as Above1000Cnt
 						 , measuredDay
					  FROM @RawData
					 GROUP BY measuredDay
		             ) as t20
			) AS t2
		    ON t1.measuredDay = t2.measuredDay
		   AND t2.RowCnt >= 1
          JOIN ( SELECT EventTime
					   , measuredDay
		          FROM @DayData
                 WHERE RowNumDateMin = 1
                ) AS t3
             ON t1.measuredDay = t3.measuredDay
 	       JOIN ( SELECT EventTime
					   , measuredDay
		          FROM @DayData
                 WHERE RowNumDateMax = 1
                ) AS t4
             ON t1.measuredDay = t4.measuredDay

    END

	return 
END
