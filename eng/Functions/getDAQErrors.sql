/*
select * from [Eng].[getDAQErrors] (2906363618721267897,	'2020-01-03', '2020-05-01','All')
 
select * from [Eng].[getDAQErrors] (2886527161940836478,	'2020-05-10', '2020-05-17','Week')

select * from [Eng].[getDAQErrors] (2907285353029173311,	'2020-05-10', '2020-05-17','Week') 

-- 05/11/2020 https://github.com/new-horizons/mf-mfox/issues/317
for DAQ sensor errors I want all of the 618* errors
6181,6182,6183,6184,6185,6186,6187,6188,6189,618a,618b,618c
For any errors in this list show a single message/line in the report:
message: DAQ sensor error
detail: all error codes from the above list that occurred during the week
value: error count over the week, sum of all counts for all the 618* errors
The link should go to grafana for the time range covered by the report, with the relevant error selected.

other things to put in the value column (I) of the sheet:
5882: show the minimum EWCP while SCPX=1
5889: show the minimum TEVIN while SCPX=1
5888: show the maximum TCDOUT while SCPX=1
5881 max ewcp while scpx=1
5884 % of control packets missing tvctopctl over the week (@tkreyche has a query for this in the tech report)
5084 max, min ecdbat during the week (show "[maxvalue, minvalue]")

for 440D ,4408  and 640C leave blank

*/

CREATE FUNCTION [eng].[getDAQErrors] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)='Week')  
RETURNS  @results 
TABLE
(		[MessageInterval]  [VARCHAR] (5) NULL,
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		RecCount  int Null,
		EventTime datetime2(0),
		link      [varchar](2048) null,  -- MFOX Link
		Glink     [varchar](2048) null   -- Grafana Link
)  

