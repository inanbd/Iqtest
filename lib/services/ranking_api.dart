import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/question.dart';
import '../models/ranking.dart';

/// Raised when the shared service refuses or cannot answer a request.
class RankingApiException implements Exception {
  const RankingApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the shared ranking service that also serves the website.
///
/// The app never sends a score. It sends the items it drew and what was
/// answered, and the service scores that against its own copy of the bank —
/// which is why an offline app can still be on the same board as the web.
class RankingApi {
  RankingApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalise(baseUrl ?? defaultBaseUrl);

  /// Override at build time:
  ///
  ///     flutter run --dart-define=IQ_API_BASE_URL=https://your-host
  ///
  /// The default is the loopback address an Android emulator uses to reach
  /// the host machine, which is the common case while developing.
  static const String defaultBaseUrl = String.fromEnvironment(
    'IQ_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5080',
  );

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _baseUrl;

  static String _normalise(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  String get baseUrl => _baseUrl;

  /// The public address of a certificate, for sharing or opening.
  String certificateUrl(String slug) => '$_baseUrl/certificate/$slug';

  Future<List<Country>> countries() async {
    final json = await _get('/api/countries') as List;
    return json
        .cast<Map<String, dynamic>>()
        .map(Country.fromJson)
        .toList(growable: false);
  }

  Future<LeaderboardPage> leaderboard({
    String? countryCode,
    int page = 1,
    int pageSize = 25,
  }) async {
    final query = {
      if (countryCode != null && countryCode.isNotEmpty) 'country': countryCode,
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final json = await _get('/api/leaderboard', query) as Map<String, dynamic>;
    return LeaderboardPage.fromJson(json);
  }

  /// Sends a finished sitting for scoring.
  ///
  /// [participant] may be null, which files the attempt and returns a
  /// certificate without putting anyone on the board.
  Future<SubmissionResult> submit({
    required bool isFullTest,
    required List<Question> questions,
    required List<int?> answers,
    required Duration duration,
    ParticipantDetails? participant,
  }) async {
    final payload = {
      'format': isFullTest ? 'Full' : 'Quick',
      'answers': [
        for (final answer in answersFor(questions, answers)) answer.toJson(),
      ],
      'durationSeconds': duration.inSeconds,
      if (participant != null) ...{
        'displayName': participant.displayName,
        'countryCode': participant.countryCode,
        if (participant.email != null && participant.email!.isNotEmpty)
          'email': participant.email,
      },
    };

    final json = await _post('/api/attempts', payload) as Map<String, dynamic>;
    return SubmissionResult.fromJson(json);
  }

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _send(
      () => _client.get(uri, headers: const {'Accept': 'application/json'}),
    );
  }

  Future<Object?> _post(String path, Object body) async {
    return _send(
      () => _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<Object?> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const RankingApiException(
        'The ranking service did not answer in time. Check your connection and try again.',
      );
    } on Exception {
      throw RankingApiException(
        'Could not reach the ranking service at $_baseUrl.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    // The service explains a refusal in the body; surface that rather than a code.
    throw RankingApiException(_errorFrom(response));
  }

  static String _errorFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return 'The ranking service refused the request (${response.statusCode}).';
  }

  void dispose() => _client.close();
}
