import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ok = await ref.read(authProvider.notifier).signIn(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.confirmingEmail) {
        context.push(AppRoutes.confirmEmail,
            extra: _emailCtrl.text.trim());
      }
      // Fehlermeldung wird über authProvider.errorMessage gezeigt
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authProvider).errorMessage;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gradient Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              padding: EdgeInsets.only(
                top: topPadding + AppConstants.spaceXL,
                left: AppConstants.screenPaddingH,
                right: AppConstants.screenPaddingH,
                bottom: AppConstants.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: const Icon(Icons.science_outlined,
                        size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  Text(
                    'Willkommen zurück',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Melde dich an um deinen Stack zu verwalten.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: Colors.white.withOpacity(0.75)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.screenPaddingH,
                AppConstants.spaceXL,
                AppConstants.screenPaddingH,
                bottomPadding + AppConstants.spaceXL,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fehlermeldung
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceM),
                        decoration: BoxDecoration(
                          color: AppColors.evidenceRed.withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusM),
                          border: Border.all(
                              color: AppColors.evidenceRed.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: AppColors.evidenceRed),
                            const SizedBox(width: AppConstants.spaceS),
                            Expanded(
                              child: Text(error,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.evidenceRed)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email-Adresse',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email erforderlich';
                        if (!v.contains('@')) return 'Ungültige Email-Adresse';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spaceM),

                    // Passwort
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Passwort erforderlich';
                        return null;
                      },
                    ),

                    // Passwort vergessen
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.forgotPassword),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: AppConstants.spaceS),
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Passwort vergessen?'),
                      ),
                    ),

                    const SizedBox(height: AppConstants.spaceS),

                    // Login Button
                    FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Anmelden'),
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spaceM),
                          child: Text(
                            'oder',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // Google Sign-In
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                      label: const Text('Mit Google fortfahren'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // Registrieren
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Noch kein Konto? ',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.register),
                          child: Text(
                            'Jetzt registrieren',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
