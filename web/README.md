# Cognitive Index — web

An ASP.NET Core 9 site that runs the same IQ test as the Flutter app, ranks
everyone on one shared board, and issues a certificate at its own permanent
address.

Razor Pages for the site, minimal API for the mobile app, Dapper over SQL
Server (no EF), clean architecture, CQRS through MediatR.

## Layout

```
src/
  IqTest.Domain/          entities, the deviation scale, the draw — no dependencies
  IqTest.Application/     CQRS commands, queries and their handlers; ports
  IqTest.Infrastructure/  Dapper + SQL Server, the shared bank loader
  IqTest.Web/             Razor Pages, the JSON API, composition root
tests/
  IqTest.Domain.Tests/          pure, fast
  IqTest.Application.Tests/     handlers against in-memory ports
  IqTest.Infrastructure.Tests/  real SQL Server
  IqTest.Web.Tests/             the real app hosted in memory
```

Dependencies point inwards only: `Domain ← Application ← Infrastructure`, with
`Web` as the composition root. `Application` names what it needs as interfaces
(`IQuestionBank`, `IAttemptRepository`, `ILeaderboardReadStore`, …) and
`Infrastructure` supplies them, so nothing inside knows SQL Server exists.

## CQRS

Writes go through commands that load and mutate domain entities:
`StartSittingCommand`, `AnswerQuestionCommand`, `SubmitSittingCommand`,
`SubmitExternalAttemptCommand`.

Reads go through queries that return flat view models straight from SQL,
without rehydrating an entity: `GetSittingQuery`, `GetCertificateQuery`,
`GetLeaderboardQuery`, `GetLeaderboardStatsQuery`, `GetCountryStandingsQuery`.

The split is real rather than nominal — `ILeaderboardReadStore` returns
`LeaderboardRow` records the write side never touches, and the ranking rules
live in one SQL projection rather than in C# over loaded aggregates.

## Where the questions come from

Both platforms build their bank from `../shared/questions.json`, exported from
the Flutter project's Dart source:

```bash
dart run tool/export_questions.dart     # from the repository root
```

A Dart test fails if the committed export drifts from the Dart bank, and the
site refuses to start if the export's scoring constants disagree with the ones
compiled into `DeviationScale`. So the two platforms cannot silently diverge.

## How the leaderboard is kept honest

**No score is ever accepted from a client.**

- The web test is issued by the server, which stores the items it showed and
  scores the answers itself.
- The mobile app draws its own sitting so it can work offline, so it submits
  the item ids it used along with the answers. `QuestionPool.ValidateSitting`
  checks that set really is a draw the blueprint could have produced — right
  count, no repeats, correct number at each difficulty in each domain — before
  scoring it against the server's own copy of the bank.

A payload carrying `"score": 145` is simply ignored; the reply is whatever the
server worked out. There are no accounts, so this is not proof against someone
who already knows the answers, but the number beside a name is always one the
server computed.

Only full 32-item sittings are ranked, so a lucky short form cannot outrank a
real sitting. Where an email was given, only that person's best attempt is kept.

## Running it

With Docker:

```bash
cd web && docker compose up
```

Against your own SQL Server:

```bash
dotnet run --project src/IqTest.Web
```

Configure with `Database:ConnectionString` and `QuestionBank:Path` (see
`appsettings.json`). The app creates the database if it does not exist and
applies the idempotent scripts in `Infrastructure/Persistence/Migrations` on
every start-up — there is no EF migrations runner to invoke.

## Tests

```bash
dotnet test
```

The Infrastructure and Web suites need SQL Server on `127.0.0.1,1433` (override
with `IQTEST_SQL_MASTER`). Without one they skip rather than fail, so the
Domain and Application suites still run anywhere.

## API

| Method | Route | Purpose |
|---|---|---|
| `GET` | `/api/countries` | The country list for the join form |
| `POST` | `/api/attempts` | Submit a client-drawn sitting for scoring |
| `GET` | `/api/leaderboard` | A page of the board (`country`, `page`, `pageSize`) |
| `GET` | `/api/leaderboard/stats` | Totals across the board |
| `GET` | `/api/leaderboard/countries` | Countries ranked by average |
| `GET` | `/api/certificates/{slug}` | A certificate by its public address |
