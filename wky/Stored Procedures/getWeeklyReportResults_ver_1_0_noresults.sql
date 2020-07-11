​
​
/*
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] @Country = 'All',@ReportRunDate='2020-04-20'
​
EXEC [wky].[getWeeklyReportResults_ver_1_0] @Country = 'All',@ReportRunDate='2020-04-13'
​
EXEC [wky].[getWeeklyReportResults_ver_1_0_noresults] 'DRC', '2020-4-23'
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
where startdate = '2020-04-12'
​
*/
​
​
CREATE PROCEDURE [wky].[getWeeklyReportResults_ver_1_0_noresults] 
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
      
    -- Delete and RePopulate if @Country = 'All'
    ----------------------------------------------
	  IF (@Country = 'All')
	  BEGIN
	     DELETE wky.Report_WeeklyTech_v6
          WHERE StartDate = @Start
	        AND EndDate   = @End
​
         EXEC [wky].[populateWeeklyReportTech_v6]  @startDate = @Start, @endDate = @End, @Country = @Country
	  END
​
	 -- if @Country <> 'All' (Ex., @Country = 'DRC'), Populate only if data doesn't exist for the date range
     ------------------------------------------------------------------------------------------------------
	  IF (@Country <> 'All')
	  BEGIN
         SELECT @Count = ISNULL(count(*),0)
           FROM wky.Report_WeeklyTech_v6
          WHERE StartDate = @Start
	        AND EndDate   = @End
		    AND Country   = @Country
	 
         IF @Count = 0
         BEGIN
            EXEC [wky].[populateWeeklyReportTech_v6]  @startDate = @Start, @endDate = @End, @Country = @Country
         END
	  END




	


​
  END
