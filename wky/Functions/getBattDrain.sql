
/*

select * from [wky].[getBattDrain] (2912125678092550146,	'2019-12-01',	'2019-12-08')


*/



CREATE FUNCTION [wky].[getBattDrain] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Get battery drain over 24 hour period, finds worst case of the week. 
	-- More consistent results than just getting first case, and also eliminates null cases
	-- look in 24 to 25 hour window
	----------------------------------------------------------------------------------------------------------------------


	;with a as
	(
		select
		measureddtm as dtm1,
		(
			select top 1 measureddtm
			from sensordata_view 
			where fridgeid = @fridgeid
			and measureddtm >= dateadd(hour,24,v.measureddtm) and measureddtm < @endDate
			order by measureddtm
		) dtm2

		from sensordata_view v
		where fridgeid = @fridgeid
		and measureddtm >= @startdate and measureddtm < @endDate
	)

	,b as
	(
		select top 1
			(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) -
			(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) as battDiff
		from a
		where 
		(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) is not null
		and 
		(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) is not null
		and datediff(minute,dtm1,dtm2) < 1500

	)

	insert into @results
	select 
	'Low',
	'Fast Battery Drain' as [message], 
	--'Drain Exceeds 24 hr Limit' as [detail], 
	--battDiff as [value],
	null,
	null,
	null
	from b
	where battDiff < -2.0

	return





	/*

	;with a as
	(
		select
		measureddtm as dtm1,
		(
			select top 1 measureddtm
			from sensordata_view 
			where fridgeid = @fridgeid
			and measureddtm >= dateadd(hour,24,v.measureddtm) and measureddtm < @endDate
		) dtm2

		from sensordata_view v
		where fridgeid = @fridgeid
		and measureddtm >= @startdate and measureddtm < @endDate
	)

	,b as
	(
		select top 1
		*,
		datediff(minute,dtm1,dtm2) as DiffMins
		from a
		where datediff(minute,dtm1,dtm2) > 1440 and datediff(minute,dtm1,dtm2) < 1500
	)

	insert into @results
	select 
	'Battery Drain Error' as [message], 
	'Drain Exceeds 24 hr Limit' as [detail], 
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) -
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) 
	as [value],
	null
	from b	

	return 

	*/

end



