CREATE TABLE [wky].[Report_WeeklyEng_v1] (
    [CreatedDtm]    DATETIME2 (0)  CONSTRAINT [con_Report_WeeklyEng_v1_createdDtm] DEFAULT (getutcdate()) NULL,
    [Priority]      VARCHAR (255)  NULL,
    [Country]       VARCHAR (64)   NULL,
    [L1]            VARCHAR (255)  NULL,
    [L3]            VARCHAR (255)  NULL,
    [StartDate]     DATE           NULL,
    [EndDate]       DATE           NULL,
    [ReportDays]    INT            NULL,
    [FridgeId]      BIGINT         NULL,
    [FridgeShortSN] VARCHAR (33)   NULL,
    [FridgeType]    CHAR (1)       NULL,
    [Deployed]      CHAR (1)       NULL,
    [commDte]       DATE           NULL,
    [Message]       VARCHAR (255)  NULL,
    [Detail]        VARCHAR (255)  NULL,
    [value]         FLOAT (53)     NULL,
    [Link]          VARCHAR (1024) NULL
);

