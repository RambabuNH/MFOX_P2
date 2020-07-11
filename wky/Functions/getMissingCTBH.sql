

/*

select * from [wky].[getMissingSCPX] (2931321265656430834, '2019-12-1','2019-12-9')

*/




CREATE FUNCTION [wky].[getMissingCTBH] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Missing SCPX
	----------------------------------------------------------------------------------------------------------------------

		;with a as
		(

			select
			case
				when count(measuredDtm) = 0 then 0
				else cast( count(CTBH) as float) / cast( count(measureddtm) as float) * 100.0 
			end as ctbhPct
			from sensordata_view s 
			where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
		)

	
		insert into @results
		select
		'Low',
		'Missing CTBH',
		'Data OK %',
		ctbhPct,
		null
		from a
		where ctbhPct < 90


	return 

end

