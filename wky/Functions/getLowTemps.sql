

/*


*/



CREATE FUNCTION [wky].[getLowTemps] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Low temperatures, flag units with TVCTOPCTL or TVCBOT < 2C during the week
	----------------------------------------------------------------------------------------------------------------------	
		;with a as
		(
			select 
			dateadd(minute, 1 * (datediff(minute, '20160101', measureddtm) / 1), '20160101') as dte,
			--sum(case when TVCTOPCTL < 2 or TVCBOT < 2 then 1 else 0 end) as minct
			sum(case when TVCTOPCTL < 2 then 1 else 0 end) as minct
			from sensordata_view e where e.FridgeId = @fridgeid
			and measureddtm >= @startDate and measureddtm < @endDate
			group by dateadd(minute, 1 * (datediff(minute, '20160101', measureddtm) / 1), '20160101')
		)

		,b as
		(
		select dateadd(day, 1 * (datediff(day, '20160101', dte) / 1), '20160101') as dte
		from a
		where minct > 0
		group by dateadd(day, 1 * (datediff(day, '20160101', dte) / 1), '20160101')
		)

		insert into @results
		select
		'High',
		'Low Temperature Alert',
		'Days (Count)',
		count(*),
		null
		from b 
		having count(*) > 0


	return 

end
