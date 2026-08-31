import 'question.dart';

/// A country the shared service will accept for the leaderboard.
class Country {
  const Country({required this.code, required this.name, required this.flag});

  final String code;
  final String name;
  final String flag;

  static Country fromJson(Map<String, dynamic> json) => Country(
    code: json['code'] as String,
    name: json['name'] as String,
    flag: json['flag'] as String? ?? '',
  );
}

/// What the service gives back once it has scored a submission.
///
/// Note that the score here is the server's, not the one computed on device.
/// The two agree because both platforms share the same bank and the same
/// scoring constants — but the leaderboard only ever trusts its own.
class SubmissionResult {
  const SubmissionResult({
    required this.certificateSlug,
    required this.certificateUrl,
    required this.score,
    required this.percentile,
    required this.band,
    required this.correct,
    required this.total,
    required this.isRanked,
    this.rank,
  });

  final String certificateSlug;
  final String certificateUrl;
  final int score;
  final double percentile;
  final String band;
  final int correct;
  final int total;
  final bool isRanked;
  final int? rank;

  static SubmissionResult fromJson(Map<String, dynamic> json) =>
      SubmissionResult(
        certificateSlug: json['certificateSlug'] as String,
        certificateUrl: json['certificateUrl'] as String,
        score: (json['score'] as num).toInt(),
        percentile: (json['percentile'] as num).toDouble(),
        band: json['band'] as String,
        correct: (json['correct'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        isRanked: json['isRanked'] as bool? ?? false,
        rank: (json['rank'] as num?)?.toInt(),
      );
}

/// One row of the shared board.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.countryCode,
    required this.country,
    required this.flag,
    required this.score,
    required this.correct,
    required this.total,
    required this.platform,
    required this.certificateSlug,
  });

  final int rank;
  final String displayName;
  final String countryCode;
  final String country;
  final String flag;
  final int score;
  final int correct;
  final int total;
  final String platform;
  final String certificateSlug;

  /// True for entries set on a phone rather than in a browser.
  bool get isMobile => platform.toLowerCase() == 'mobile';

  static LeaderboardEntry fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num).toInt(),
        displayName: json['displayName'] as String,
        countryCode: json['countryCode'] as String? ?? '',
        country: json['country'] as String? ?? '',
        flag: json['flag'] as String? ?? '',
        score: (json['score'] as num).toInt(),
        correct: (json['correct'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        platform: json['platform'] as String? ?? 'Web',
        certificateSlug: json['certificateSlug'] as String? ?? '',
      );
}

class LeaderboardPage {
  const LeaderboardPage({
    required this.rows,
    required this.page,
    required this.totalPages,
    required this.totalRows,
  });

  final List<LeaderboardEntry> rows;
  final int page;
  final int totalPages;
  final int totalRows;

  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  static LeaderboardPage fromJson(Map<String, dynamic> json) => LeaderboardPage(
    rows: (json['rows'] as List)
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false),
    page: (json['page'] as num).toInt(),
    totalPages: (json['totalPages'] as num).toInt(),
    totalRows: (json['totalRows'] as num).toInt(),
  );
}

/// The details someone gives to appear on the board.
class ParticipantDetails {
  const ParticipantDetails({
    required this.displayName,
    required this.countryCode,
    this.email,
  });

  final String displayName;
  final String countryCode;
  final String? email;
}

/// One answered item, as sent for scoring.
class SubmittedAnswer {
  const SubmittedAnswer(this.questionId, this.selectedIndex);

  final String questionId;
  final int? selectedIndex;

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedIndex': selectedIndex,
  };
}

/// Convenience for turning a finished sitting into a submission payload.
List<SubmittedAnswer> answersFor(
  List<Question> questions,
  List<int?> answers,
) => [
  for (var i = 0; i < questions.length; i++)
    SubmittedAnswer(questions[i].id, answers[i]),
];
