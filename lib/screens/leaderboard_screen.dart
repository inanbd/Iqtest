import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ranking.dart';
import '../services/ranking_api.dart';

/// The shared board, the same one the website shows.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.highlightSlug, RankingApi? api})
    : _api = api;

  /// Ringed on the list, so someone arriving from their own result can find it.
  final String? highlightSlug;

  final RankingApi? _api;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final RankingApi _api = widget._api ?? RankingApi();
  late Future<LeaderboardPage> _page;
  int _pageNumber = 1;
  String? _countryCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget._api == null) _api.dispose();
    super.dispose();
  }

  void _load() {
    _page = _api.leaderboard(countryCode: _countryCode, page: _pageNumber);
  }

  void _goTo(int page) {
    setState(() {
      _pageNumber = page;
      _load();
    });
  }

  Future<void> _openCertificate(String slug) async {
    final uri = Uri.parse(_api.certificateUrl(slug));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _goTo(_pageNumber),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<LeaderboardPage>(
          future: _page,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _Message(
                icon: Icons.cloud_off_rounded,
                title: 'The board is out of reach',
                body: '${snapshot.error}',
                action: FilledButton(
                  onPressed: () => _goTo(_pageNumber),
                  child: const Text('Try again'),
                ),
              );
            }

            final page = snapshot.data!;
            if (page.rows.isEmpty) {
              return const _Message(
                icon: Icons.emoji_events_outlined,
                title: 'Nobody has ranked yet',
                body: 'Take the full assessment and submit it to be first.',
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${page.totalRows} ranked '
                          '${page.totalRows == 1 ? 'entry' : 'entries'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_countryCode != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _countryCode = null;
                            _pageNumber = 1;
                            _load();
                          }),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text(_countryCode!),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: page.rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _EntryTile(
                      entry: page.rows[index],
                      highlighted:
                          page.rows[index].certificateSlug ==
                          widget.highlightSlug,
                      onTapCertificate: _openCertificate,
                      onTapCountry: (code) => setState(() {
                        _countryCode = code;
                        _pageNumber = 1;
                        _load();
                      }),
                    ),
                  ),
                ),
                if (page.totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: page.hasPrevious
                              ? () => _goTo(_pageNumber - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text('Page ${page.page} of ${page.totalPages}'),
                        IconButton(
                          onPressed: page.hasNext
                              ? () => _goTo(_pageNumber + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.highlighted,
    required this.onTapCertificate,
    required this.onTapCountry,
  });

  final LeaderboardEntry entry;
  final bool highlighted;
  final ValueChanged<String> onTapCertificate;
  final ValueChanged<String> onTapCountry;

  static const List<Color> _medals = [
    Color(0xFFB8860B),
    Color(0xFF8C8C9A),
    Color(0xFFA0693C),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = entry.rank <= 3 ? _medals[entry.rank - 1] : null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlighted
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: entry.certificateSlug.isEmpty
            ? null
            : () => onTapCertificate(entry.certificateSlug),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: medal ?? scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => onTapCountry(entry.countryCode),
                      child: Text(
                        '${entry.flag} ${entry.country}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.score}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '${entry.correct}/${entry.total}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                entry.isMobile
                    ? Icons.phone_iphone_rounded
                    : Icons.language_rounded,
                size: 16,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
