-- Idempotent: safe to run on every start.
IF OBJECT_ID(N'dbo.Participants', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Participants
    (
        Id           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Participants PRIMARY KEY,
        DisplayName  NVARCHAR(40)     NOT NULL,
        CountryCode  CHAR(2)          NOT NULL,
        Email        NVARCHAR(254)    NULL,
        CreatedAtUtc DATETIMEOFFSET(3) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.Attempts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Attempts
    (
        Id                 UNIQUEIDENTIFIER  NOT NULL CONSTRAINT PK_Attempts PRIMARY KEY,
        CertificateSlug    VARCHAR(22)       NOT NULL,
        ParticipantId      UNIQUEIDENTIFIER  NULL,
        Format             TINYINT           NOT NULL,
        Platform           TINYINT           NOT NULL,
        ScoreIndex         INT               NOT NULL,
        Percentile         DECIMAL(5, 2)     NOT NULL,
        CorrectCount       INT               NOT NULL,
        TotalCount         INT               NOT NULL,
        WeightedPoints     INT               NOT NULL,
        MaxWeightedPoints  INT               NOT NULL,
        DurationSeconds    INT               NOT NULL,
        IsRanked           BIT               NOT NULL,
        CompletedAtUtc     DATETIMEOFFSET(3) NOT NULL,
        CONSTRAINT FK_Attempts_Participants FOREIGN KEY (ParticipantId) REFERENCES dbo.Participants (Id)
    );

    -- The certificate address is the public key for an attempt, so it must be
    -- unique and is looked up on every certificate view.
    CREATE UNIQUE INDEX UX_Attempts_CertificateSlug ON dbo.Attempts (CertificateSlug);

    -- Covers the leaderboard's ordering: best score first, then the tie-breaks.
    CREATE INDEX IX_Attempts_Ranking
        ON dbo.Attempts (IsRanked, ScoreIndex DESC, WeightedPoints DESC, DurationSeconds ASC, CompletedAtUtc ASC)
        INCLUDE (ParticipantId, CertificateSlug, Format, Platform, CorrectCount, TotalCount, Percentile);
END;
GO

IF OBJECT_ID(N'dbo.AttemptCategoryScores', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AttemptCategoryScores
    (
        AttemptId UNIQUEIDENTIFIER NOT NULL,
        Category  TINYINT          NOT NULL,
        Correct   INT              NOT NULL,
        Total     INT              NOT NULL,
        CONSTRAINT PK_AttemptCategoryScores PRIMARY KEY (AttemptId, Category),
        CONSTRAINT FK_AttemptCategoryScores_Attempts FOREIGN KEY (AttemptId)
            REFERENCES dbo.Attempts (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.AttemptAnswers', N'U') IS NULL
BEGIN
    -- Kept so a score can be re-derived and audited after the fact.
    CREATE TABLE dbo.AttemptAnswers
    (
        AttemptId     UNIQUEIDENTIFIER NOT NULL,
        Position      INT              NOT NULL,
        QuestionId    VARCHAR(16)      NOT NULL,
        SelectedIndex INT              NULL,
        IsCorrect     BIT              NOT NULL,
        CONSTRAINT PK_AttemptAnswers PRIMARY KEY (AttemptId, Position),
        CONSTRAINT FK_AttemptAnswers_Attempts FOREIGN KEY (AttemptId)
            REFERENCES dbo.Attempts (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.Sittings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sittings
    (
        Id            UNIQUEIDENTIFIER  NOT NULL CONSTRAINT PK_Sittings PRIMARY KEY,
        Format        TINYINT           NOT NULL,
        VisitorKey    VARCHAR(64)       NULL,
        StartedAtUtc  DATETIMEOFFSET(3) NOT NULL,
        ExpiresAtUtc  DATETIMEOFFSET(3) NOT NULL,
        SubmittedAtUtc DATETIMEOFFSET(3) NULL
    );

    -- Finds the items a returning visitor last saw, so the draw can avoid them.
    CREATE INDEX IX_Sittings_Visitor ON dbo.Sittings (VisitorKey, StartedAtUtc DESC);
END;
GO

IF OBJECT_ID(N'dbo.SittingItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SittingItems
    (
        SittingId     UNIQUEIDENTIFIER NOT NULL,
        Position      INT              NOT NULL,
        QuestionId    VARCHAR(16)      NOT NULL,
        SelectedIndex INT              NULL,
        CONSTRAINT PK_SittingItems PRIMARY KEY (SittingId, Position),
        CONSTRAINT FK_SittingItems_Sittings FOREIGN KEY (SittingId)
            REFERENCES dbo.Sittings (Id) ON DELETE CASCADE
    );
END;
GO
