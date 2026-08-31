import 'package:flutter/material.dart';

import '../models/question.dart';

/// Visual identity for the app: one seed colour, Material 3, light and dark.
abstract final class AppTheme {
  static const Color seed = Color(0xFF5B4BE8);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Icon and accent colour per reasoning domain, used by the chips and the
/// category breakdown on the results screen.
extension CategoryStyle on QuestionCategory {
  IconData get icon => switch (this) {
    QuestionCategory.numerical => Icons.calculate_outlined,
    QuestionCategory.verbal => Icons.abc_outlined,
    QuestionCategory.logical => Icons.account_tree_outlined,
    QuestionCategory.spatial => Icons.grid_view_outlined,
  };

  Color get accent => switch (this) {
    QuestionCategory.numerical => const Color(0xFF2E7DF6),
    QuestionCategory.verbal => const Color(0xFF00A283),
    QuestionCategory.logical => const Color(0xFFE07B22),
    QuestionCategory.spatial => const Color(0xFF8B5CF6),
  };
}
