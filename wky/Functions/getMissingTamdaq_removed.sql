

/*

select * from  wky.getMissingTamdaq(2932774983237107926,'2019-11-14', '2019-11-21')
select * from  wky.getMissingTamdaq(2947297169608016007,'2019-11-14', '2019-11-21')

	drop table if exists #fridge
	select 2932774983237107926 as fridgeid into #fridge
	insert into #fridge select 2947297169608016007 as fridgeid 
	SELECT f.fridgeid, [Message], Detail, [value], errCnt
	FROM #fridge f 
	CROSS APPLY [wky].[getMissingTamdaq] (f.fridgeid,'2019-11-14', '2019-11-21')




*/



CREATE FUNCTION [wky].[getMissingTamdaq_removed] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Missing TAMDAQ, usb board dropout
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select
			case
				when count(measuredDtm) = 0 then 0
				else cast( count(TAMDAQ) as float) / cast( count(measureddtm) as float) * 100.0 
			end as tamdaqPct
			from sensordata_view s 
			where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
		)

	
		insert into @results
		select
		'Medium',
		'Missing USB Board Data',
		'Data OK %',
		tamdaqPct,
		null
		from a
		where tamdaqPct < 90


	return 

end
