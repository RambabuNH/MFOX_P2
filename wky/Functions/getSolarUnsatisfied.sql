

/*

select * from [wky].[getSolarUnsatisfied] (2917497110255370483, '2019-11-11', '2019-11-18')

*/



CREATE FUNCTION [wky].[getSolarUnsatisfied] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- flag for solar fridge never hitting satisfied that week #242
	-- flag if SCPX reaches 6 but never reaches 2: control cycling, undersatisfied
	-- flag if SCPX never equals 2 or 6 during the week - not enough ice
	----------------------------------------------------------------------------------------------------------------------

	declare @count6 int
	declare @count2 int

	select @count6 = count(measuredDtm)
	from sensordata_view s
	where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
	and SCPX = 6

	select @count2 = count(measuredDtm)
	from sensordata_view s
	where s.FRIDGEID = @fridgeid and measuredDtm >= @startDate and measuredDtm < @endDate
	and SCPX = 2


	-- flag if SCPX reaches 6 but never reaches 2: control cycling, undersatisfied
	insert into @results
	select
	'Low',
	'Solar Fridge Low Ice' as a, 
	'Undersatisfied' as b, 
	null as c,
	null as d
	where @count6 > 1 and @count2 = 0



	-- flag if SCPX never equals 2 or 6 during the week - not enough ice
	insert into @results
	select
	'Medium',
	'Solar Fridge Low Ice', 
	'Not Enough Ice', 
	null,
	null
	where @count6 = 0 and @count2 = 0

	
	return 

end
