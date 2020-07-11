

/*


*/



CREATE FUNCTION [wky].[getMissingEvln] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Missing EVLN, power board dropout
	----------------------------------------------------------------------------------------------------------------------	

		;with a as
		(

			select
			case
				when count(evln) = 0 then 0
				else cast( count(evln) as float) / cast( count(measureddtm) as float) * 100.0 
			end as evlnPct
			from sensordata_view s 
			where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
		)

	
		insert into @results
		select
		'Medium',
		'Missing Power Board Data',
		'Data OK %',
		evlnPct,
		null
		from a
		where evlnPct < 90


	return 

end
