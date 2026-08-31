# Cognitive Index

A timed IQ-style reasoning assessment on two platforms that share one item
bank, one scoring rule and one leaderboard:

- a **Flutter app** for Android, iOS, web, macOS, Windows and Linux;
- an **ASP.NET Core site** (Razor Pages, Dapper over SQL Server, clean
  architecture, CQRS via MediatR) in [`web/`](web/README.md).

Both present items from four reasoning domains, score them on the conventional
deviation scale (mean 100, SD 15), issue a certificate at its own permanent
address, and rank everyone on a single shared board.

## What it does

- **Two formats** — a full 32-item / 25-minute assessment, or a balanced
  16-item / 12-minute short form.
- **A different test every time** — each sitting is a fresh sample from a
  65-item pool, and two consecutive sittings share no questions at all.
- **An info page** explaining how a sitting is assembled, how the score is
  computed, where the questions came from, and what the number cannot tell
  you.
- **Four domains** — numerical (number series, quantitative reasoning), verbal
  (analogies, classification), logical (deduction, inference), and spatial
  (Raven's-style progressive matrices).
- **A hard clock** — the test submits itself when time runs out, and
  unanswered items are marked incorrect.
- **Free navigation** — move back and forth, or open a question map to see
  what is still unanswered and jump straight to it.
- **A real result** — a deviation-scale index, the matching percentile drawn
  on the reference distribution, a per-domain breakdown, and a full review of
  every item with the answer and an explanation of why.
- **Local history** — every attempt is stored on the device with a trend line
  across sittings. Nothing is uploaded unless you choose to submit.
- **A shared leaderboard** — submit a sitting from either platform and it lands
  on the same board, with a certificate at its own permanent link.

## How a sitting is assembled

Sampling at random would make two scores incomparable — draw an easy set one
day and a hard set the next and the number moves for reasons unrelated to the
person taking it. So the draw follows a fixed **blueprint**: a set number of
items at each difficulty, from each domain, every time.

| Difficulty | Full | Quick |
|---|---|---|
| 1 · easiest | 1 | — |
| 2 | 1 | 1 |
| 3 | 2 | 1 |
| 4 | 2 | 1 |
| 5 · hardest | 2 | 1 |
| **Items** | **32** | **16** |
| **Points available** | **108** | **56** |

Counts are per domain; multiply by four for the totals. The item mix changes
between sittings; the shape of the test does not.

Every difficulty band holds at least twice what a sitting draws from it. That
surplus is spent on freshness: the draw holds back every item the previous
sitting used, so **two consecutive sittings share no questions**. Seeing an
item again would measure recall rather than reasoning. If the pool is ever
edited below that threshold the draw falls back to repeating items rather than
returning a short test, and a test asserts the threshold still holds.

The short form skips difficulty 1 — items almost everyone answers correctly
separate nobody, so with four items per domain to spend they are spent higher
up the range.

## Two platforms, one source of truth

The Dart bank in `lib/data/question_bank.dart` is the source. It is exported to
`shared/questions.json`, which the ASP.NET site builds its own pool from:

```bash
dart run tool/export_questions.dart
```

`test/question_export_test.dart` fails if the committed export has drifted from
the Dart source, and the site refuses to start if the export's scoring
constants disagree with the ones compiled into its `DeviationScale`. So the two
platforms cannot quietly start asking different questions or scoring them
differently — and `test_live/` proves it end to end by scoring the same sitting
on both and asserting the numbers match.

## The leaderboard, and why it is hard to forge

Neither platform ever sends a score. The site scores everything itself:

- the **web** test is issued by the server, which remembers the items it showed;
- the **app** draws its own sitting so it works offline, so it submits the item
  ids it used with the answers — and the server checks that set really is a
  draw the blueprint could have produced before scoring it.

A payload carrying `"score": 145` is ignored. Only full 32-item sittings are
ranked, so a lucky short form cannot outrank a real sitting, and where an email
is given only that person's best attempt is kept.

See [`web/README.md`](web/README.md) for the architecture and the API.

## Matrix items are drawn, not shipped

The spatial items are Raven's-style progressive matrices, and each one is
authored as data — a `FigureSpec` per cell describing shape, count, fill,
orientation and centre dot — then rendered by a `CustomPainter`. The puzzles
are therefore resolution-independent, adapt to light and dark themes, and the
rules that generate them can be checked by tests instead of by eye.

`test/matrix_rules_test.dart` encodes each item's rule independently and
re-derives the answer from the grid, asserting that the authored key matches
and that exactly one option satisfies the rule. An authoring slip fails the
build rather than reaching a candidate.

## How scoring works

Each item carries a weight equal to its difficulty (1-5), so a hard item is
worth more than an easy one. The weighted points earned are divided by the
points available, and that proportion is mapped onto the deviation scale:

```
z     = (proportion - 0.55) / 0.19
index = round(100 + 15 * z), clamped to [55, 145]
```

The percentile comes from the standard normal CDF of the resulting index,
using an Abramowitz & Stegun erf approximation (error below 1.5e-7).

**The reference constants are assumed, not measured.** This app has no norming
sample, so the index is a self-consistent yardstick for comparing your own
attempts — not a clinical measurement, and not a diagnosis. The difficulty
ratings are editorial judgement rather than measured item difficulty, and since
difficulty is also the scoring weight, those judgements feed straight into the
result. The in-app info page states all of this.

## Layout

```
lib/
  main.dart                    app entry and theming
  navigation.dart              route observer used to refresh the home screen
  models/
    figure_spec.dart           declarative description of a matrix figure
    question.dart              sealed Question: TextQuestion | MatrixQuestion
    attempt.dart               a stored, completed attempt
  data/
    question_bank.dart         the 65-item pool and the draw
    test_blueprint.dart        how many items a sitting takes per difficulty
  services/
    scoring.dart               weighting, the deviation scale, erf/normal CDF
    history_store.dart         local persistence via shared_preferences
  state/test_controller.dart   answer sheet, cursor and countdown
  screens/                     home, quiz, result, review, history, about
  widgets/                     figure painter, matrix grid, bell curve, tiles
```

## Where the questions come from

Every item was written for this app. The number series use standard
mathematics; the logic items use standard argument forms. The analogies and the
matrices are original.

Nothing is copied from Raven's Progressive Matrices, the Wechsler scales, or
any commercial or clinical instrument — those are copyrighted, and the clinical
ones depend on their items staying out of circulation. The matrices are
Raven-*style*, not Raven's.

Items that are famous published research problems were deliberately kept out.
An earlier revision included two items from Frederick's Cognitive Reflection
Test and Wason's selection task; because recognising them hands a large,
heavily-weighted score to anyone who has met them before, they were replaced
with original items testing the same constructs — intuition override, and
falsification of a conditional rule.

## Running it

The app:

```bash
flutter pub get
flutter run                 # or: flutter run -d chrome
```

Point it at a ranking service with `--dart-define`:

```bash
flutter run --dart-define=IQ_API_BASE_URL=http://127.0.0.1:5080
```

The site (which is that service):

```bash
cd web && docker compose up          # SQL Server + the site on :5080
# or, against your own SQL Server:
dotnet run --project web/src/IqTest.Web
```

## Tests

```bash
flutter analyze && flutter test      # the app
cd web && dotnet test                # the site
```

Cross-platform checks need both running, so they sit outside the default run:

```bash
dotnet run --project web/src/IqTest.Web &
flutter test test_live --dart-define=IQ_API_BASE_URL=http://127.0.0.1:5080
```

The suite covers the scoring maths against published normal-distribution
values, item-bank integrity, the matrix rules, the controller's clock and
answer sheet, local persistence, and an end-to-end pass through the app from
the home screen to a scored result and its review.

Three properties of the draw are asserted directly, since they are what make
the scores mean anything:

- every sitting matches the blueprint exactly, whatever the seed;
- every sitting offers the same number of weighted points;
- two consecutive sittings share no items, checked across both formats and
  thirty seeds, and again end-to-end by taking two tests in the widget test.
