/// How many items one sitting draws from each difficulty, within every domain.
///
/// Holding this fixed is what makes two sittings comparable. The items vary
/// from one attempt to the next, but the shape of the test — how many easy,
/// medium and hard items it contains, and therefore how many weighted points
/// are available — does not.
class TestBlueprint {
  const TestBlueprint(this.perDifficulty);

  /// Difficulty (1..5) to the number of items drawn at that difficulty, per
  /// domain. A difficulty absent from the map is not sampled at all.
  final Map<int, int> perDifficulty;

  /// The full sitting: eight items per domain spanning the whole range.
  static const TestBlueprint full = TestBlueprint({
    1: 1,
    2: 1,
    3: 2,
    4: 2,
    5: 2,
  });

  /// The short form: one item per domain at each difficulty above the
  /// easiest band, which carries the least information about ability.
  static const TestBlueprint quick = TestBlueprint({2: 1, 3: 1, 4: 1, 5: 1});

  /// Items drawn from a single domain.
  int get itemsPerCategory =>
      perDifficulty.values.fold(0, (sum, count) => sum + count);

  /// Weighted points available from a single domain.
  int get weightPerCategory => perDifficulty.entries.fold(
    0,
    (sum, entry) => sum + entry.key * entry.value,
  );

  /// Total items, across [categoryCount] domains.
  int itemCount(int categoryCount) => itemsPerCategory * categoryCount;

  /// Total weighted points available, across [categoryCount] domains.
  int maxWeight(int categoryCount) => weightPerCategory * categoryCount;

  /// The smallest pool that lets a draw avoid everything the previous sitting
  /// used: twice what each cell contributes.
  int poolNeededFor(int difficulty) => (perDifficulty[difficulty] ?? 0) * 2;
}
