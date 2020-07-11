

/*

select * from [wky].[getMissingIceSensors] (2919283236796367032, '2019-11-1', '2019-11-8')

*/



CREATE FUNCTION [wky].[getDAQHiTempErrors] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- more DAQ Sensor Errors
	-- number of days with high temp alarms
	--flag units with high temp alarms during the week #249
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select 
			ROW_NUMBER() over (partition by measureddtm order by measuredDtm) as rn,
			e.measuredDtm
			from FridgeErrors e where e.FridgeId = @fridgeid
			and (e.ID = '4406' or e.ID = '6402')
			and measureddtm >= @startDate and measureddtm < @endDate
		)

		,b as
		(
			select 
			cast(measureddtm as date) as dte
			from a
			where rn = 1
			group by cast(measureddtm as date)
		)

		insert into @results
		select
		'High',
		'High Temp Alarm', 
		'Number of Alarm Days', 
		count(*),	
		null
		from b
		having count(*) > 0



	return 

end
