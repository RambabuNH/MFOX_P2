CREATE TABLE [eng].[Report_WeeklyEng_v1] (
    [CreatedDtm]      DATETIME2 (0)  CONSTRAINT [con_Report_WeeklyEng_v1_createdDtm] DEFAULT (getutcdate()) NULL,
    [Country]         VARCHAR (64)   NULL,
    [L1]              VARCHAR (255)  NULL,
    [L3]              VARCHAR (255)  NULL,
    [StartDate]       DATE           NULL,
    [EndDate]         DATE           NULL,
    [ReportDays]      INT            NULL,
    [FridgeId]        BIGINT         NULL,
    [FridgeShortSN]   VARCHAR (33)   NULL,
    [FridgeType]      CHAR (1)       NULL,
    [Message]         VARCHAR (255)  NULL,
    [Detail]          VARCHAR (255)  NULL,
    [value]           VARCHAR (255)  NULL,
    [EventTime]       DATETIME2 (0)  NULL,
    [RecCount]        INT            NULL,
    [Link]            VARCHAR (1024) NULL,
    [MessageInterval] VARCHAR (5)    NOT NULL,
    [GLink]           VARCHAR (1024) NULL
);

