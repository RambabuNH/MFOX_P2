



/*


truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-4-12', '2020-4-19'


truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-2-23', '2020-3-1'


truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-2-16', '2020-2-23'

truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-2-2', '2020-2-9'


truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-1-26', '2020-2-2'

truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-1-19', '2020-1-26'

truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2020-1-12', '2020-1-19'

-----------------

truncate table Report_WeeklyTech_v5
exec wky.populateWeeklyReportTech_v5 '2019-9-15', '2019-9-22'

------------------------------------
select * from Report_WeeklyTech_v5
where message = 'Missing Data'

select * from Report_WeeklyTech_v5 order by fridgeshortsn
--order by 1
order by fridgeid
*/




CREATE PROCEDURE [wky].[populateWeeklyReportTech_v5] 
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

	declare @range int = 14400 * 2

	declare @days int = datediff(day,@startDate, @endDate)

	create table #fridge(fridgeid bigint, fridgeType char(1))

	CREATE TABLE #results
	(
		[Priority] varchar(255) null,
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
			--and fridgeid = 2882377905688543293
		)

		insert into #fridge
		select fridgeid, fridgeType from a where rn = 1

	----------------------------------------------------------------------------------------------------------------------
	-- data rx, flag units with low data rx% in tech report, issue #181
	-- based on 10 minute intervals to handle low power state
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getDataRx](f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing Ice Sensors and CTBH
	-- Both Missing Ice Sensors
	-- Missing Ice, Control Sensors and CTBH
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getMissingIceSensors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- bad mains power
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadMainsPower] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- bad solar/hybrid power
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadSolarPower] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- possibly dirty solar panels
	-- uses simple EWDCA threshold
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDirtySolarPanels] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- solar power totally disconnected
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getZeroSolarPower] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- Bad or missing battery
	-- Look for 1 hour periods where evdbat < .2
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getBattMissing](f.fridgeid,@startDate,@endDate) x

	----------------------------------------------------------------------------------------------------------------------
	-- Fast Battery Drain
	-- Get battery drain over 24 hour period, finds worst case of the week. 
	-- More consistent results than just getting first case, and also eliminates null cases
	-- look in 24 to 25 hour window
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getBattDrain](f.fridgeid,@startDate,@endDate) x

	----------------------------------------------------------------------------------------------------------------------
	-- DAQ Sensor Errors, 	ID in ('A186','A187','6782','6784','A1D5','A188')
	-- now only: when e.id = '6782' or e.id = '6784' then 'SD Card Error'
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDAQSensorErrors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- more DAQ Hi Temp Errors
	-- number of days with high temp alarms
	-- flag units with high temp alarms during the week #249
	-- only implemented Part 1 for now
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDAQHiTempErrors] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Bad Generator Frequency Errors - checks frequency when voltage in range
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getBadFrequencyErrors]  (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Refrigerant Leak (only for mains devices)
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getRefrigerantLeak]  (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- flag for solar fridge never hitting satisfied that week #242
	-- flag if SCPX reaches 6 but never reaches 2: control cycling, undersatisfied
	-- flag if SCPX never equals 2 or 6 during the week - not enough ice
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getSolarUnsatisfied] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'S'

	----------------------------------------------------------------------------------------------------------------------
	-- Mech Thermostat engaged, does not apply to solar fridges
	-- closed when temperature is 2 deg +- 1.5,  opens when temp drops to -1.5 +- 1.5
	-- breaks the ac power connection to compressor, thermostat tends to stick, events may be disassociated
	----------------------------------------------------------------------------------------------------------------------
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMechThermTripped] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- Low temperatures, flag units with TVCTOPCTL or TVCBOT < 2C during the week
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getLowTemps] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Long door openings based on 5404 status message
	-- function seems excessively complicated but does the job
	-- current threshold is 12 hours
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getLongDoorOpen] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing EVLN, power board dropout, Mains fridges only
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingEvln] (f.fridgeid,@startDate,@endDate) 
	where f.fridgeType = 'M'

	----------------------------------------------------------------------------------------------------------------------
	-- Missing TAMDAQ, usb board dropout
	----------------------------------------------------------------------------------------------------------------------	
	-- combined now with ice and control sensors
	/*
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingTamdaq] (f.fridgeid,@startDate,@endDate) 
	*/
	----------------------------------------------------------------------------------------------------------------------
	-- Missing SCPX
	----------------------------------------------------------------------------------------------------------------------	
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingSCPX] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Missing CTBH
	-- commented out 2/10/2020, duplicated in getMissingIceSensors
	----------------------------------------------------------------------------------------------------------------------	
	--insert into #results
	--SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	--FROM #fridge f 
	--CROSS APPLY [wky].[getMissingCTBH] (f.fridgeid,@startDate,@endDate) 

	----------------------------------------------------------------------------------------------------------------------
	-- Find duplicate fridgeids, any days where max number of records is exceeded, should be rare 
	-- to be included elsewhere
	----------------------------------------------------------------------------------------------------------------------

	/*
	insert into #results
	SELECT [Priority], f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getDupFridgeid] (f.fridgeid,@startDate,@endDate) 
	*/

	----------------------------------------------------------------------------------------------------------------------	
	-- remove unnecessary messages when device is offline
	----------------------------------------------------------------------------------------------------------------------	

	update #results
	set [Message] = 'Unit Offline', Detail = null, [value] = null
	where [Message] = 'Missing Data' and value = 0 

	delete #results
	where fridgeid in (select distinct fridgeid from #results where [Message] = 'Unit Offline')
	and [Message] != 'Unit Offline'

	----------------------------------------------------------------------------------------------------------------------	
	-- remove extra power messages when no power data is available
	----------------------------------------------------------------------------------------------------------------------	

	delete #results
	where fridgeid in (select distinct fridgeid from #results where [Message] = 'Missing Power Board Data' and [value] < 1)
	and [Message] = 'Low Mains Power Availability' or [Message] = 'Line Frequency Abnormal'

	delete #results
	where fridgeid in (select distinct fridgeid from #results where [Message] = 'Low Mains Power Availability' and [value] < 1)
	and [Message] = 'Line Frequency Abnormal'

	----------------------------------------------------------------------------------------------------------------------	
	-- remove extra solar power messages when disconnected
	----------------------------------------------------------------------------------------------------------------------	

	delete #results
	where fridgeid in (select distinct fridgeid from #results where [Message] = 'Solar Power Disconnected')
	and [Message] = 'Low Solar Power'

	----------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------
	-- Fixed Columns calculations, not errors
	----------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------

		insert into Report_WeeklyTech_v5
			select 
			r.[Priority],
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
					when avg(s.tvcbot) is null then cast(avg(s.TVCTOPCTL) as numeric(8,1))
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
				(select isnull(sum(case when slnx = 1 or (slnx is null and evln > 82 and evln < 290) or EWDCA > 30 then 1 else 0 end),0)
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

			/*
			(
				cast(
				(select count(measureddtm) from sensordata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate)
				/ (8640.0 * @days) * 100.0 as numeric(6,1))
			) as DataRx,
			*/

			(
				select datarx from [wky].[getDataRxValue] (r.fridgeid, @startDate, @endDate)
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
				--https://mfoxmf2.azurewebsites.net/FridgeComment/IndexSolarFlag?fridgeid=2887946103137763440&start=1580966950&stop=1581183738
					CASE 
					WHEN (select top 1 1 from GroupFridge g where g.FridgeID = f.FridgeId and GroupName = 'solar') = 1
					
					THEN 
					
						'https://mfoxmf2.azurewebsites.net/FridgeComment/indexSolarFlag?fridgeid=' +
						cast(f.fridgeid as varchar(64)) + 
						'&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @startDate) - (@range) as varchar) +
						'&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @endDate) + (@range) as varchar) 				

					ELSE 
						'https://mfoxmf2.azurewebsites.net/FridgeComment/indexFlag?fridgeid=' +
						cast(f.fridgeid as varchar(64)) + 
						'&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @startDate) - (@range) as varchar) +
						'&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @endDate) + (@range) as varchar) 

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

	update Report_WeeklyTech_v5
	set CTBH = Null, SLNX = Null
	where [message] = 'Unit Offline'


END