AS  
begin  
	----------------------------------------------------------------------------------------------------------------------
	-- DAQ Errors
	-- ( '640C','4408','440D','5881','5882','5884','5885','5888','5889','5084') plus all 618* errors
	----------------------------------------------------------------------------------------------------------------------
	declare @range int = 120 * 10 -- 20 minutes
	      , @DAQ618ErrorCount  int
		  , @DAQ618CodeString  varchar(255)
		  , @BadSensorNames    varchar(255)
		  , @DAQ618GrafanCodeString varchar(255)
		  , @days int = datediff(day,@startDate, @endDate)
    
	-- grafana link needs to go to the entire time period covered by the report, not the time of the first event.
    -- for DAQ errors let's just do the week of the report with 6 extra hours on either side
	SET @range = @range * 18 -- 20 minutes * 18 is 6 hours

	declare @RawData TABLE
      (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL,
		DAQErrorID  [varchar](255) NULL,
		EventTime datetime2(0) 
       )  
	declare @DAQ618Data TABLE
      (
		ID varchar(6) null,
		BadSensorName varchar(255) null,
        measureddtm datetime2(0) 
       )  


	declare @WeekData TABLE
       (
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL,
		DAQErrorID  [varchar](255) NULL,
		BadSensorNames [varchar](255) NULL,
		EventTime datetime2(0) ,
	    measuredWeek datetime2(0) ,
		RowNumberMin int,
		RowNumberMax int
       )  

		; with a as
		(
			SELECT 'DAQ Error : ' +e.ID AS [Message]
				 , e.[description] as Detail
				 , SUBSTRING ( e.message, CHARINDEX('(',e.message) + 1 , CHARINDEX(')',e.message) - CHARINDEX('(',e.message) - 1 )   as [Value]
				 , e.ID as DAQErrorID
      	         , measureddtm
			  from fridgeErrors_view e 
			 where e.fridgeid = @fridgeid
			   and e.ID in ( '640C','4408','440D','5881','5882','5884','5885','5888','5889','5084') --,'6183','618B')
			   and e.measureddtm >= @startDate 
			   and e.measureddtm < @endDate
			   and TRIM([message]) IS NOT NULL
			   and CHARINDEX('(',    e.message ) >0

    	)

		INSERT INTO @RawData 
		SELECT *
		  FROM a

        --
		-- if there is no number in parenthesis it counts as one.
		INSERT INTO @RawData 
		SELECT 'DAQ Error : ' +e.ID AS [Message]
			 , e.[description] as Detail
			 , convert(nvarchar,1 )  as [Value]
			 , e.ID as DAQErrorID
      	     , measureddtm
		  from fridgeErrors_view e 
		 where e.fridgeid = @fridgeid
		   and e.ID = '5884'
		   and e.measureddtm >= @startDate 
		   and e.measureddtm < @endDate
		   and e.[message] = ''

		; with DAQ618_errors as
		(
			SELECT ID  
			     , SUBSTRING ( message, 1, CHARINDEX('(',message)-1 )  AS DAQSensorCode 
      	         , measureddtm
			  from fridgeErrors_view 
			 where fridgeid = @fridgeid
			   and ID like '618%'
			   and measureddtm >= @startDate 
			   and measureddtm < @endDate
			   and TRIM([message]) IS NOT NULL
			   and CHARINDEX('(',    message ) >0
        )

		-- Get all 618* codes
		INSERT INTO @DAQ618Data
		SELECT ID 
		     , CASE WHEN DAQSensorCode = '0' THEN 'TEVIN'
			        WHEN DAQSensorCode = '1' THEN 'DAQ chain'
			        WHEN DAQSensorCode = '2' THEN 'TCDOUT'
			        ELSE DAQSensorCode
			    END AS BadSensorName
		     , measureddtm
		  FROM DAQ618_errors

		--- If more than one 618* codes exists, Create a concatenated list of 618 codes
		---------------------------------------------------
        IF (Select distinct count(*) ID from @DAQ618Data ) >= 1
		BEGIN
		   SELECT @DAQ618CodeString = STRING_AGG(ID,',')
		     FROM ( SELECT DISTINCT ID
			          FROM @DAQ618Data
                  ) as t1

           SELECT @BadSensorNames =  STRING_AGG(BadSensorName,',')
		     FROM ( SELECT DISTINCT BadSensorName
			          FROM @DAQ618Data
                  ) as t1

		   SELECT @DAQ618GrafanCodeString = '&'+STRING_AGG(ID,'&')
		     FROM ( SELECT DISTINCT 'var-ERRORS='+ID AS ID
			          FROM @DAQ618Data
                  ) as t1
		END

		-- 618 Error count
		--------------------------------------
	    SELECT @DAQ618ErrorCount = ISNULL(count(*),0)
		  FROM @DAQ618Data
               

        IF @MessageInterval = 'All'
		BEGIN
		   INSERT INTO @results
		   SELECT 'All' AS [MessageInterval]
		        , [Message]
				, [Detail]
				, [value]  
				, 1 AS RecCount 
				, EventTime
			    , [Eng].[getFridgeLinkForDateRange] (@fridgeid, EventTime, DATEADD(DAY,1,EventTime), @range) AS link 
				, [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS='+DAQErrorID,EventTime, DATEADD(DAY,1,EventTime), @range) AS GLink
		     FROM @RawData
          
		  UNION ALL
		   SELECT 'All' AS [MessageInterval]
		        , ID AS [Message]
				, BadSensorName AS [Detail]
				, NULL AS [value]  
				, 1 AS RecCount 
				, measureddtm
			    , [Eng].[getFridgeLinkForDateRange] (@fridgeid, measureddtm, DATEADD(DAY,1,measureddtm), @range) AS link 
				, [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS='+ID,measureddtm, DATEADD(DAY,1,measureddtm), @range) AS GLink
		     FROM @DAQ618Data


		  

        END
  ------------------------------------------------
  -- DAQ Data is weekly for time being
  -------------------------------------------------
 
        ELSE IF @MessageInterval = 'Week'
		BEGIN
		   INSERT INTO @WeekData
		   SELECT [Message]
				, [Detail]
		        , [value]
                , DAQErrorID
				, NULL AS BadSensorNames
	            , EventTime
		        , dateadd(Week,  (datediff(Week, '20160101', EventTime)  ), '20160101') AS measuredWeek
			    , RowNumberMin = ROW_NUMBER() over (partition by  DAQErrorID order by  EventTime ASC)
			    , RowNumberMax = ROW_NUMBER() over (partition by  DAQErrorID order by  EventTime Desc)
            FROM @RawData

		   INSERT INTO @results
		   SELECT 'Week' AS [MessageInterval]
		        , t1.[Message]
				, t1.[Detail] 
				, t4.[value]  
				, t2.RowCnt
				, t1.EventTime
				, [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t3.EventTime, @range) AS link 
                , [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS='+t1.DAQErrorID, t1.EventTime, t3.EventTime, @range) AS Glink 
	       FROM ( SELECT [Message]
			           , [Detail] 
				       , [value] 
					   , DAQErrorID
		               , EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMin = 1
                ) AS t1
           JOIN ( SELECT count(*) as RowCnt
		             , DAQErrorID
		             , measuredWeek
		          FROM @WeekData
                 GROUP BY DAQErrorID,measuredWeek
		       ) AS t2
		     ON t1.measuredWeek = t2.measuredWeek
			AND t1.DAQErrorID   = t2.DAQErrorID
           JOIN ( SELECT EventTime
		             , DAQErrorID
					 , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMax = 1
              ) AS t3
		     ON t1.measuredWeek = t3.measuredWeek
		    AND t1.DAQErrorID   = t3.DAQErrorID
  /*
 To put in the value column :

5881 - max ewcp while scpx=1
5884  - % of control packets missing tvctopctl over the week (@tkreyche has a query for this in the tech report)
5084 - max, min ecdbat during the week (show "[maxvalue, minvalue]")
5882 - show the minimum EWCP while SCPX=1
5889 - show the minimum TEVIN while SCPX=1
5888 - show the maximum TCDOUT while SCPX=1

for 440D, 4408 and 640c leave blank 
  */
           JOIN (SELECT CASE WHEN  [Message] like 'DAQ%440D' THEN NULL
		          			 WHEN  [Message] like 'DAQ%4408' THEN NULL
							 WHEN  [Message] like 'DAQ%640C' THEN NULL
							 WHEN  [Message] like 'DAQ%5881' THEN ( SELECT max(EWCP2) AS ewcp 
							                                          FROM sensordata_view
                                                                     WHERE FRIDGEID = @fridgeid
																	   AND SCPX = 1
																	   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																  )
																  -- For 5882, let's try "minimum EWCP that is >1 while SCPX=1" and if there aren't any EWCP>1 during the week, 
																  -- just show the min EWCP.

							 WHEN  [Message] like 'DAQ%5882' THEN ( SELECT CASE WHEN  ( SELECT min(EWCP2) AS EWCP 
																						  FROM sensordata_view
																						 WHERE FRIDGEID = @fridgeid
																						   AND SCPX = 1 AND EWCP2 > 1
																						   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																		              ) > 1 THEN (SELECT min(EWCP2) AS EWCP  FROM sensordata_view
																						           WHERE FRIDGEID = @fridgeid
																						            AND SCPX = 1 AND EWCP2 > 1
																						            AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																						   )
                                                                                ELSE (SELECT min(EWCP2) AS EWCP 
																						  FROM sensordata_view
																						 WHERE FRIDGEID = @fridgeid
																						   AND SCPX = 1
																						   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																					 )

																	       END
											
																  )
							 WHEN  [Message] like 'DAQ%5889' THEN ( SELECT min(TEVIN) AS TEVIN
							                                          FROM sensordata_view
                                                                     WHERE FRIDGEID = @fridgeid
																	   AND SCPX = 1
																	   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																  )

							 WHEN  [Message] like 'DAQ%5888' THEN ( SELECT max(TCPDISCTL) AS TCPDISCTL
							                                          FROM sensordata_view
                                                                     WHERE FRIDGEID = @fridgeid
													    			   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																  )
							 WHEN  [Message] like 'DAQ%5084' THEN ( SELECT '['+t1.max_ecdbat+','+t1.min_ecdbat+']' as [value]
							                                          FROM
							                                         (SELECT max(ecdbat) AS max_ecdbat
							                                             , min(ecdbat) AS min_ecdbat
							                                          FROM sensordata_view
                                                                     WHERE FRIDGEID = @fridgeid
																	   AND SCPX = 1
																	   AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																       ) as t1
																  )
                              WHEN  [Message] like 'DAQ%5884' THEN (SELECT SUM(convert(int,[Value])) as [Value] 
							                                          FROM  @WeekData
																	 WHERE [Message] like 'DAQ%5884'
														          )
                     --       WHEN  [Message] like 'DAQ%5884' THEN  convert(nvarchar,(SELECT CASE WHEN SCPXCT = 0 THEN 0
			                  --                                                ELSE cast( cast(tvctopctl_ct as float) / cast(scpxCt as float) * 100.0 as numeric(8,1)) 
																		   --end as [value]
							              --                           FROM ( SELECT count(SCPX) as scpxCt
																	    --    , sum(case when TVCTOPCTL is null then 0 else 1 end) as tvctopctl_ct
							              --                                    FROM sensordata_view
                     --                                                        WHERE FRIDGEID = @fridgeid
															     	--          AND measuredDtm >= EventTime AND measuredDtm < DATEADD(Day,7,EventTime)
																     --     ) as t1
															      -- ))


		                END AS [value]
					   , DAQErrorID 
		               , measuredWeek
		            FROM @WeekData
                   WHERE RowNumberMin = 1
		        ) as t4
             ON t1.measuredWeek = t4.measuredWeek
			AND t1.DAQErrorID   = t4.DAQErrorID
           
        END		

        IF (@MessageInterval = 'Week' and @DAQ618ErrorCount >= 1)
		BEGIN
		   DELETE @WeekData

		   INSERT INTO @WeekData
		   SELECT 'DAQ sensor error' AS [Message]
		        , @DAQ618CodeString AS [Detail]
		        , NULL  AS [value]
                , @DAQ618GrafanCodeString AS DAQErrorID
				, @BadSensorNames AS BadSensorNames
	            , measureddtm AS EventTime
		        , dateadd(Week,  (datediff(Week, '20160101', measureddtm)  ), '20160101') AS measuredWeek
			    , RowNumberMin = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', measureddtm)  ), '20160101') order by  measureddtm Asc)
			    , RowNumberMax = ROW_NUMBER() over (partition by  dateadd(Week,  (datediff(Week, '20160101', measureddtm)  ), '20160101') order by  measureddtm Desc)
            FROM @DAQ618Data

		   INSERT INTO @results
		   SELECT 'Week' AS [MessageInterval]
		        , t1.[Message]
				, t1.[Detail] 
				, @BadSensorNames  AS [value]  
				, @DAQ618ErrorCount AS RowCnt
				, t1.EventTime
				, [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t3.EventTime, @range) AS link 
                , [Eng].[getDAQErrorGrafanaLink] (@fridgeid, t1.DAQErrorID, t1.EventTime, t3.EventTime, @range) AS GLink 
	       FROM ( SELECT [Message]
			           , [Detail] 
				       , [value] 
					   , DAQErrorID
		               , EventTime
					   , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMin = 1
                ) AS t1
           JOIN ( SELECT EventTime
		             , DAQErrorID
					 , measuredWeek
		          FROM @WeekData
                 WHERE RowNumberMax = 1
              ) AS t3
		     ON t1.measuredWeek = t3.measuredWeek
		    AND t1.DAQErrorID   = t3.DAQErrorID

         END		

 	return 
end
