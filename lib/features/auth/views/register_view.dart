import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../viewmodels/auth_view_model.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthViewModel>().register(
      fullName: _fullNameController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Kembali ke route utama.
      // AuthGate akan menampilkan AppShell setelah status authenticated.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _clearError() {
    context.read<AuthViewModel>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: viewModel.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 30,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Buat akun kasir',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Lengkapi informasi berikut untuk membuat akun baru.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 32),

                    AppTextField(
                      label: 'Nama lengkap',
                      hintText: 'Contoh: Nauval Pradipta',
                      controller: _fullNameController,
                      enabled: !viewModel.isLoading,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama lengkap wajib diisi.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    AppTextField(
                      label: 'Username',
                      hintText: 'Buat username',
                      controller: _usernameController,
                      enabled: !viewModel.isLoading,
                      prefixIcon: const Icon(Icons.person_outline),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username wajib diisi.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    AppTextField(
                      label: 'Password',
                      hintText: 'Minimal 8 karakter',
                      controller: _passwordController,
                      enabled: !viewModel.isLoading,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      onChanged: (_) {
                        _clearError();
                        _formKey.currentState?.validate();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password wajib diisi.';
                        }

                        if (value.length < 8) {
                          return 'Password minimal 8 karakter.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    AppTextField(
                      label: 'Konfirmasi password',
                      hintText: 'Masukkan ulang password',
                      controller: _confirmPasswordController,
                      enabled: !viewModel.isLoading,
                      obscureText: _obscureConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      onChanged: (_) {
                        _clearError();
                        _formKey.currentState?.validate();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Konfirmasi password wajib diisi.';
                        }

                        if (value != _passwordController.text) {
                          return 'Password tidak cocok.';
                        }

                        return null;
                      },
                    ),

                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _RegisterErrorMessage(message: viewModel.errorMessage!),
                    ],

                    const SizedBox(height: 24),

                    AppButton(
                      label: 'Buat akun',
                      icon: Icons.person_add_alt_1,
                      isLoading: viewModel.isLoading,
                      onPressed: _submit,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah memiliki akun?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Masuk'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterErrorMessage extends StatelessWidget {
  const _RegisterErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
