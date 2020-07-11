



CREATE FUNCTION [wky].[getBattMissing] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Look for 1 hour periods where evdbat < .2
	----------------------------------------------------------------------------------------------------------------------

	;with a as
	(
		select fridgeid,
		case when max(evdbat) = null then 1 else 0 end as nullFlag,
		max(evdbat) as evdbat,
		datepart(year,measureddtm) as yr,
		datepart(month,measureddtm) as mo,
		datepart(day,measureddtm) as dy,
		datepart(hour,measureddtm) as hr
		from sensordata_view where fridgeid = @fridgeid
		and measureddtm >= @startDate and measureddtm < @endDate
		group by
		fridgeid,
		datepart(year,measureddtm),
		datepart(month,measureddtm),
		datepart(day,measureddtm),
		datepart(hour,measureddtm)
	)

	,b as
	(
		select count(*) as ct from a where evdbat < .2 and nullFlag != 1
	)

	insert into @results
	select 
	'Medium',
	'Battery Missing Error' as [message], 
	'1-hour Max Batt < .2 v' as [detail], 
	null,
	ct
	from b
	where ct > 0

	return 

end




