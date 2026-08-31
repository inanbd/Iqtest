import 'package:flutter/material.dart';

import 'navigation.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const IqTestApp());
}

class IqTestApp extends StatelessWidget {
  const IqTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Index',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
    );
  }
}
