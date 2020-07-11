

/*

		drop table if exists #fridge

		select l.fridgeid
		into #fridge
		from fridgelocation2 l
		where l.Country = 'Nigeria' 
		and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')

	SELECT f.fridgeid, u.Message, u.Detail, u.value, u.errCnt
	FROM #fridge f
	CROSS APPLY [wky].[getMechThermTripped] (f.fridgeid, '2019-11-1', '2019-11-18') u

	-- should show 2 fridges


	select * from [wky].[getMechThermTripped2] (2935511813690753220, '2020-2-15', '2020-3-1')   




*/



CREATE FUNCTION [wky].[getMechThermTripped2] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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



	-- handles case where thermostat trips before compressor start

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
		DATEADD(minute,2,t2) as sp -- add a couple minutes after startup
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
		on s.FRIDGEID = @fridgeid and measuredDtm < dateadd(minute,5,b.sp) and measuredDtm > b.sp and scpx = 1 and ewcp2 != 0 
		group by b.sp
	)

	----------------------------------------------------------------------------------------------------------------------
	-- Mech Thermostat engaged
	-- closed when temperature is 2 deg +- 1.5
	-- opens when temp drops to -1.5 +- 1.5
	-- breaks the ac power connection to compressor
	-- thermostat tends to stick, events may be disassociated
	----------------------------------------------------------------------------------------------------------------------

	insert into @results
	select
	'Medium',
	'Mech Thermostat Engaged',
	'Event Count',
	count(*),
	null
	from c where avgEWCP < 1 and ct > 20 
	having count(*) > 0

	return 

end
