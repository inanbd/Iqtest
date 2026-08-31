import 'package:flutter_test/flutter_test.dart';
import 'package:iq_test/models/attempt.dart';
import 'package:iq_test/models/question.dart';
import 'package:iq_test/services/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Attempt _attempt(int iq, {DateTime? when}) => Attempt(
  takenAt: when ?? DateTime(2026, 3, 4, 10, 30),
  iq: iq,
  correct: 20,
  total: 32,
  duration: const Duration(minutes: 12, seconds: 34),
  categoryAccuracy: const {
    QuestionCategory.numerical: 0.75,
    QuestionCategory.spatial: 0.5,
  },
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
