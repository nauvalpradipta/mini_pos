import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/viewmodels/auth_view_model.dart';
import '../../features/auth/views/login_view.dart';
import '../navigation/app_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    // Periksa sesi setelah widget pertama selesai dibuat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<AuthViewModel>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    switch (authViewModel.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const _AuthLoadingView();

      case AuthStatus.authenticated:
        return const AppShell();

      case AuthStatus.unauthenticated:
        return const LoginView();
    }
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
