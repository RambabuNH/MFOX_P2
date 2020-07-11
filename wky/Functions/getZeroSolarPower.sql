/*
-- https://github.com/new-horizons/mf-mfox/issues/305

select * from [ram].[getZeroSolarPower] (2884497467770929352 ,GETUTCDATE()-7, GETUTCDATE())
*/



CREATE FUNCTION [wky].[getZeroSolarPower] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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

		declare @pct float = 0
		declare @rxThreshold float = 5.0

		-- find fridges with zero EWDCA for past week
		-- get the data availability only for zero EWDCA fridges
		-- only submit results for fridges sending data
		-- don't get rx% for all fridges - takes too much time and unnecessary

		if 
		(
			SELECT 
			sum(CASE WHEN EWDCA > 0.1 THEN 1 ELSE 0 END) AS ct
			FROM dbo.solardata_view 
			WHERE FRIDGEID = @fridgeid
			AND measuredDtm >= @startDate and measuredDtm < @endDate
		) = 0

		begin
			;with a as
			(
				select 
				dateadd(minute, 10 * (datediff(minute, '20160101', measureddtm) / 10), '20160101') as dte
				from sensordata_view e 
				where fridgeid = @fridgeid and measureddtm >= @startDate and measureddtm < @endDate
				group by dateadd(minute, 10 * (datediff(minute, '20160101', measureddtm) / 10), '20160101')
			)

			select @pct = (select cast( count(dte) as float) / cast( DATEDIFF(minute,@startDate,@endDate) / 10.0 as float) * 100.0 from a)
		end

		insert into @results 
		select 'Medium',
		'Solar Power Disconnected',
		'Data Rx %',
		cast(cast(@pct as numeric (6,0)) as varchar(16)),
		null
		where @pct > @rxThreshold

	RETURN 

END

  