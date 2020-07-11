


CREATE FUNCTION [wky].[getBattDrain_test] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @results 
TABLE
(
		fridgeid bigint,
		startDate date, 
		endDate date,
		startDtm datetime2(0), 
		endDtm datetime2(0),
		battStart float,
		battEnd float,
		battDiff float
)  

AS  
begin  

	----------------------------------------------------------------------------------------------------------------------
	-- Get battery drain over first 24 hour period 
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

	insert into @results
	select top 1
	@fridgeid,
	@startDate,
	@endDate,
	dtm1,
	dtm2,
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) as ecdbat1,
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) as ecdbat2,
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) -
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) as battDiff
	--datediff(minute,dtm1,dtm2) as DiffMins
	from a
	where 
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) is not null
	and 
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) is not null
	and datediff(minute,dtm1,dtm2) < 1500
	order by 5 asc


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
		and ecdbat is not null
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
	@fridgeid,
	@startDate,
	@endDate,
	dtm1,
	dtm2,
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1),
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2),

	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm2) -
	(select ecdbat from sensordata_view where fridgeid = @fridgeid and measureddtm = dtm1) 
	from b	
*/
	return 

end



