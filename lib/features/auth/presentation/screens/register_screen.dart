import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ok = await ref.read(authProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passCtrl.text,
          name: _nameCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      // Zur Email-Bestätigung weiterleiten
      context.push(AppRoutes.confirmEmail, extra: _emailCtrl.text.trim());
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
            // Gradient Header
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
                    'Konto erstellen',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kostenlos registrieren — dein Stack wartet.',
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
                    // Fehler
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
                        child: Text(error,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.evidenceRed)),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                    ],

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Vorname',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Vorname erforderlich';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spaceM),

                    // Stadt
                    TextFormField(
                      controller: _cityCtrl,
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Stadt / Region',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        helperText: 'Für saisonale Supplement-Empfehlungen',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Stadt erforderlich';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spaceM),

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
                      obscureText: _obscure1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText:
                            'Mind. 8 Zeichen, Groß- + Kleinbuchstaben, Zahl, Sonderzeichen (!@#…)',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure1 = !_obscure1),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 8) {
                          return 'Mind. 8 Zeichen erforderlich';
                        }
                        if (!v.contains(RegExp(r'[A-Z]'))) {
                          return 'Mind. ein Großbuchstabe erforderlich';
                        }
                        if (!v.contains(RegExp(r'[a-z]'))) {
                          return 'Mind. ein Kleinbuchstabe erforderlich';
                        }
                        if (!v.contains(RegExp(r'[0-9]'))) {
                          return 'Mind. eine Zahl erforderlich';
                        }
                        if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\;~`]'))) {
                          return 'Mind. ein Sonderzeichen erforderlich (z.B. !)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spaceM),

                    // Passwort bestätigen
                    TextFormField(
                      controller: _pass2Ctrl,
                      obscureText: _obscure2,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Passwort bestätigen',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure2 = !_obscure2),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passCtrl.text) {
                          return 'Passwörter stimmen nicht überein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spaceL),

                    // Registrieren Button
                    FilledButton(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Konto erstellen'),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bereits registriert? ',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Text(
                            'Anmelden',
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
