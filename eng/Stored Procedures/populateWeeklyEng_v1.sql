/*
-- 05/05/2020-- https://github.com/new-horizons/mf-mfox/issues/313
-- engineering report flag if TAMDAQ is <10 or >40C

-- 05/09/2020 -- https://github.com/new-horizons/mf-mfox/issues/312 Add high compressor power to engineering report
-- 05/18/2020 -- https://github.com/new-horizons/mf-mfox/issues/274 Add a query for no door openings over the week

delete from [Eng].Report_WeeklyEng_v1
exec [Eng].populateWeeklyEng_v1 '2020-4-21', '2020-4-28', 'Nigeria'

select * from [Eng].Report_WeeklyEng_v1 with (nolock) order by Message
delete from [Eng].Report_WeeklyEng_v1 where country = 'Nigeria'

-- Populate data for Kenya and Nigeria for the week of 5/10 of 5/1
exec [Eng].populateWeeklyEng_v1 '2020-05-10', '2020-05-17', 'Nigeria','Day'

exec [Eng].populateWeeklyEng_v1 '2020-05-17', '2020-05-24'  -- All countries with default Aggregation

select * from [Eng].Report_WeeklyEng_v1 with (nolock) order by Message

select * from [Eng].Report_WeeklyEng_v1 with (nolock) 
 where MessageInterval = 'Week'

select * from [Eng].Report_WeeklyEng_v1 with (nolock) 
 where MessageInterval = 'Day'

*/

CREATE PROCEDURE [eng].[populateWeeklyEng_v1] 
(
	@startDate date,
	@endDate   date,
	@Country   VARCHAR(64) = 'All',
    @MessageInterval VARCHAR(64) = 'Day' --Data Aggregation by Hour/Day/Week or 'All' to see all records
	                                     --Currently defaulting to 'Day' except for some event data by Week or Day. Refer to the calling TVFs below.
)

AS
BEGIN

    SET NOCOUNT ON;
    BEGIN TRY	
	----------------------------------------------------------------------------------------------------------------------
	-- temporary fridge and results table
	---------------------------------------------------------------------------------------------------------------------
	SET @Country = Trim(@Country)
	declare @days int = datediff(day,@startDate, @endDate)

	create table #fridge( fridgeid bigint
	                    , FridgeShortSN varchar(33)
	                    , fridgeType char(1)
						)

    select * 
	  into #fridgeLocation
	  from ( select ROW_NUMBER() over (partition by fridgeid order by createddtm desc) as rn,
	                createddtm,
				    fridgeid, 
				    country, 
				    L1,
				    L3, 
				    commDte,
				    report
				from fridgelocation2 
			   where Country != 'China'
			     and fridgeid not in (select fridgeid from GroupFridge where GroupName = 'freezer')
				)x 
	  where rn = 1
		 
			 

	CREATE TABLE #results
	(
		[fridgeid] [bigint] NOT NULL,
	    [MessageInterval]  [VARCHAR] (5) NULL,
		[Message] [varchar](255) NULL,
		[Detail]  [varchar](255)  NULL,
		[value]   [varchar](255)  NULL, 
		RecCount  int Null,
		EventTime datetime2(0),
		link      [varchar](2048) null, -- MFOX Link
	    Glink     [varchar](2048) null  -- Grafana Link
	) 

    IF @Country = 'All'
	BEGIN
	   INSERT INTO #fridge (fridgeid,FridgeShortSN,fridgeType)
	   SELECT l.fridgeid
	        , l.FridgeShortSN
		    , case when l.FridgeID in (select fridgeid from GroupFridge where GroupName = 'solar') then 'S' else 'M' 
			  end as fridgeType
  		 from dbo.latestFridgeLocation2_view l
		where l.Country != 'China'
	      and l.fridgeid not in (select fridgeid from GroupFridge where GroupName = 'freezer')
     END
	
    IF @Country <> 'All'
	BEGIN
	   INSERT INTO #fridge (fridgeid,FridgeShortSN,fridgeType)
	   SELECT l.fridgeid
	        , l.FridgeShortSN
		    , case when l.FridgeID in (select fridgeid from GroupFridge where GroupName = 'solar') then 'S' else 'M' 
			  end as fridgeType
		 from dbo.latestFridgeLocation2_view l
	    where l.Country = @Country
	      and fridgeid not in (select fridgeid from GroupFridge where GroupName = 'freezer')
    END

	-----------------------------------------------------------------------------------------
	--Issue 274 add a query for no door openings over the week  Issue #274
	-----------------------------------------------------------------------------------------
	INSERT INTO #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	  FROM #fridge f
	 CROSS APPLY [Eng].[getNoDoorOpenings](f.fridgeid,@startDate,@endDate,'Week') 

	----------------------------------------------------------------------------------------------------------------------
	--Issue 317 DAQ Errors ( '640C','4408','440D','5881','5882','5884','5885','5888','5889','5084' plus DAQ Sensor errors 618* )
	------------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,Glink
	FROM #fridge f
	CROSS APPLY [Eng].[getDAQErrors](f.fridgeid,@startDate,@endDate,'Week') 

	--------------------------------------------------------------
	-- Issue 318 Mechanical thermostat events
	-- thermostat trips when compressor is running
	-- thermostat trips before compressor is supposed to start but doesn't
	--------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getMechThermTrippedAll](f.fridgeid,@startDate,@endDate,'Week') 

   --------------------------------------------------------------------------------------------------------------------
   --Issue 320 05/15/2020  -- query for overlapping data/FridgeID
   --------------------------------------------------------------------------------------------------------------------	
 	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getOverlappingData](f.fridgeid,@startDate,@endDate,'Hour')

	
	-----------------------------------------------------
	-- Populate Aggregation by Day
	----------------------------------------------------


	-------------------------------------------------------------------------------------------
	-- Issue 292 high voltage events 
	-------------------------------------------------------------------------------------------
	INSERT INTO #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	  FROM #fridge f
	 CROSS APPLY [Eng].[getHighVoltageEvents](f.fridgeid,@startDate,@endDate,@MessageInterval) 



	----------------------------------------------------------------------------------------------------------------------
	-- Issue 311 Low temperatures, flag units with TVCTOPCTL or TVCBOT < 2C  
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getLowTemperatures](f.fridgeid,@startDate,@endDate,@MessageInterval) 


    ----------------------------------------------------------------------------------------------------------------------
	----Issue 313 05/05/2020  engineering report flag if TAMDAQ is <10 or >40C
	------------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getTAMDAQHighLowTemps](f.fridgeid,@startDate,@endDate,'Week') 

   --------------------------------------------------------------------------------------------------------------------
   --Issue 312  05/09/2020  add high compressor power to engineering report
   --------------------------------------------------------------------------------------------------------------------	
   --let's keep this as daily aggregation for now. may switch to weekly after I see how the full report goes.
	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getHighCompressorPower](f.fridgeid,@startDate,@endDate,@MessageInterval)

	-- Still pending
    --------------------------------------------------------------------------------------------------------------------
   --Issue 322  add query for sdx and sdxc don't match
   --------------------------------------------------------------------------------------------------------------------	
    --------------------------------------------------------------------------------------------------------------------
   --Issue 179  add to 7 day report query for fridges where ECDBAT is different than it should be
   --------------------------------------------------------------------------------------------------------------------	
 
   --------------------------------------------------------------------------------------------------------------------
   --Issue 221  new query for failed start attempts
   --------------------------------------------------------------------------------------------------------------------	
   	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [Eng].[getFailedStartAttempts](f.fridgeid,@startDate,@endDate,'Week')

   --------------------------------------------------------------------------------------------------------------------
   --Issue 222  change low compressor power query
   --------------------------------------------------------------------------------------------------------------------	
   	insert into #results
	SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	FROM #fridge f
	CROSS APPLY [eng].[getlowCompressorPower](f.fridgeid,@startDate,@endDate,@MessageInterval)

