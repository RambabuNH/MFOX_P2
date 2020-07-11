

/*

select * from [wky].[getMissingIceSensors] (2919283236796367032, '2019-11-1', '2019-11-8')
Line Freqency Abnormal	Percentage	69.2
select * from [wky].[getBadGeneratorErrors] (2945393914980335705,'2019-9-1', '2019-9-8')
Line Freqency Abnormal	Percentage	63.0
select * from [wky].[getBadGeneratorErrors] (2945393914980335705,'2019-9-8', '2019-9-16')
Line Freqency Abnormal	Percentage	89.7
select * from [wky].[getBadGeneratorErrors] (2945393914980335705,'2019-9-16', '2019-9-24')
Line Freqency Abnormal	Percentage	5.1

select * from [wky].[getBadGeneratorErrors] (2945393914980335705,'2019-9-24', '2019-10-1')


select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-10-1', '2019-10-8')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-10-8', '2019-10-16')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-10-16', '2019-10-24')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-10-24', '2019-11-1')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-11-1', '2019-11-8')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-11-8', '2019-11-16')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-11-16', '2019-11-24')

select * from [wky].[getBadFrequencyErrors] (2917675231139070019,'2019-11-24', '2019-12-6')


select * from [wky].[getBadFrequencyErrors] (2882410590406443083,'2019-11-24', '2019-12-6')




select * from [wky].[getBadFrequencyErrors] (2910952812751880355,'2019-12-2', '2019-12-9')
select * from [wky].[getBadFrequencyErrors] (2945393914980335705,'2019-12-2', '2019-12-9')
select * from [wky].[getBadFrequencyErrors] (2909200195512172668,'2020-1-5', '2020-1-12')

select * from [wky].[getBadFrequencyErrors] (2891445436365668583,'2020-1-5', '2020-1-12')
select * from [wky].[getBadFrequencyErrors] (2891445436365668583,'2019-6-1', '2019-6-8')
select * from [wky].[getBadFrequencyErrors] (2891445436365668583,'2019-6-8', '2019-6-16')
select * from [wky].[getBadFrequencyErrors] (2891445436365668583,'2019-6-16', '2019-6-24')
select * from [wky].[getBadFrequencyErrors] (2891445436365668583,'2019-6-24', '2019-7-1')


select * from [wky].[getBadFrequencyErrors] (2914027571215597778,'2019-9-14', '2019-9-25')


Message	Detail	value	errCnt
Line Freqency Abnormal	In Range %	0.0	NULL

--https://github.com/new-horizons/mf-mfox/issues/286
only show 'line frequency abnormal' if

slnx<15 AND (%time EVLN is between 82 and 290) > 3%

-- slnx from main
			-- modified 1/21/2019
			(
				cast(
				(select isnull(sum(case when slnx = 1 or (slnx is null and evln > 82 and evln < 290) or EWDCA > 30 then 1 else 0 end),0)
				from sensorsolardata_view s where s.FRIDGEID = r.fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate)
				/ (8640.0 * @days) * 100.0 as numeric(6,1))

			) as SLNX,

*/





CREATE FUNCTION [wky].[getBadFrequencyErrors] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Bad Generator Errors - checks frequency when voltage in range
	----------------------------------------------------------------------------------------------------------------------



		declare @days int = datediff(day,@startDate, @endDate)

		declare @voltageOK bit =
		(
			select case when count(measuredDtm) > 1 then 1 else 0 end from sensordata_view s 
			where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate 
			and (s.EVLN > 82 and s.EVLN < 290)
		)

		-- don't process further if voltage is all bad, this case will be caught elsewhere and flagged
		if @voltageOK = 0 return


		;with a as
		(
			select
			(
				-- voltage is in range and frequency out of range count
				select count(measuredDtm) from sensordata_view s where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate 
				and (s.EHZLN < 45 OR s.EHZLN > 65) and (s.EVLN > 82 and s.EVLN < 290)
			) as HzBadCt,

			(
				-- voltage in range count
				select count(measuredDtm) from sensordata_view s where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate 
				and (s.EVLN > 82 and s.EVLN < 290)
			) as vOkCt,

			(
				-- any voltage count, used for voltage in range threshold filter
				select count(measuredDtm) from sensordata_view s where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
				and s.EVLN is not null
			) as vAllCt,


			(
				select sum(case when slnx = 1 then 1 else 0 end)
				from sensorsolardata_view s where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
			) as SLNXct



		)

		,b as
		(
			select 
			case 
				when vOkCt = 0 then 0 
				else 100.0 - ((cast(HzBadCt as float) / cast(vOkCt as float)) * 100.0)
			end	as badHzPct,

			case 
				when vAllct = 0 then 0 
				else 100 - ((cast(vOkCt as float) / cast(vAllCt as float)) * 100.0)
			end	as vTotalPct,


			case 
				when SLNXct = 0 then 0 
				else SLNXct / (8640.0 * @days) * 100.0 
			end	as SLNXpct

			from a
		)


		insert into @results
		select
		'Medium',
		'Line Frequency Abnormal',
		'In Range %',
		badHzPct,
		vTotalPct
		from b
		where badHzPct < 95 and vTotalPct > 3 and SLNXpct < 15



	return 

end
