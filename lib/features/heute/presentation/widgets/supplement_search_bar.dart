import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../recommendations/presentation/screens/supplement_detail_screen.dart';
import '../../../settings/data/recommendation_mode_provider.dart';
import '../../../settings/domain/models/recommendation_mode.dart';
import '../../../settings/data/cache_mode_provider.dart';
import '../../../settings/domain/models/cache_mode.dart';

/// Suchleiste für den Home Screen — tippfehler-/schreibweise-tolerant
/// ("Vitamin B", "Vitamin-B", "VitaminB" finden dieselben Treffer).
/// Antippen eines Treffers generiert die volle Karte und öffnet sie —
/// respektiert dabei den aktuellen KI-/Datenbank-Modus.
class SupplementSearchBar extends ConsumerStatefulWidget {
  const SupplementSearchBar({super.key});

  @override
  ConsumerState<SupplementSearchBar> createState() => _SupplementSearchBarState();
}

class _SupplementSearchBarState extends ConsumerState<SupplementSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<SupplementSearchResult> _results = [];
  bool _searching = false;
  String? _loadingResultId; // welcher Treffer wird gerade zur vollen Karte generiert

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final results = await ApiService.instance.searchSupplements(query: query);
    if (!mounted || _controller.text.trim() != query.trim()) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = [];
      _searching = false;
    });
    _focusNode.unfocus();
  }

  Future<void> _openResult(SupplementSearchResult result) async {
    final dbOnly =
        ref.read(recommendationModeProvider) == RecommendationMode.ragOnly;
    final bypassCache = ref.read(cacheModeProvider) == CacheMode.noCache;
    setState(() => _loadingResultId = result.id);
    try {
      final supplement = await ApiService.instance.lookupSupplement(
        supplementId: result.id,
        supplementName: result.name,
        dbOnly: dbOnly,
        bypassCache: bypassCache,
      );
      if (!mounted) return;
      _clear();
      showSupplementDetail(context, supplement);
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Karte konnte nicht geladen werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingResultId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingH,
        vertical: AppConstants.spaceS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Supplement suchen …',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textTertiary),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textTertiary),
                            onPressed: _clear,
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                  vertical: AppConstants.spaceM,
                ),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppConstants.spaceXS),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final result in _results)
                    _SearchResultTile(
                      result: result,
                      isLoading: _loadingResultId == result.id,
                      onTap: _loadingResultId == null
                          ? () => _openResult(result)
                          : null,
                    ),
                ],
              ),
            )
          else if (!_searching &&
              _controller.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AppConstants.spaceS,
                left: AppConstants.spaceS,
              ),
              child: Text(
                'Keine Treffer für "${_controller.text.trim()}".',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SupplementSearchResult result;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.result,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceS,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name, style: AppTextStyles.bodyMedium),
                  if (result.category.isNotEmpty)
                    Text(
                      result.category,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
