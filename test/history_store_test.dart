import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/models/attempt.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/services/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Attempt _attempt(int iq, {DateTime? when, List<String>? itemIds}) => Attempt(
  takenAt: when ?? DateTime(2026, 3, 4, 10, 30),
  iq: iq,
  correct: 20,
  total: 32,
  duration: const Duration(minutes: 12, seconds: 34),
  categoryAccuracy: const {
    QuestionCategory.numerical: 0.75,
    QuestionCategory.spatial: 0.5,
  },
  itemIds: itemIds ?? const ['n1', 'v1', 'l1', 's1'],
);

void main() {
  late HistoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = HistoryStore();
  });

  test('starts empty', () async {
    expect(await store.load(), isEmpty);
  });

  test('round-trips an attempt', () async {
    await store.add(_attempt(118));
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    final attempt = loaded.single;
    expect(attempt.iq, 118);
    expect(attempt.correct, 20);
    expect(attempt.total, 32);
    expect(attempt.duration, const Duration(minutes: 12, seconds: 34));
    expect(attempt.takenAt, DateTime(2026, 3, 4, 10, 30));
    expect(
      attempt.categoryAccuracy[QuestionCategory.numerical],
      closeTo(0.75, 1e-9),
    );
    expect(
      attempt.categoryAccuracy.containsKey(QuestionCategory.verbal),
      isFalse,
      reason: 'domains the test did not sample should not be invented',
    );
  });

  test('keeps the newest attempt first', () async {
    await store.add(_attempt(100));
    await store.add(_attempt(110));
    final loaded = await store.add(_attempt(120));

    expect(loaded.map((a) => a.iq), [120, 110, 100]);
    expect((await store.load()).map((a) => a.iq), [120, 110, 100]);
  });

  test('caps the stored history', () async {
    for (var i = 0; i < HistoryStore.maxAttempts + 8; i++) {
      await store.add(_attempt(90 + (i % 30)));
    }
    expect(await store.load(), hasLength(HistoryStore.maxAttempts));
  });

  test('round-trips the item ids a sitting used', () async {
    await store.add(_attempt(110, itemIds: ['n4', 's13', 'v9']));
    expect((await store.load()).single.itemIds, ['n4', 's13', 'v9']);
  });

  test('recentItemIds reports the last sitting by default', () async {
    await store.add(_attempt(100, itemIds: ['a', 'b']));
    await store.add(_attempt(105, itemIds: ['c', 'd']));

    expect(await store.recentItemIds(), {'c', 'd'});
    expect(await store.recentItemIds(sittings: 2), {'a', 'b', 'c', 'd'});
  });

  test('recentItemIds is empty with no history', () async {
    expect(await store.recentItemIds(), isEmpty);
  });

  test('an attempt stored before item ids were recorded still loads', () async {
    SharedPreferences.setMockInitialValues({
      'iq_test_attempts_v1':
          '[{"takenAt":"2026-01-02T09:00:00.000","iq":112,"correct":21,'
          '"total":32,"durationSeconds":700,"categoryAccuracy":{}}]',
    });
    final loaded = await HistoryStore().load();
    expect(loaded.single.iq, 112);
    expect(loaded.single.itemIds, isEmpty);
    expect(await HistoryStore().recentItemIds(), isEmpty);
  });

  test('clear removes everything', () async {
    await store.add(_attempt(105));
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('survives a corrupt payload instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      'iq_test_attempts_v1': 'not json at all',
    });
    expect(await HistoryStore().load(), isEmpty);
  });
}
