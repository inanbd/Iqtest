# Cognitive Index

A timed IQ-style reasoning assessment built with Flutter. It presents items
from four reasoning domains, scores them on the conventional deviation scale
(mean 100, SD 15), and keeps a local history so you can compare sittings.

Runs on Android, iOS, web, macOS, Windows and Linux from one codebase.

## What it does

- **Two formats** — a full 32-item / 25-minute assessment, or a balanced
  16-item / 12-minute short form that draws four items from each domain and
  spreads them across the difficulty range.
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
  across sittings. Nothing is uploaded anywhere.

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
attempts — not a clinical measurement, and not a diagnosis. The app says so on
both the home and the results screen.

## Layout

```
lib/
  main.dart                    app entry and theming
  navigation.dart              route observer used to refresh the home screen
  models/
    figure_spec.dart           declarative description of a matrix figure
    question.dart              sealed Question: TextQuestion | MatrixQuestion
    attempt.dart               a stored, completed attempt
  data/question_bank.dart      the 32 authored items and the two test formats
  services/
    scoring.dart               weighting, the deviation scale, erf/normal CDF
    history_store.dart         local persistence via shared_preferences
  state/test_controller.dart   answer sheet, cursor and countdown
  screens/                     home, quiz, result, review, history
  widgets/                     figure painter, matrix grid, bell curve, tiles
```

## Running it

```bash
flutter pub get
flutter run                 # or: flutter run -d chrome
```

## Tests

```bash
flutter analyze
flutter test
```

The suite covers the scoring maths against published normal-distribution
values, item-bank integrity, the matrix rules, the controller's clock and
answer sheet, local persistence, and an end-to-end pass through the app from
the home screen to a scored result and its review.
