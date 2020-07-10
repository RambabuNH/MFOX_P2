/*  
select * from [Eng].[getNoDoorOpenings] (2905443683937550348, '2020-05-01', '2020-05-17','Week')  
  
select * from [Eng].[getNoDoorOpenings] (2948723231894274129, '2020-05-17', '2020-05-24','Week')  
  
select * from [Eng].[getNoDoorOpenings] (2908324447351996668,'2020-06-28', '2020-07-05','Week')  
  
  
-- 05/11/2020 https://github.com/new-horizons/mf-mfox/issues/274  
add a query for no door openings over the week  
*/  
  
CREATE FUNCTION [eng].[getNoDoorOpenings] (@fridgeid bigint, @startDate datetime2(0), @endDate datetime2(0),@MessageInterval [varchar](5)='Week')    
RETURNS  @results   
TABLE  
(  [MessageInterval]  [VARCHAR] (5) NULL,  
  [Message] [varchar](255) NULL,  
  [Detail]  [varchar](255)  NULL,  
  [value]   [varchar](255)  NULL,   
  RecCount  int Null,  
  EventTime datetime2(0),  
  link      [varchar](2048) null  
)    
  
AS    
begin    
 declare @range int = 120 * 10  -- 20 minutes. for fridge Mfox Web UI link  
  
  
   
 ; with a as  
  (     
   SELECT   
   sum(sdxc) as ct  
            from sensordata_view  
   where fridgeid = @fridgeid  
   and measureddtm >= @startDate   
   and measureddtm < @endDate  
     )  
  
 
  
  
  INSERT INTO @results  
  SELECT 'Week' AS [MessageInterval]  
       , 'Door Openings' AS [Message]  
       , 'No door openings over the week' AS [Detail]   
       , NULL AS [value]    
       , ct AS RecCount   
    -- the date of the last door opening  
       , ( select top(1) measureddtm  
            from sensordata_view  
           where fridgeid = @fridgeid  
             and measureddtm < @startDate and measuredDtm >= DATEADD(day,-90, @startDate)   
             and sdxc > 0  
           order by measureddtm desc  
         ) as EventTime 
        , [Eng].[getFridgeLinkForDateRange] (@fridgeid, @startDate, @endDate, @range) AS link  
 
     FROM a  
    where ct = 0  
        
  
  return   
end  