
/*


select * from [wky].[getDAQSensorErrors] (2929896298586833139,	'2020-02-01', '2020-2-15')


*/




CREATE FUNCTION [wky].[getDAQSensorErrors] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0) )  

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
	-- DAQ Sensor Errors
	-- need to do more work to find out what's going on with duplicate entries in the error table
	-- I think they are real (?)
	-- plus the way that Bob is sending the  data is not ideal
	----------------------------------------------------------------------------------------------------------------------

		declare @days float = datediff(day,@startDate, @enddate)



		; with a as
		(
			select err, msg, ct from
			(
				select
				ROW_NUMBER() over (partition by measureddtm order by measureddtm) as rn,
				e.measureddtm,
		
				case 
					--when e.id = 'A186' or e.id = 'A187' or e.id = 'A1D5' or e.id = 'A188' then 'Control Sensor Error'
					when e.id in ('6782','6784','6301','630D') then 'SD Card Error'
				end as err,
		
				case
					when CHARINDEX('(',e.message) = 0 then e.message
					else SUBSTRING( e.message,0, CHARINDEX(' ',e.message) )  
				end as msg,
				case 
					when CHARINDEX('(',e.message) = 0 then 1
					else SUBSTRING ( e.message, CHARINDEX('(',e.message) + 1 , CHARINDEX(')',e.message) - CHARINDEX('(',e.message) - 1 )  
				end as ct

				from fridgeErrors_view e where e.fridgeid = @fridgeid
				--and e.ID in ('A186','A187','6782','6784','A1D5','A188')
				and e.ID in ('6782','6784','6301','630D')
				--and e.message not like ('TCPDISCT%')
				and e.measureddtm >= @startDate and measureddtm < @endDate
			)x where rn = 1
			group by err, msg, ct
		)

		,b as
		(
			select
			err, 
			msg + ' Error Count' as pct, 
			/*
			case 
				when cast( cast(sum(ct) as float) / cast(360.0 * 24.0 * @days as float) * 100.0  as numeric(9,3)) > 100.0 then 100.0
				else cast( cast(sum(ct) as float) / cast(360.0 * 24.0 * @days as float) * 100.0  as numeric(9,3))
			end as ct,
			*/
			sum(ct) as ct,
			sum(ct) as errCnt
			from a
			group by err, msg
		)

		insert into @results 
		select 
		'Low',
		err,
		pct,
		ct,
		errCnt 
		from b
		-- extra filtering based on Jenny's rules
		where err = 'SD Card Error' and errCnt > 20


	return 

end
