import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_provider.dart';

class ConfirmEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const ConfirmEmailScreen({super.key, required this.email});

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .confirmSignUp(widget.email, code);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email bestätigt! Bitte jetzt anmelden.'),
          backgroundColor: AppColors.evidenceGreen,
        ),
      );
      context.go(AppRoutes.login);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    await ref
        .read(authProvider.notifier)
        .resendConfirmationCode(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code erneut gesendet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authProvider).errorMessage;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
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
                const Icon(Icons.mark_email_read_outlined,
                    size: 40, color: Colors.white),
                const SizedBox(height: AppConstants.spaceM),
                Text(
                  'Email bestätigen',
                  style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wir haben einen 6-stelligen Code an\n${widget.email} gesendet.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white.withOpacity(0.75)),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppConstants.spaceXL),

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

                  TextFormField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLarge
                        .copyWith(letterSpacing: 12),
                    decoration: const InputDecoration(
                      labelText: 'Bestätigungscode',
                      counterText: '',
                    ),
                    onChanged: (v) {
                      if (v.length == 6) _confirm();
                    },
                  ),

                  const SizedBox(height: AppConstants.spaceL),

                  FilledButton(
                    onPressed: _isLoading ? null : _confirm,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Bestätigen'),
                  ),

                  const SizedBox(height: AppConstants.spaceM),

                  TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? 'Wird gesendet...' : 'Code erneut senden',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
