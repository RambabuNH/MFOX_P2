/*
-- https://github.com/new-horizons/mf-mfox/issues/311
Low Temperature Alert

select * from [Eng].[getLowTemperatures](2919283236796367032,'2020-04-24','2020-05-04','All') 

select * from [Eng].[getLowTemperatures](2911325237922496634,'2020-05-04','2020-05-05','Hour') -- -0.06	2914	2020-05-04 15:59:36
select * from [Eng].[getLowTemperatures](2911325237922496634,'2020-05-04','2020-05-05','Day') 


*/

CREATE FUNCTION [eng].[getLowTemperatures] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)='Day' )  
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
	DECLARE @range int = 120 * 10  ---- 20 minutes. for fridge Mfox Web UI link
	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   float  NULL, 
		EventTime datetime2(0) 
       )  
	declare @DayData TABLE
      (
		[value]   float NULL, 
		[Detail]  [varchar](255)  NULL,
		EventTime datetime2(0) ,
		measuredDay datetime2(0) ,
		RowNum       int,
		RowNumDayMin int,
		RowNumDayMax int
       )  


	----------------------------------------------------------------------------------------------------------------------
	-- Low temperatures, flag units with TVCTOPCTL or TVCBOT < 2C  
	----------------------------------------------------------------------------------------------------------------------	
		;with a as
		(
			select measureddtm
			     , 'excursion is TVCTOPCTL < 2' as Detail
			     , TVCTOPCTL AS TVCTOPCTL_TVCBOT_Value
			  from sensordata_view
			 where FridgeId    = @fridgeid
			   and measureddtm >= @startDate 
			   and measureddtm < @endDate
			   and TVCTOPCTL < 2
   
		     
			 UNION ALL
			 select measureddtm
		         , 'excursion is TVCBOT < 2' as Detail
			     , TVCBOT AS TVCTOPCTL_TVCBOT_Value
			  from sensordata_view
			 where FridgeId    = @fridgeid
			   and measureddtm >= @startDate 
			   and measureddtm < @endDate
			   and TVCBOT < 2
 
		)
	   INSERT INTO @RawData
       SELECT 'Low Temperature Alert' AS [Message]
            , Detail
			, TVCTOPCTL_TVCBOT_Value AS  [Value]
			, measureddtm as EventTime
		FROM a

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
	
 	ELSE IF @MessageInterval = 'Day'
	BEGIN
	   INSERT INTO @DayData
	   SELECT [value]
	        , [Detail]
	        , EventTime
		    , dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') AS measuredDay
			, RowNum       = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  [value] Asc)
			, RowNumDayMin = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Asc)
   			, RowNumDayMax = ROW_NUMBER() over (partition by  dateadd(Day,  (datediff(Day, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
        FROM @RawData
	   
	   INSERT INTO @results
	   SELECT 'Day' AS [MessageInterval]
	        , 'Low Temperature Alert' AS [Message]
	        , t1.Detail
			, t1.[value] 
			, t2.RowCnt  
			, t1.EventTime
            , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t3.EventTime, t4.EventTime, @range) AS link
	     FROM ( SELECT [value]
	                 , [Detail]
		             , EventTime
					 , measuredDay
		          FROM @DayData
                 WHERE RowNum = 1
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
                 WHERE RowNumDayMin = 1
                ) AS t3
             ON t1.measuredDay = t3.measuredDay
 	     JOIN ( SELECT EventTime
					, measuredDay
		          FROM @DayData
                 WHERE RowNumDayMax = 1
                ) AS t4
             ON t1.measuredDay = t4.measuredDay
    END

	return 
END
