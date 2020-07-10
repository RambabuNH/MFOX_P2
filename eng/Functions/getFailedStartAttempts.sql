/*
-- https://github.com/new-horizons/mf-mfox/issues/221
get total count of events over the week, with link to the first occurrence.
for a first pass at this let's just add any occurrences of D0A0 to the engineering report

The mains power board looks at the PCOMP signal from the CTL processor, since the power board 
doesn't directly control turn on/off events. If PCOMP was high for 89 seconds or less, 
it calls it a failed start, and sends status code D0A0.


select * from [Eng].[getFailedStartAttempts](2927167315021660373,'2020-05-29','2020-05-30','All') 
 
select * from [Eng].[getFailedStartAttempts](2905840083682722037,'2020-05-29','2020-05-30','Day') 

select * from [Eng].[getFailedStartAttempts](2914027571215597778,'2020-05-24','2020-05-31','Week') 

*/



CREATE FUNCTION [eng].[getFailedStartAttempts] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5) )  

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
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		EventTime datetime2(0) 
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

   ;with FailedStartAttempts_CTE as
	   (SELECT measuredDtm
	      from [dbo].[fridgeErrors_view_d]
         where fridgeid    =  @fridgeid
		   and id          = 'E0A1' -- let's try using E0A1 instead of D0A0, that's much more selective (requires a few D0A0 within some time period but already calculated on the power board so let's use it.
	       and measuredDtm >= @startDate
	       and measuredDtm <  @endDate 
       )
   
   INSERT INTO @RawData
   SELECT 'too many failed starts' AS [Message]
        , 'measuredDtm of the first PCOMP signal''s failed start attempt' AS Detail
		, measuredDtm AS EventTime
     FROM FailedStartAttempts_CTE
 

    IF @MessageInterval = 'All'
	BEGIN
	   INSERT INTO @results
	   SELECT 'All' AS [MessageInterval]
	        , [Message]
			, [Detail] 
			, NULL AS [value]  
			, 1 AS RecCount 
			, EventTime
		    , [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS=E0A1',EventTime, DATEADD(Day,1,EventTime), @range) AS link
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
	        , 'too many failed starts' AS [Message]
            , 'measuredDtm of the first PCOMP signal''s failed start attempt' AS Detail
			, NULL AS [value] 
			, t3.RowCnt  
			, t1.EventTime
     --       , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
		    , [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS=E0A1',t1.EventTime, t2.EventTime, @range) AS link
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
	        , 'too many failed starts' AS [Message]
            , 'measuredDtm of the first PCOMP signal''s failed start attempt' AS Detail
			, NULL AS [value] 
			, t3.RowCnt  
			, t1.EventTime
   --         , [Eng].[getFridgeLinkForDateRange] (@fridgeid, t1.EventTime, t2.EventTime, @range) AS link 
		    , [Eng].[getDAQErrorGrafanaLink] (@fridgeid, '&var-ERRORS=E0A1',t1.EventTime, t2.EventTime, @range) AS link

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
		      ) AS t3
		    ON t1.measuredWeek = t3.measuredWeek
    END


   return 

END


 
