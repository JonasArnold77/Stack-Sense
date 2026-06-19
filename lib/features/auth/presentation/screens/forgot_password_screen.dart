import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .resetPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) _codeSent = true;
    });
  }

  Future<void> _confirmReset() async {
    if (_codeCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).confirmResetPassword(
          _emailCtrl.text.trim(),
          _codeCtrl.text.trim(),
          _passCtrl.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwort erfolgreich zurückgesetzt.'),
          backgroundColor: AppColors.evidenceGreen,
        ),
      );
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authProvider).errorMessage;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              padding: EdgeInsets.only(
                top: topPadding + AppConstants.spaceM,
                left: AppConstants.screenPaddingH,
                right: AppConstants.screenPaddingH,
                bottom: AppConstants.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('Zurück',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  Text(
                    'Passwort zurücksetzen',
                    style: AppTextStyles.headlineLarge.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _codeSent
                        ? 'Gib den Code aus der Email und dein neues Passwort ein.'
                        : 'Wir senden dir einen Reset-Code per Email.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: AppColors.evidenceRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                        border: Border.all(
                            color: AppColors.evidenceRed.withOpacity(0.3)),
                      ),
                      child: Text(error,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.evidenceRed)),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                  ],

                  // Schritt 1: Email eingeben
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_codeSent,
                    decoration: const InputDecoration(
                      labelText: 'Email-Adresse',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  if (!_codeSent) ...[
                    const SizedBox(height: AppConstants.spaceL),
                    FilledButton(
                      onPressed: _isLoading ? null : _sendCode,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Reset-Code senden'),
                    ),
                  ],

                  // Schritt 2: Code + neues Passwort
                  if (_codeSent) ...[
                    const SizedBox(height: AppConstants.spaceM),
                    TextFormField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Bestätigungscode',
                        prefixIcon: Icon(Icons.pin_outlined),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Neues Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText: 'Mind. 8 Zeichen, Groß-/Kleinbuchstaben, Zahl',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceL),
                    FilledButton(
                      onPressed: _isLoading ? null : _confirmReset,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Passwort speichern'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
