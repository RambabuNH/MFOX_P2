CREATE EXTERNAL TABLE [dbo].[AspNetRoles] (
    [Id] NVARCHAR (128) NOT NULL,
    [Name] NVARCHAR (256) NOT NULL
)
    WITH (
    DATA_SOURCE = [MyElasticDBQueryDataSrc]
    );

