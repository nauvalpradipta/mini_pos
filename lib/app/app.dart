import 'package:flutter/material.dart';

import 'navigation/app_routes.dart';
import 'navigation/app_shell.dart';
import 'theme/app_theme.dart';

class KasirkuApp extends StatelessWidget {
  const KasirkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KASIRKU POS',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.home,

      routes: {AppRoutes.home: (context) => const AppShell()},
    );
  }
}
