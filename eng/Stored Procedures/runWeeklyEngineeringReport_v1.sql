​
/*
select * from [Eng].[Report_WeeklyEng_v1]

exec [eng].[runWeeklyEngineeringReport_v1]
​
*/
​
​
CREATE PROCEDURE [eng].[runWeeklyEngineeringReport_v1] 

AS
  BEGIN
      SET NOCOUNT ON

	  declare @ReportRunDate date = getutcdate()

​
	  DECLARE @Start  Date
	        , @End    Date
			, @Count  int
     
      declare @Country varchar(32) = 'All'
	  SELECT @Start =  DATEADD(day,-7,@ReportRunDate)
           , @End   =  DATEADD(day,+1,@ReportRunDate)
      

	select @ReportRunDate, @Start, @End

	DELETE [Eng].[Report_WeeklyEng_v1] where StartDate = @Start

​	EXEC [eng].[populateWeeklyEng_v1]  @startDate = @Start, @endDate = @End, @Country = @Country
	
	--select * from [Eng].[Report_WeeklyEng_v1]
​
  END
