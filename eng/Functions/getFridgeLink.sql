/*


drop table if exists #fridge

		select l.fridgeid
		into #fridge
		from fridgelocation2 l
		where l.Country = 'Nigeria' 
		and l.FridgeID not in (select fridgeid from GroupFridge where GroupName = 'solar')
		and fridgeid in (2919283236796367032, 2910809566969069806)

	SELECT f.fridgeid,  u.link
	  FROM #fridge f
	 CROSS APPLY [Eng].[getFridgeLink] (f.fridgeid, '2020-04-27', 1200) u


*/
CREATE FUNCTION [Eng].[getFridgeLink] (@fridgeid bigint, @Date datetime2(0), @range int )  
RETURNS  [varchar](2048)  
AS  
begin  
   DECLARE @result varchar(2048)
   SELECT @result = 
         CASE WHEN (select top 1 1 from GroupFridge g where g.FridgeID = @fridgeid and GroupName = 'solar') = 1
              THEN 
              'https://mfoxmf2.azurewebsites.net/FridgeComment/indexSolarFlag?fridgeid=' +
               cast(@fridgeid as varchar(64)) + 
              '&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @Date) - (@range) as varchar) +
              '&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @Date) + (@range) as varchar)
  
             ELSE 
             'https://mfoxmf2.azurewebsites.net/FridgeComment/indexFlag?fridgeid=' +
              cast(@fridgeid as varchar(64)) + 
             '&start=' + cast(DATEDIFF(SECOND, '1970-01-01', @Date) - (@range) as varchar) +
             '&stop=' + cast(DATEDIFF(SECOND, '1970-01-01', @Date) + (@range) as varchar)
          END
 return @result

end
