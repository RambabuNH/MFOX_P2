


/*

select * from Report_WeeklyTech_v4 
--where message = 'Solar Power'
--where message = 'Line Freqency Abnormal'
order by country, l1, l3

truncate table Report_WeeklyTech_v4
exec wky.populateWeeklyReportTech_v4 '2019-12-29', '2020-1-4'

truncate table Report_WeeklyTech_v4
exec wky.populateWeeklyReportTech_v4 '2020-1-12', '2020-1-19'

truncate table Report_WeeklyTech_v4
exec wky.populateWeeklyReportTech_v4 '2020-1-19', '2020-1-26'



*/



CREATE PROCEDURE [wky].[populateWeeklyReportTech_v4] 
(
	@startDate date,
	@endDate date
)

AS
BEGIN

    SET NOCOUNT ON


	----------------------------------------------------------------------------------------------------------------------
	-- temporary fridge and results table
	---------------------------------------------------------------------------------------------------------------------

	declare @days int = datediff(day,@startDate, @endDate)

	create table #fridge(fridgeid bigint, fridgeType char(1))

	CREATE TABLE #results
	(
		[fridgeid] [bigint] NOT NULL,
		[Message] [varchar](255) NULL,
		[Detail] [varchar](255)  NULL,
		[value] [float] NULL,
		errCnt int null
	) 

	----------------------------------------------------------------------------------------------------------------------
	-- get fridges
	-- for now, Jenny has spec'd all fridges except those in china
	-- nigeria fridges are good test case due to number of problems
	-- filter out freezers, duplicates due to moved fridges
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select 
			ROW_NUMBER() over (partition by fridgeid order by fridgeid) as rn,
			l.fridgeid, 
			case when l.FridgeID in (select fridgeid from GroupFridge where GroupName = 'solar') then 'S' else 'M' end as fridgeType
			from fridgelocation2 l
			--where l.Country = 'Nigeria' 
			where l.Country != 'China'
			and fridgeid not in (select fridgeid from GroupFridge where GroupName = 'freezer')
			--and fridgeid = 2947297169608016007
		)

		insert into #fridge
		select fridgeid, fridgeType from a where rn = 1




	----------------------------------------------------------------------------------------------------------------------
	-- data rx, flag units with low data rx% in tech report, issue #181
	-- based on 10 minute intervals to handle low power state
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getDataRx](f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing Ice Sensors and CTBH
	-- Both Missing Ice Sensors
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getMissingIceSensors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- bad mains power
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadMainsPower] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- bad solar/hybrid power
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadSolarPower] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- Bad or missing battery
	-- Look for 1 hour periods where evdbat < .2
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getBattMissing](f.fridgeid,@startDate,@endDate) x

	----------------------------------------------------------------------------------------------------------------------
	-- Fast Battery Drain
	-- Get battery drain over 24 hour period, finds worst case of the week. 
	-- More consistent results than just getting first case, and also eliminates null cases
	-- look in 24 to 25 hour window
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getBattDrain](f.fridgeid,@startDate,@endDate) x

	----------------------------------------------------------------------------------------------------------------------
	-- DAQ Sensor Errors, 	ID in ('A186','A187','6782','6784','A1D5','A188')
	-- now only: when e.id = '6782' or e.id = '6784' then 'SD Card Error'
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDAQSensorErrors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- more DAQ Hi Temp Errors
	-- number of days with high temp alarms
	-- flag units with high temp alarms during the week #249
	-- only implemented Part 1 for now
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDAQHiTempErrors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Bad Generator Frequency Errors - checks frequency when voltage in range
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadFrequencyErrors]  (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Refrigerant Leak (only for mains devices)
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getRefrigerantLeak]  (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- flag for solar fridge never hitting satisfied that week #242
	-- flag if SCPX reaches 6 but never reaches 2: control cycling, undersatisfied
	-- flag if SCPX never equals 2 or 6 during the week - not enough ice
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getSolarUnsatisfied] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- Mech Thermostat engaged, does not apply to solar fridges
	-- closed when temperature is 2 deg +- 1.5,  opens when temp drops to -1.5 +- 1.5
	-- breaks the ac power connection to compressor, thermostat tends to stick, events may be disassociated
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMechThermTripped] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- Low temperatures, flag units with TVCTOPCTL or TVCBOT < 2C during the week
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getLowTemps] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Long door openings based on 5404 status message
	-- function seems excessively complicated but does the job
	-- current threshold is 12 hours
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getLongDoorOpen] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing EVLN, power board dropout, Mains fridges only
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingEvln] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- Missing TAMDAQ, usb board dropout
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingTamdaq] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing SCPX
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingSCPX] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Find duplicate fridgeids, any days where max number of records is exceeded, should be rare 
	----------------------------------------------------------------------------------------------------------------------

	insert into #results
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDupFridgeid] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------	
	-- need to remove unnecessary messages when device is offline
	----------------------------------------------------------------------------------------------------------------------	

	declare @dFridge table (fridgeid bigint)

	update #results
	set [Message] = 'Unit Offline', Detail = null, [value] = null
	where [Message] = 'Missing Data' and value = 0

	insert into @dFridge
	select distinct fridgeid  from #results where [Message] = 'Unit Offline'	

	delete #results
	where fridgeid in (select fridgeid from @dFridge)
	and [Message] != 'Unit Offline'

	-- remove extra power messages when no power data is available
	-- zero seems to pick up a few fridges with small numbers, try < 1

	delete from @dFridge
	insert into @dFridge
	select distinct fridgeid from #results where [Message] = 'Missing Power Board Data' and [value] < 1

	delete #results
	where fridgeid in (select fridgeid from @dFridge)
	and [Message] != 'Low Mains Power Availability'
	

	----------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------
	-- Fixed Columns calculations, not errors
	----------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------

		insert into Report_WeeklyTech_v4
			select 
			d.Country, d.L1, d.L3,
			@startDate as StartDate,
			@endDate as EndDate,
			(datediff(day,@startDate,@endDate)) as ReportDays,
			f.FridgeId,
			upper(f.FridgeShortSN) as FridgeShortSN,
			case when (select top 1 1 from GroupFridge g where g.FridgeID = f.FridgeId and GroupName = 'solar') = 1 then 'S' else 'M' end,
			case when d.report = 1 then 'Y' else null end,
			d.commDte,
			r.Message,
			r.Detail,
			r.value,

			(
				select
				case  
					when avg(s.TVCTOPCTL) is null and avg(s.tvcbot) is null then null
					when avg(s.TVCTOPCTL) is null then cast(avg(s.tvcbot) as numeric(8,1))
					else cast( ((avg(s.tvctopctl) + avg(s.tvcbot)) / 2.0  ) as numeric(8,1))
				end
				from sensordata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate 

			) as TVCTOPCTLavg, 


			(
				cast(
				(select 	isnull(avg(ctbh),0) from sensordata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate )
				as numeric(6,1))
			) as CTBH,


			-- modified 1/21/2019
			(
				cast(
				(select isnull(sum(case when slnx = 1 or (slnx is null and evln > 90 and evln < 290) or EWDCA > 30 then 1 else 0 end),0)
				from sensorsolardata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate)
				/ (8640.0 * @days) * 100.0 as numeric(6,1))

			) as SLNX,

			/*
			(
				cast(
				(select isnull(sum(cast(slnx as int)),0)  from sensordata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate)
				/ (8640.0 * @days) * 100.0 as numeric(6,1))
			) as SLNX,
			*/

			(
				cast(
				(select count(measureddtm) from sensordata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate)
				/ (8640.0 * @days) * 100.0 as numeric(6,1))
			) as DataRx,

			(
				select runAgeMin from dbo.getLastCompRunFridge(r.fridgeid, @startDate, @endDate)
			) as CompRunAgeMin,

			(
				select 	dbo.getDH( runAgeMin * 60 )
				from dbo.getLastCompRunFridge(r.fridgeid, @startDate, @endDate)
			) as CompRunAge,


			(
				select dbo.getdatediffdh2( max(measureddtm), @endDate) from sensordata_view where fridgeid = r.fridgeid and measuredDtm < @endDate
			) as DataAge,

			(
					CASE 
					WHEN (select top 1 1 from GroupFridge g where g.FridgeID = f.FridgeId and GroupName = 'solar') = 1
					THEN 'https://mfoxmf2.azurewebsites.net/FridgeComment/indexSolarFlag?fridgeid=' + Cast(f.FridgeId AS VARCHAR(64))
					ELSE 'https://mfoxmf2.azurewebsites.net/FridgeComment/indexFlag?fridgeid=' + Cast(f.FRIDGEID AS VARCHAR(64))
					end
			) as link


			from #results r
			left join fridge f on r.fridgeid = f.FridgeId
			left join
			(
				select * from 
				(select ROW_NUMBER() over (partition by fridgeid order by createddtm desc) as rn, 
				fridgeid, 
				country, 
				L1,
				L3, 
				commDte,
				report
				from fridgelocation2)x 
				where rn = 1
			) d
			on r.fridgeid = d.FridgeID


	----------------------------------------------------------------------------------------------------------------------	
	-- need to remove unnecessary values when device is offline
	----------------------------------------------------------------------------------------------------------------------	

	update Report_WeeklyTech_v4
	set CTBH = Null, SLNX = Null
	where [message] = 'Unit Offline'


END



