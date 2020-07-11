

/*



select * from [wky].[getMissingIceSensors] (2947995359491653818, '2020-1-12', '2020-1-19')

select * from [wky].[getMissingIceSensors] (2947587436382781441, '2020-1-12', '2020-1-19')

select * from [wky].[getMissingIceSensors] (2940514016004407476, '2020-1-12', '2020-1-19')

select * from [wky].[getMissingIceSensors] (2927567219393036462, '2020-1-12', '2020-1-19')

select * from [wky].[getMissingIceSensors] (2909278419751534728, '2020-1-12', '2020-1-19')

select * from [wky].[getMissingIceSensors] (2927567219393036462, '2020-1-12', '2020-1-19')


*/



CREATE FUNCTION [wky].[getMissingIceSensors] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Missing Ice, Control Sensors and CTBH
	----------------------------------------------------------------------------------------------------------------------

	; with b as
	(
		select
		count(measuredDtm) as dtmCt,
		count(SCPX) as scpxCt,
		sum(case when TAMDAQ is null then 0 else 1 end) as tamdaq_ct,
		sum(case when TVCTOPCTL is null then 0 else 1 end) as tvctopctl_ct,
		sum(case when TICMCTL is null then 0 else 1 end) as ticmctl_ct,
		sum(case when TICBKCTL is null then 0 else 1 end) as ticbkctl_ct,
		sum(case when CTBH is null then 0 else 1 end) as ctbh_ct
		from sensordata_view s where s.FRIDGEID = @fridgeid and s.measuredDtm >= @startDate and s.measuredDtm < @endDate
	)


	/*
	jenny based rules 2020-27-1
	tamdaq - uses dtmCt
	ctbh - uses dtmCt
	tvctopctl - uses scpx count
	ticmctl - uses scpx count
	ticbkctl - uses scpx count

	Both Missing Ice Sensors
	if sxpx count < 5 then don't show control sensor errors
	*/


	,c as
	(
		select b.*,
		case when dtmCt = 0 then 0
			else cast( cast(tamdaq_ct as float) / cast(dtmCt as float) * 100.0 as numeric(8,1)) end  as TAMDAQ_pct,
		case when scpxCt = 0 then 0
			else cast( cast(tvctopctl_ct as float) / cast(scpxCt as float) * 100.0 as numeric(8,1)) end as TVCTOPCTL_pct,
		case when scpxCt = 0 then 0
			else cast( cast(ticmctl_ct as float) / cast(scpxCt as float) * 100.0 as numeric(8,1)) end  as TICMCTL_pct,
		case when scpxCt = 0 then 0
			else cast( cast(ticbkctl_ct as float) / cast(scpxCt as float) * 100.0 as numeric(8,1)) end as TICbkCTL_pct,
		case when dtmCt = 0 then 0
			else cast( cast(ctbh_ct as float) / cast(dtmCt as float) * 100.0 as numeric(8,1)) end as CTBH_pct
		from b
	)



		insert into @results
		select * from
		(

			select
			'Medium' as [Priority],
			'USB Board - Control Sensor Error' as a, 
			'TAMDAQ OK %' as b, 
			TAMDAQ_pct as c,	
			dtmCt - tamdaq_ct as d
			from c
			where TAMDAQ_pct < 90

			union all

			select
			'Low' as [Priority],
			'Control Sensor Error' as a, 
			'TVCTOPCTL OK %' as b, 
			TVCTOPCTL_pct as c,	
			dtmCt - tvctopctl_ct as d
			from c
			where TVCTOPCTL_pct < 90 and scpxCt > 5

			union all

			select
			'Low' as [Priority],
			'Ice Sensor Error' as a, 
			'TICMCTL OK %' as b, 
			TICMCTL_pct as c,	
			dtmCt - ticmctl_ct as d
			from c
			where TICMCTL_pct < 90 and scpxCt > 5

			union all

			select
			'Low',
			'Ice Sensor Error', 
			'TICBKCTL OK %', 
			TICBKCTL_pct,	
			dtmCt - ticbkctl_ct
			from c
			where TICBKCTL_pct < 90	and scpxCt > 5

			union all

			select
			'Low',
			'No Calculated Holdover', 
			'Check Sensor Errors', 
			CTBH_pct,	
			null
			from c
			where CTBH_pct < 80 

			union all

			-- Both Missing Ice Sensors
			select
			'Medium',
			'Both Ice Sensors Missing Error' as a, 
			'Control OK %' as b, 
			case when ticmctl_pct > ticbkctl_pct then ticmctl_pct else ticbkctl_pct end as [value],
			null as errCnt
			--scpxCt - ticmctl_ct as d
			from c
			where TICMCTL_pct < 95 and TICbkCTL_pct < 95 and scpxCt > 5


		)x


	return 

end
