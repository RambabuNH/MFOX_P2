/*
TAMDAQ Ambient Temperature (Location : DAQ Board)


select * from [Eng].[getTAMDAQHighLowTemps] (2883357793870413998,	'2019-12-31', '2020-01-06','Week')
select * from [Eng].[getTAMDAQHighLowTemps] (2883357793870413998,	'2019-12-31', '2020-01-01','All')


-- https://github.com/new-horizons/mf-mfox/issues/313
-- 05/13/2020  value should be the min/max tamdaq,this is fine to do on weekly basis not daily
--             Keeping the @MessageInterval =  'Week' and 'All' to list all events
*/

CREATE FUNCTION [Eng].[getTAMDAQHighLowTemps] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)='Week')  
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
	----------------------------------------------------------------------------------------------------------------------
	-- engineering report flag if TAMDAQ is <10 or >40C
	-- detail of min/max value
	----------------------------------------------------------------------------------------------------------------------
	declare @range int = 120 * 10  -- 20 minutes. for fridge Mfox Web UI link
	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [float] NULL,  -- To store TAMDAQ datatype float
		EventTime datetime2(0) 
       )  

	declare @WeekData TABLE
       (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [float]  NULL, 
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumber    int,
		RowNumDateMin int,
		RowNumDateMax int
       )  

		; with a as
		(
			SELECT 'TAMDAQ High Temp Alerts' AS [Message]
                 , 'measuredDtm of the max TAMDAQ above 40C' AS Detail--+ Convert(nvarchar,measuredDtm) AS Detail
			     , TAMDAQ 
			     , measureddtm
			  from sensorData_view  
			 where fridgeid     = @fridgeid
		       and measureddtm >= @startDate 
			   and measureddtm < @endDate
               and TAMDAQ > 40
          
		  UNION ALL

			SELECT 'TAMDAQ Low Temp Alerts' AS [Message]
                 , 'measuredDtm of the min TAMDAQ below 10C' AS Detail--+ Convert(nvarchar,measuredDtm) AS Detail
			     , TAMDAQ 
			     , measureddtm
			  from sensorData_view  
			 where fridgeid     = @fridgeid
		       and measureddtm >= @startDate 
			   and measureddtm < @endDate
               and TAMDAQ < 10 
 		)


		INSERT INTO @RawData 
		SELECT *
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
                , [Eng].[getFridgeLink] (@fridgeid, EventTime, @range) AS link 
		     FROM @RawData
        END
 
 ------------------------------------
  -- To calculate Min/least value of TAMDAQ < 10
  ----------------------------------------------
        IF @MessageInterval = 'Week'
		BEGIN
		   INSERT INTO @WeekData
		   SELECT [Message]
		        , [Detail]
		        , [value]
	            , EventTime
		        , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			    , RowNumber = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  [value] ASC)
				, RowNumDateMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime ASC)
				, RowNumDateMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
            FROM @RawData
           WHERE [value] < 10	

		   INSERT INTO @results
		   SELECT 'Week' AS [MessageInterval]
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
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumber = 1
                ) AS t1
           JOIN ( SELECT count(*) as RowCnt
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY measuredWeek
		       ) AS t2
		     ON t1.measuredWeek = t2.measuredWeek
 	       JOIN ( SELECT EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumDateMin = 1
                ) AS t3
             ON t1.measuredWeek = t3.measuredWeek
 	       JOIN ( SELECT EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumDateMax = 1
                ) AS t4
             ON t1.measuredWeek = t4.measuredWeek
        END		
  -------------------------------------------------
  -- To calculate Max/greatest value of TAMDAQ > 40
  ------------------------------------------------
        IF @MessageInterval = 'Week'
		BEGIN
		   DELETE FROM @WeekData

		   INSERT INTO @WeekData

		   SELECT [Message]
		        , [Detail]
		        , [value]
	            , EventTime
		        , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			    , RowNumber = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  [value] Desc)
				, RowNumDateMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime ASC)
				, RowNumDateMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') order by  EventTime Desc)
            FROM @RawData
           WHERE [value] > 40	

		   INSERT INTO @results
		   SELECT 'Week' AS [MessageInterval]
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
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumber = 1
                ) AS t1
           JOIN ( SELECT count(*) as RowCnt
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY measuredWeek
		       ) AS t2
		     ON t1.measuredWeek = t2.measuredWeek
 	       JOIN ( SELECT EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumDateMin = 1
                ) AS t3
             ON t1.measuredWeek = t3.measuredWeek
 	       JOIN ( SELECT EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumDateMax = 1
                ) AS t4
             ON t1.measuredWeek = t4.measuredWeek
        END		

 	return 
end
