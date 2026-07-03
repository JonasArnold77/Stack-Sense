import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/url_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Karte zur Laufzeit-Konfiguration der Backend-URL (ohne App-Rebuild).
class BackendUrlCard extends StatefulWidget {
  const BackendUrlCard({super.key});

  @override
  State<BackendUrlCard> createState() => _BackendUrlCardState();
}

class _BackendUrlCardState extends State<BackendUrlCard> {
  late TextEditingController _controller;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: UrlConfigService.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await UrlConfigService.setUrl(url);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _reset() async {
    await UrlConfigService.reset();
    setState(() {
      _controller.text = UrlConfigService.current;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                'Backend URL',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          TextField(
            controller: _controller,
            style: AppTextStyles.bodySmall,
            decoration: InputDecoration(
              hintText:
                  'https://xxx.ngrok-free.dev  oder  http://192.168.x.x:8000',
              hintStyle:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical: AppConstants.spaceS,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: AppConstants.spaceS),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spaceS),
                  ),
                  child: Text(
                    _saved ? '✓ Gespeichert' : 'Speichern',
                    style:
                        AppTextStyles.labelMedium.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceS),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spaceS,
                    horizontal: AppConstants.spaceM,
                  ),
                ),
                child: Text('Reset', style: AppTextStyles.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceXS),
          Text(
            'Ohne Neustart sofort aktiv. /api/v1 wird automatisch ergänzt.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
