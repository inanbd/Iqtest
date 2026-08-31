import 'package:flutter/material.dart';

import '../models/ranking.dart';
import '../services/ranking_api.dart';

/// Collects the little the board asks for, then submits.
///
/// Returns the service's own result, or null if the sheet was dismissed.
class SubmitScoreSheet extends StatefulWidget {
  const SubmitScoreSheet({
    super.key,
    required this.api,
    required this.onSubmit,
    required this.isRankable,
  });

  final RankingApi api;

  /// Performs the submission with the details given, or null for anonymous.
  final Future<SubmissionResult> Function(ParticipantDetails?) onSubmit;

  /// False for the short form, which is scored but never ranked.
  final bool isRankable;

  @override
  State<SubmitScoreSheet> createState() => _SubmitScoreSheetState();
}

class _SubmitScoreSheetState extends State<SubmitScoreSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  late Future<List<Country>> _countries;
  String? _countryCode;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countries = widget.api.countries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool anonymous}) async {
    if (!anonymous && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.onSubmit(
        anonymous
            ? null
            : ParticipantDetails(
                displayName: _nameController.text.trim(),
                countryCode: _countryCode!,
                email: _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
              ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } on RankingApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = exception.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join the global board',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your answers are sent for scoring and you get a certificate with '
                'its own link. The web and the app share one board.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (!widget.isRankable) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.info_outline_rounded,
                  text:
                      'The short form is not ranked. You will still get a score '
                      'and a certificate.',
                  color: theme.colorScheme.primary,
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'How you want to appear',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'A name is needed to appear on the board.'
                    : null,
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Country>>(
                future: _countries,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Notice(
                      icon: Icons.cloud_off_rounded,
                      text:
                          'Could not load the country list. '
                          '${snapshot.error}',
                      color: theme.colorScheme.error,
                    );
                  }
                  final countries = snapshot.data;
                  return DropdownButtonFormField<String>(
                    initialValue: _countryCode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Country',
                      border: const OutlineInputBorder(),
                      suffixIcon: countries == null
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    items: [
                      for (final country in countries ?? const <Country>[])
                        DropdownMenuItem(
                          value: country.code,
                          child: Text(
                            '${country.flag}  ${country.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: countries == null
                        ? null
                        : (value) => setState(() => _countryCode = value),
                    validator: (value) =>
                        value == null ? 'Choose a country.' : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  helperText: 'Only used to keep your best score, never shown.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return null;
                  final looksValid = RegExp(
                    r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$',
                  ).hasMatch(email);
                  return looksValid
                      ? null
                      : 'That does not look like an email.';
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                  color: theme.colorScheme.error,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _submit(anonymous: false),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit and get my certificate'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : () => _submit(anonymous: true),
                child: const Text('Submit without being named'),
              ),
              const SizedBox(height: 10),
              Text(
                'Submitting without a name still gives you a certificate, but no '
                'place on the leaderboard.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
