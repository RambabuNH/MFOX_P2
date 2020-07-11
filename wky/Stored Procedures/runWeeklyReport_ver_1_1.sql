​
​
/*
​
exec [wky].[runWeeklyReport_ver_1_1]
​
*/
​
​
CREATE PROCEDURE [wky].[runWeeklyReport_ver_1_1] 

AS
  BEGIN
      SET NOCOUNT ON

	  declare @ReportRunDate date = getutcdate()

​
	  DECLARE @Start  Date
	        , @End    Date
			, @Count  int
     
      declare @Country varchar(32) = 'All'
	  SELECT @Start =  DATEADD(day,-8,@ReportRunDate)
           , @End   =  DATEADD(day,-1,@ReportRunDate)
      

	  select @ReportRunDate, @Start, @End

	DELETE wky.Report_WeeklyTech_v6

​	EXEC [wky].[populateWeeklyReportTech_v6]  @startDate = @Start, @endDate = @End, @Country = @Country
	
	--select * from wky.Report_WeeklyTech_v6
​
  END
