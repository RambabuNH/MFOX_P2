

/*

select * from [wky].[getBadSolarPower] (2893245177986547874,'2019-12-02', '2019-12-09')

*/



CREATE FUNCTION [wky].[getBadSolarPower] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- bad power mains and hybrid
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select
				case when
					slnx = 1  -- Handles new code and mains.
					or (slnx is null and evln > 90 and evln < 290) -- Handles old code that doesn't send SLNX.
					or EWDCA > 30 -- Handles PV.
					then 1 else 0
				end as pwrOK		
			from sensorSolarData_view s
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
		'Low Solar Power Availability',
		'Power OK %',
		pwrOKPct,
		null
		from b
		where pwrOKPct < 15


	return 

end
