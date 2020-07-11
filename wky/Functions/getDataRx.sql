

/*



*/



CREATE FUNCTION [wky].[getDataRx] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		[Priority] varchar(255) null,
		[Message] [varchar](255) NULL,
		[Detail] [varchar](255)  NULL,
		[value] [float] NULL,
		errCnt int null
)  

AS  
begin  

	----------------------------------------------------------------------------------------------------------------------
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
			cast
			(
				cast( count(dte) as float) / cast( DATEDIFF(minute,@startDate,@endDate) / 10.0 as float) * 100.0
				as numeric(8,1)
			) as dtePct
			from a
		)

		insert into @results
		select 
		'Low',
		'Missing Data',
		'Data Rx %',
		dtePct,
		null
		from b
		where dtePct < 95

	return 

end
