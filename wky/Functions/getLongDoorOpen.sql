


/*

select * from [wky].[getLongDoorOpen] (2933023309656227845,'2019-10-1','2019-10-15')

select * from [wky].[getLongDoorOpen] (2912812658111545446,'2019-8-1','2019-8-15')

*/



CREATE FUNCTION [wky].[getLongDoorOpen] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- Long door openings based on 5404 status message
	-- function seems excessively complicated but does the job
	-- current threshold is 12 hours
	----------------------------------------------------------------------------------------------------------------------	

	
			-- find every hour that has a door open alert
			;with a as
			(
				select 
				dateadd(hour, 1 * (datediff(HOUR, '20160101', measureddtm) / 1), '20160101') as dte
				from fridgeErrors_view e 
				where e.ID in ('5404')
				and measureddtm >= @startDate and measureddtm < @endDate
				and fridgeid = @fridgeid
				group by dateadd(hour, 1 * (datediff(HOUR, '20160101', measureddtm) / 1), '20160101')
			)

			-- get difference in hours between subsequent events
			-- force them into groups
			,b as
			(
				select 
				dte,
				DATEDIFF(hour, dte, lead(dte) over (order by dte)) as diff
				from a
			)

			-- handle last entry
			,c as
			(
				select *, 
				case 
				when diff is null then 0
				when DATEDIFF(hour, dte,lead(dte) over (order by dte)) = 1 then 0 else 1 
				end as grp	
				from b
			)
			-- create the groups with count
			,d as
			(
				select *,
				sum(grp) over (order by dte) as grp1
				from c
			)

			,e as
			(
				select 
				grp1, 
				count(*) as ct
				from d 
				group by grp1
			)

			insert into @results
			select
			'High',
			'Door Open Alert',
			'Open Hours',
			max(ct),
			null
			from e
			having max(ct) > 11




	return 

end
