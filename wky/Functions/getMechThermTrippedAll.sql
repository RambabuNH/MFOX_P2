

/*

	drop table if exists #fridge

	select l.fridgeid
	into #fridge
	from latestFridgeLocation3_view l
	where l.Country = 'Nigeria' 
	and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
	--and fridgeid in (2919283236796367032, 2910809566969069806)

	SELECT *
	FROM #fridge f
	CROSS APPLY [wky].[getMechThermTrippedAll](f.fridgeid, '2020-4-19', '2040-4-26') u
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
	CROSS APPLY [wky].[getMechThermTrippedAll](f.fridgeid, '2019-11-1', '2019-11-18') u
	order by 1,2

	-- test cases

	-- will trip with either algorithm, should return three results
	select * from [wky].[getMechThermTrippedAll] (2910809566969069806, '2019-11-5 3:30', '2019-11-5 6:00') 
	2019-11-05 03:43:32
	2019-11-05 05:08:21
	2019-11-05 03:51:13

	-- only trips with first
	select * from [wky].[getMechThermTrippedAll] (2919283236796367032, '2019-11-4 17:00', '2019-11-4 17:30') 

	-- only trips with second
	select * from [wky].[getMechThermTrippedAll] (2935511813690753220, '2020-2-8 13:00', '2020-2-9 13:30') 

	select * from [wky].[getMechThermTrippedAll] (2907236149883830276, '2019-12-28 14:30', '2019-12-28 15:00') 

	select * from [wky].[getMechThermTrippedAll] (2909254591239422000, '2020-4-28','2020-4-29')

*/



CREATE FUNCTION [wky].[getMechThermTrippedAll] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		dtm datetime2(0)
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

	-- SCPX compressor running = 1, off = 0, look for transitions from running to off
	;with a as
	(
		select
		measureddtm as dtm,
		scpx as s1,
		lead(scpx) over (order by measureddtm) as s2
		from sensordata_view v 
		where v.FRIDGEID = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
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

	insert into @results
	select dtm from c where avgEWCP < 1

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

	insert into @results
	select dtm from c where avgEWCP < 1

	return 

end
