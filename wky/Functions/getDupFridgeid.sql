


/*

select * from [wky].[getDupFridgeid] (2908746088619966487, '2019-12-2', '2019-12-9')

select * from [wky].[getDupFridgeid] (2933115672927928541, '2019-12-2', '2019-12-9')

*/



CREATE FUNCTION [wky].[getDupFridgeid] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		[Message] [varchar](255) NULL,
		[Detail] [varchar](255)  NULL,
		[value] [float] NULL,
		errCnt int null
)  

AS  
begin  

	----------------------------------------------------------------------------------------------------------------------
	-- Find duplicate fridgeids, any days where max number of records is exceeded, should be rare 
	----------------------------------------------------------------------------------------------------------------------
	
	declare @dayCt int 


	; with a as
	(
		select 
		cast(s.measureddtm as date) as dte,
		count(s.measureddtm) as ct
		from sensordata_view s 
		where s.FRIDGEID  = @fridgeid and s.measuredDtm >= @startDate and s.measuredDtm < @endDate
		group by cast(s.measureddtm as date)
	
	)

	-- add a little extra headroom, may be off by a couple 
	select @dayCt = count(*) from a where ct > 8640.0 * 1.002

	insert into @results
	select
	'Data Error' as [message], 
	'Duplicate FridgeId' as [detail], 
	null as [value],
	@dayCt as [errCnt]
	where @dayCt > 0

	/*
	insert into @results
	select
	'Data Error' as [message], 
	'Duplicate FridgeId' as [detail], 
	null as [value],
	--cast(ct as float) / cast(secs as float) * 100.0 as [value],
	null as [errCnt]
	from a
	where cast(ct as float) / cast(secs as float) > 1.01
	*/

	return 

end


