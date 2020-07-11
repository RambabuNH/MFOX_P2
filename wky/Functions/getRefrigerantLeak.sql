

/*


select * from [wky].[getRefrigerantLeak] (2947587436382781441, '2019-12-2', '2019-12-9')

*/



CREATE FUNCTION [wky].[getRefrigerantLeak] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Refrigerant Leak (only for mains devices)
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(
			select
			(
				select count(measuredDtm) from sensordata_view s where s.FRIDGEID = @fridgeid and  measuredDtm >= @startDate and measuredDtm < @endDate 
				and EWCP2 > 10 and EWCP2 < 160 and SCPX = 1
			) as v1,

			(
				select count(measuredDtm) from sensordata_view s where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate 
				and ewcp2 > 10 and SCPX = 1
			) as v2
		)

		,b as
		(
			select 
				case when v2 = 0 then 0
				else cast(v1 as float) / cast (v2 as float) * 100.0
				end as pct
			from a
		)

		,c as
		(
			select (100.0 - b.pct) as pct from b
		)

		insert into @results
		select
		'High',
		'Possible refrigerant leak',
		'Compressor Power %',
		c.pct,
		null
		from c
		where c.pct < 95


	return 

end
