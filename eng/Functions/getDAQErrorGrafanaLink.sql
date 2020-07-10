
/*
drop table if exists #fridge

		select l.fridgeid
		into #fridge
		from fridgelocation2 l
		where l.Country = 'Nigeria' 
		and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
		and fridgeid in (2929756664905072841, 2953814662187057234)

	SELECT f.fridgeid,  u.link
	  FROM #fridge f
	 CROSS APPLY [eng].[getDAQErrorGrafanaLink] (f.fridgeid, '440D','2020-04-26','2020-04-28', 120) u

--https://mf2.clubmezz.org/chart?fid=2929756664905072841&start=1587859127&stop=1587861527&var-ERRORS=440D
--https://mf2.clubmezz.org/chart?fid=2929756664905072841&start=1587859127&stop=1587861527&var-ERRORS=440D&var-ERRORS=440C

*/
-- grafana link needs to go to the entire time period covered by the report, not the time of the first event.
-- for DAQ errors let's just do the week of the report with 6 extra hours on either side
CREATE FUNCTION [eng].[getDAQErrorGrafanaLink] (@fridgeid bigint,@id varchar(255), @startDate datetime2(0),@endDate datetime2(0), @range int)  
RETURNS  [varchar](2048)  
AS  
begin  
   DECLARE @result varchar(2048)
    SELECT @result = 
          CASE WHEN (select top 1 1 from GroupFridge where FridgeID = @fridgeid and GroupName = 'solar') = 1
               THEN 'https://mf2.clubmezz.org/chartsolar?fid=' + cast(@fridgeid as varchar(64)) +           
                    '&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @startDate) - (@range) as varchar) +
                    '&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @endDate) + (@range) as varchar)+@id
               ELSE 'https://mf2.clubmezz.org/chart?fid=' + cast(@fridgeid as varchar(64)) +           
                    '&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @startDate) - (@range) as varchar) +
                    '&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @endDate) + (@range) as varchar)+@id
          END

   return @result

end
