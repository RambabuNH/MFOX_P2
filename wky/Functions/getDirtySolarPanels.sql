


/*

select * from wky.getDirtySolarPanels(2889103485188440208, '2020-1-1','2020-1-25')

select measureddtm, ewdca from solardata_view where fridgeid = 2889103485188440208 and measureddtm > '2020-1-1'
order by measureddtm

*/



CREATE FUNCTION [wky].[getDirtySolarPanels] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
			cast( max(EWDCA) as numeric(6,0)) as maxEWDCA
			from solardata_view s 
			where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
		)

	
		insert into @results
		select
		'Low',
		'Low Solar Power',
		'Max EWDCA',
		maxEWDCA,
		null
		from a
		where maxEWDCA < 120


	return 

end

