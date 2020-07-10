CREATE EXTERNAL TABLE [dbo].[AspNetUserRoles] (
    [UserId] NVARCHAR (128) NOT NULL,
    [RoleId] NVARCHAR (128) NOT NULL
)
    WITH (
    DATA_SOURCE = [MyElasticDBQueryDataSrc]
    );

