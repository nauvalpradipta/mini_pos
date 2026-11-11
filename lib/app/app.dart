import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

class KasirkuApp extends StatelessWidget {
  const KasirkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KASIRKU POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
