

/*

-- comp running when data cuts out
select * from dly.getLastCompRunFridge_ver_1_1(2929263765834694672,'2019-10-7','2019-11-1')

-- manipulate end data to test scenario
select * from dly.getLastCompRunFridge_ver_1_1(2882364410918076482,'2019-10-7','2019-10-31 19:05:00')

*/



CREATE FUNCTION [wky].[getLastCompRun] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

RETURNS  @fridges TABLE(lastDte datetime2(0), runDurSec int, runAgeMin int)  

AS  
begin  

	-- don't count compressor runs under 5 minutes
	declare @runLimitSec int = 5 * 60

	-- storage for intermediate results
	declare  @t table (measureddtm datetime2(0), st int, sp int)
	declare @x table (measureddtm datetime2(0), ewcp2 float)


	-- need to hande two special cases, maybe more, for ending transitions
	-- 1) compressor running at @endDate
	-- 2) compressor running when data is cut off

	-- find last data point, normally will be near @endDate, unless there is missing data
	declare @maxDte datetime2(0) = 
	(
		select max(measuredDtm) from sensordata_view s 
		where s.fridgeid = @fridgeid and s.measureddtm > @startDate and s.measuredDtm < @endDate
	)
	--select @maxDte

	-- get ewcp for last data point
	declare @ewcp float = (select ewcp2 from sensordata_view s where s.fridgeid = @fridgeid and measuredDtm = @maxDte)
	--select @ewcp

	-- save the data point if comp is running
	if @ewcp > 40.0
	insert into @t select @maxDte, 0,1
	--select * from @t


	-- get normal data and compensate for single missing data points, if there is one missing point use the next
	-- is the single point compensation work and is necessary?
	insert into @x
	select measureddtm,
	isnull(ewcp2,lead(ewcp2) over (order by measureddtm)) as ewcp2
	from sensordata_view s where s.fridgeid = @fridgeid
	and s.measuredDtm >= @startDate and s.measuredDtm < @endDate

	--select * from @x

	-- find the transitions
	insert into @t
	select * from
	(
		select measureddtm,
		-- include solar, 40 seems to work ok and not interfere with mains 
		case when isnull(ewcp2,0) > 40 and lag(isnull(EWCP2,0)) over (order by measureddtm) <= 40 then 1 else 0 end as st,
		case when isnull(ewcp2,0) > 40 and lead(isnull(ewcp2,0)) over (order by measureddtm) <= 40 then 1 else 0 end as sp
		from @x 
	)x where (st = 1 or sp = 1)  and not (st = 1 and sp = 1)

	--select * from @t


	-- find the last compressor run over minimum time
	insert into @fridges
	select top 1  measuredDtm, runSec, DATEDIFF(minute,measureddtm,@endDate) as runAgeMin from
	(
		select *,
		datediff(second,lag(measureddtm) over (order by measureddtm),measuredDtm ) as runSec
		from @t
	)x
	where sp = 1
	and runSec > @runLimitSec
	order by measureddtm desc


	return

end