/*
	--6/9/2020  Excluding from the report. refer to Github Issue 280
 --  --------------------------------------------------------------------------------------------------------------------
 --  --Issue 280  Help Field Techs Troubleshoot Bad Time and Using Incorrect FridgeID
 --  --------------------------------------------------------------------------------------------------------------------	
 --  	insert into #results
	--SELECT f.fridgeid, [MessageInterval],[Message],[Detail],[value],RecCount, EventTime,link ,NULL
	--FROM #fridge f
	--CROSS APPLY [Eng].[getBadDate](f.fridgeid,@startDate,@endDate,@MessageInterval)
*/

	------------------------------------------------------------------------
	-- Finally Populate the Engineering report table [Eng].Report_WeeklyEng_v1
	------------------------------------------------------------------------
	insert into [Eng].Report_WeeklyEng_v1
	     ( CreatedDtm
         , Country
         , L1
         , L3
         , StartDate
         , EndDate
         , ReportDays
         , FridgeId
         , FridgeShortSN
         , FridgeType
         , [Message]
         , Detail
         , [value]
         , EventTime
         , RecCount
         , Link
		 , GLink
         , MessageInterval
         )
   SELECT  t1.CreatedDtm
         , t1.Country
         , t1.L1
         , t1.L3
         , t1.StartDate
         , t1.EndDate
         , t1.ReportDays
         , t1.FridgeId
         , t1.FridgeShortSN
         , t1.FridgeType
         , t1.[Message]
         , t1.Detail
         , t1.[value]
         , t1.EventTime
         , t1.RecCount
         , t1.Link
		 , t1.GLink
         , t1.MessageInterval
     FROM
	 (
		select GETUTCDATE() AS CreatedDtm -- datetime stamp for when the query was run. So we can look back and know this.
			 , d.Country
			 , d.L1
			 , d.L3
			 , @startDate as StartDate
			 , @endDate as EndDate
			 , @days as ReportDays
			 , f.FridgeId
			 , upper(f.FridgeShortSN) as FridgeShortSN
			 , f.fridgeType
			 , r.[Message]
			 , r.Detail
			 , r.[value]
			 , r.EventTime
			 , r.RecCount
			 , r.Link
			 , r.GLink
			 , r.MessageInterval
		  from #results r
		  join #fridge f
			ON r.fridgeid = f.FridgeId 
		  left join #fridgeLocation as d
			  on r.fridgeid = d.FridgeID
    ) AS t1
	LEFT JOIN [Eng].Report_WeeklyEng_v1 as t2
	       ON t1.fridgeid  = t2.FridgeId
		  AND t1.EventTime = t2.EventTime
		  AND t1.RecCount  = t2.RecCount
   WHERE t2.fridgeid is null

    END TRY

    BEGIN CATCH
        DECLARE @error int
		      , @message varchar(4000);
        SELECT @error = ERROR_NUMBER()
		     , @message = ERROR_MESSAGE()
      
        RAISERROR ('[Eng].[populateWeeklyEng_v1]: %d: %s', 16, 1, @error, @message) ;
        RETURN;
    END CATCH 

END
 




