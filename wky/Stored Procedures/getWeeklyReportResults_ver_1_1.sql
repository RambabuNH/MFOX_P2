​
​
/*
​
EXEC [wky].[getWeeklyReportResults_ver_1_1] @Country = 'All',@ReportRunDate='2020-04-27'
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] @Country = 'All',@ReportRunDate='2020-04-13'
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] 'DRC', '2020-04-20', 1
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] @Country = 'Ethiopia',@ReportRunDate='2020-04-20'
​
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] 'DRC', '2020-04-22'
​
select * from wky.Report_WeeklyTech_v6 where country = 'drc'
​
--  delete wky.Report_WeeklyTech_v6 where country = 'drc'
​
select startdate, count(*) from wky.Report_WeeklyTech_v6 group by startdate
​
select * from wky.Report_WeeklyTech_v6 
​
         EXEC [wky].[populateWeeklyReportTech_v6]  @startDate = '2020-4-19, @endDate = '2020-4-26', @Country = 'All'
​
*/
​
​
CREATE PROCEDURE [wky].[getWeeklyReportResults_ver_1_1] 
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
	  SELECT @Start =  DATEADD(day,-8,@ReportRunDate)
           , @End   =  DATEADD(day,-1,@ReportRunDate)
      
  


​
-- Return the Country specific Weekly Data
------------------------------------------------------------
	  IF @Country <> 'All'
	  BEGIN
      SELECT [Priority]
           , Country
           , L1
           , L3
           , StartDate
           , EndDate
           , ReportDays
           , FridgeId
           , FridgeShortSN
           , FridgeType
		   , Deployed
           , commDte
           , [Message]
           , Detail
           , cast([Value] as numeric(8,1)) [Value]
           , cast(TVCTOPCTLavg as numeric(8,1)) TVCTOPCTLavg
           , cast(CTBH as numeric(8,0)) CTBH
           , cast(SLNX as numeric(8,0)) SLNX
           , cast(DataRx as numeric(8,0)) DataRx
           , CompRunAgeMin
           , CompRunAge
           , DataAge
           , Link
	    FROM wky.Report_WeeklyTech_v6
	   WHERE StartDate = @Start
	     AND EndDate   = @End
		 AND Country   = @Country 
	   --ORDER by FridgeId
     END
----------------------------------------------------------
-- Return Weekly Data for all countires
------------------------------------------------------------
	  IF @Country = 'All'
	  BEGIN
      SELECT [Priority]
           , Country
           , L1
           , L3
           , StartDate
           , EndDate
           , ReportDays
           , FridgeId
           , FridgeShortSN
           , FridgeType
		   , Deployed
           , commDte
           , [Message]
           , Detail
           , cast([Value] as numeric(8,1)) [Value]
           , cast(TVCTOPCTLavg as numeric(8,1)) TVCTOPCTLavg
           , cast(CTBH as numeric(8,0)) CTBH
           , cast(SLNX as numeric(8,0)) SLNX
           , cast(DataRx as numeric(8,0)) DataRx
           , CompRunAgeMin
           , CompRunAge
           , DataAge
           , Link
	    FROM wky.Report_WeeklyTech_v6
	   WHERE StartDate = @Start
	     AND EndDate   = @End
	   --ORDER by FridgeId
     END


​
  END
