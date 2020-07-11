

/*

select * from [wky].[getMissingIceSensors] (2919283236796367032, '2019-11-1', '2019-11-8')

*/



CREATE FUNCTION [wky].[getBadMainsPower] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- bad power mains
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select
			case when
				slnx = 1  -- Handles new code and mains.
				or (slnx is null and evln > 90 and evln < 290) -- Handles old code that doesn't send SLNX.
				then 1 else 0
			end as pwrOK	
			from sensorData_view s
			where s.fridgeid = @fridgeid and  measuredDtm >= @startDate and measuredDtm < @endDate
		)

		,b as
		(
			select 
			cast(cast(sum(pwrOk) as float) / cast(DATEDIFF(minute,@startDate, @endDate) * 6.0 as float) * 100.0 as numeric(8,1)) as pwrOKPct
			from a
		)

		insert into @results
		select 
		'Medium',
		'Low Mains Power Availability',
		'Power OK %',
		pwrOKPct,
		null
		from b
		where pwrOKPct < 5


	return 

end
