

/*

		drop table if exists #fridge

		select l.fridgeid
		into #fridge
		from fridgelocation2 l
		where l.Country = 'Nigeria' 
		and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
		and fridgeid in (2919283236796367032, 2910809566969069806)

	SELECT f.fridgeid, u.Message, u.Detail, u.value, u.errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getMechThermTripped] (f.fridgeid, '2019-11-1', '2019-11-18') u


	---------------
	
	https://mfoxmf2.azurewebsites.net/FridgeComment/IndexFlag?fridgeid=2931321265656430834&start=1587563872&stop=1587591210
	https://mfoxmf2.azurewebsites.net/FridgeComment/IndexFlag?fridgeid=2912153483744378930&start=1587921843&stop=1587924243

			select * from [wky].[getMechThermTripped] (2912153483744378930, '2020-4-25', '2020-4-27') 
			select * from [wky].[getMechThermTripped] (2931321265656430834, '2020-4-21', '2020-4-24') 


		-- will trip with either algorithm
		select * from [wky].[getMechThermTripped] (2910809566969069806, '2019-11-5 3:00', '2019-11-5 6:00') 

		-- only trips with first
		select * from [wky].[getMechThermTripped] (2919283236796367032, '2019-11-4 17:00', '2019-11-4 17:30') 

		-- only trips with second
		select * from [wky].[getMechThermTripped] (2935511813690753220, '2020-2-8 13:00', '2020-2-9 13:30') 



		select * from [wky].[getMechThermTripped] (2907236149883830276, '2019-12-28 14:30', '2019-12-28 15:00') 

*/



CREATE FUNCTION [wky].[getMechThermTripped] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		[Priority] varchar(255) null,
		[Message] [varchar](255) NULL,
		[Detail] [varchar](255)  NULL,
		[value] numeric(8,1) NULL,
		errCnt int null
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


	declare @ct1 int = 0
	declare @ct2 int = 0

	-- handles case where thermostat trips when compressor is running

	;with a as
	(
		select
		scpx as s1,
		lead(measureddtm) over (order by measureddtm) as t2,
		lead(scpx) over (order by measureddtm) as s2
		from sensordata_view v 
		where v.FRIDGEID = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
	)
	
	,b as
	(
		SELECT 
		DATEADD(second,-30,t2) as sp -- need a minute or two before shutdown to eliminate artificially low readings
		FROM a
		where (s1 = 1 and s2 != 1) 
	)

	,c as
	(
		select 
		b.sp,
		count(*) as ct,
		avg(EWCP2) as avgEWCP
		from b
		inner join sensordata_view s 
		on s.FRIDGEID = @fridgeid and measuredDtm > dateadd(SECOND,-60,b.sp) and measuredDtm < b.sp and scpx = 1 and ewcp2 != 0 
		group by b.sp
	)


	 select @ct1 = count(*) from c where avgEWCP < 1 and ct > 1


	-- handles case where thermostat trips before compressor is supposed to start but doesn't

	;with a as
	(
		select
		scpx as s1,
		lead(measureddtm) over (order by measureddtm) as t2,
		lead(scpx) over (order by measureddtm) as s2
		from sensordata_view v 
		where v.FRIDGEID = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
	)
	
	,b as
	(
		SELECT 
		DATEADD(second,30,t2) as sp -- add a couple minutes after startup
		--DATEADD(minute,1,t2) as sp -- add a couple minutes after startup
		--DATEADD(SECOND,30,t2) as sp -- add a couple minutes after startup
		FROM a
		where (s1 != 1 and s2 = 1) 
	)

	,c as
	(
		select 
		b.sp,
		count(*) as ct,
		avg(EWCP2) as avgEWCP
		from b
		inner join sensordata_view s 
		on s.FRIDGEID = @fridgeid and measuredDtm < dateadd(second,60,b.sp) and measuredDtm > b.sp and scpx = 1 and ewcp2 != 0 
		--on s.FRIDGEID = @fridgeid and measuredDtm < dateadd(minute,5,b.sp) and measuredDtm > b.sp and scpx = 1 and ewcp2 != 0 
		--on s.FRIDGEID = @fridgeid and measuredDtm < dateadd(minute,1,b.sp) and measuredDtm > b.sp and scpx = 1 and ewcp2 != 0 
		group by b.sp
	)

	 select @ct2 = count(*) from c where avgEWCP < 1 and ct > 1



	insert into @results
	select
	'Medium',
	'Mech Thermostat Engaged',
	'Event Count',
	@ct1 + @ct2,
	null
	where @ct1 + @ct2 > 0


	return 

end
