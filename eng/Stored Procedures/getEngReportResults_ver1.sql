/*
​
EXEC [Eng].[getEngReportResults_ver1] @Country = 'All',@ReportRunDate='2020-06-14'
​
EXEC [Eng].[getEngReportResults_ver1] 'Kenya', '2020-06-07'
​
EXEC [Eng].[getEngReportResults_ver1] @Country = 'Nigeria',@ReportRunDate='2020-06-14'
​

select * from [Eng].[Report_WeeklyEng_v1] where country = 'Nigeria'

select startdate, count(*) from [Eng].[Report_WeeklyEng_v1] group by startdate
​
select * from [Eng].[Report_WeeklyEng_v1]
​
*/
​
​
CREATE PROCEDURE [eng].[getEngReportResults_ver1] 
     ( 
		@Country  VARCHAR(64) = 'All'
		,@ReportRunDate DATE = getutcdate
	 )
AS
  BEGIN
      SET NOCOUNT ON

​
	  DECLARE @Start  Date
	        , @End    Date
			, @Count  int
     
      SET @Country  = Trim(@Country)
	  SELECT @Start =  DATEADD(day,-7,@ReportRunDate)
     --      , @End   =  DATEADD(day,-1,@ReportRunDate)
      
​
-- Return the Country specific Weekly Data
------------------------------------------------------------
	  IF @Country <> 'All'
	  BEGIN
      SELECT Country
           , L1
           , L3
           , StartDate
           , EndDate
           , ReportDays
           , FridgeId
           , FridgeShortSN
           , FridgeType
           , [Message]
           , Detail
           , [value]
         --  , EventTime
		   , Format(cast(EventTime as datetime),'dd-MMM-yyyy HH:mm:ss','en-us') AS EventTime
           , RecCount
           , CASE WHEN [Message] like 'DAQ%' THEN GLink 
		          WHEN [Message] like 'Failed%Start%' THEN GLink 
  		          ELSE Link
		      END  AS Link
           , MessageInterval
	    FROM [Eng].[Report_WeeklyEng_v1]
	   WHERE StartDate = @Start
	   --  AND EndDate   = @End
		 AND Country   = @Country 
	   ORDER by   L1
           , L3
		   , FridgeId
     END
----------------------------------------------------------
-- Return Weekly Data for all countires
------------------------------------------------------------
	  IF @Country = 'All'
	  BEGIN
         SELECT Country
           , L1
           , L3
           , StartDate
           , EndDate
           , ReportDays
           , FridgeId
           , FridgeShortSN
           , FridgeType
           , [Message]
           , Detail
           , [value]
 --          , EventTime
	       , Format(cast(EventTime as datetime),'dd-MMM-yyyy HH:mm:ss','en-us') AS EventTime
           , RecCount
           , CASE WHEN [Message] like 'DAQ%' THEN GLink 
		          WHEN [Message] like 'Failed%Start%' THEN GLink 
  		          ELSE Link
		      END  AS Link
           , MessageInterval
	    FROM [Eng].[Report_WeeklyEng_v1]
	   WHERE StartDate = @Start
	 --    AND EndDate   = @End
	   ORDER by Country
           , L1
           , L3
		   , FridgeId
     END


​
  END
