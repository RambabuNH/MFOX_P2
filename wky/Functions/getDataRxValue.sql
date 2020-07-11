

/*

select * from [wky].[getDataRxValue](2882377905688543293,'2020-02-23','2020-03-01') 

select * from Report_WeeklyTech_v5 where message = 'missing data'

select datarx from [wky].[getDataRxValue] (r.fridgeid, @startDate, @endDate)


*/



CREATE FUNCTION [wky].[getDataRxValue] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		[dataRx] [float] NULL
)  

AS  
begin  

	----------------------------------------------------------------------------------------------------------------------
	-- same algorithm as getDataRx, but used to populate column so results are identical
	-- data rx
	-- flag units with low data rx% in tech report, issue #181
	-- this is based on 10 minute intervals to handle low power state
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select 
			dateadd(minute, 10 * (datediff(minute, '20160101', measureddtm) / 10), '20160101') as dte
			from sensordata_view e 
			where fridgeid = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
			group by dateadd(minute, 10 * (datediff(minute, '20160101', measureddtm) / 10), '20160101')
		)

		,b as
		(
			select 
			(
				cast(count(dte) as float) / cast( DATEDIFF(minute,@startDate,@endDate) / 10.0 as float) * 100.0
			) as dtePct
			from a
		)

		insert into @results
		select 
		cast(dtePct as numeric(6,1))
		from b

	return 

end
