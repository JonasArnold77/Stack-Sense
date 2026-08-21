import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/domain/models/stack_entry.dart' show StackEntry;
import '../widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../settings/data/recommendation_mode_provider.dart';
import '../../../settings/domain/models/recommendation_mode.dart';
import '../../../community/domain/models/community_insight.dart';
// ignore: unused_import
import '../../../community/data/community_insights_provider.dart';
import '../widgets/duplicate_dialog.dart';
import '../widgets/safety_warning_dialog.dart';
import '../widgets/goal_selector.dart';
import '../widgets/goal_tile_grid.dart';
import '../widgets/recommendations_states.dart';
import '../widgets/supplement_type_toggle.dart';
import '../widgets/synergy_card.dart';

const _pageSize = 4;

class RecommendationsScreen extends ConsumerStatefulWidget {
  /// Optionales Startziel — wenn gesetzt wird es beim ersten Build direkt geladen.
  final String? initialGoal;

  const RecommendationsScreen({super.key, this.initialGoal});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  String? _selectedGoal;
  final List<Supplement> _supplements = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  SupplementType _typeFilter = SupplementType.single;
  Map<String, CommunityInsight> _communityInsights = {};

  // Synergien — nur im Kombipräparate-Tab geladen
  List<SupplementSynergy> _synergies = [];
  bool _loadingSynergies = false;
  bool _synergiesLoaded = false; // Einmal pro Ziel laden

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Direkt das übergebene Ziel laden (z.B. aus GoalProgressScreen)
    if (widget.initialGoal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRecommendations(widget.initialGoal!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    if (current >= maxScroll - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore &&
        _selectedGoal != null) {
      _loadMore();
    }
  }

  bool get _dbOnly =>
      ref.read(recommendationModeProvider) == RecommendationMode.ragOnly;

  Future<void> _loadRecommendations(String goal) async {
    setState(() {
      _selectedGoal = goal;
      _isLoading = true;
      _error = null;
      _supplements.clear();
      _hasMore = true;
      // Synergien zurücksetzen — werden neu geladen wenn Kombi-Tab geöffnet
      _synergies = [];
      _synergiesLoaded = false;
    });
    final profile = ref.read(onboardingProvider);
    try {
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: goal,
        limit: _pageSize,
        excludeIds: const [],
        dbOnly: _dbOnly,
      );
      if (mounted) {
        setState(() {
          _supplements.addAll(results);
          _hasMore = results.length >= _pageSize;
          _isLoading = false;
        });
      }
      _loadCommunityInsights(results.map((s) => s.name).toList());
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCommunityInsights(List<String> names) async {
    if (names.isEmpty) return;
    try {
      final insights = await ApiService.instance.getCommunityInsights(names);
      if (mounted && insights.isNotEmpty) {
        setState(() {
          _communityInsights = {..._communityInsights, ...insights};
        });
      }
    } catch (_) {}
  }

  /// Lädt Synergien einmal pro Ziel (lazy — nur wenn Kombi-Tab geöffnet wird).
  Future<void> _loadSynergies() async {
    if (_synergiesLoaded || _loadingSynergies || _selectedGoal == null) return;
    setState(() => _loadingSynergies = true);
    final profile = ref.read(onboardingProvider);
    try {
      final results = await ApiService.instance.getSynergies(
        profile: profile,
        goal: _selectedGoal!,
      );
      if (mounted) {
        setState(() {
          _synergies = results;
          _synergiesLoaded = true;
          _loadingSynergies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSynergies = false);
    }
  }

  void _onTypeFilterChanged(SupplementType type) {
    setState(() => _typeFilter = type);
    // Synergien lazy laden wenn Kombi-Tab zum ersten Mal geöffnet wird
    if (type == SupplementType.group) {
      _loadSynergies();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _selectedGoal == null) return;
    setState(() => _isLoadingMore = true);
    final profile = ref.read(onboardingProvider);
    final alreadyLoaded = _supplements.map((s) => s.id).toList();
    try {
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: _selectedGoal!,
        limit: _pageSize,
        excludeIds: alreadyLoaded,
        dbOnly: _dbOnly,
      );
      if (mounted) {
        setState(() {
          _supplements.addAll(results);
          _hasMore = results.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
      _loadCommunityInsights(results.map((s) => s.name).toList());
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _handleAddToStack(Supplement supplement) async {
    final safetyConfirmed = await confirmSupplementSafetyIfNeeded(
      context,
      supplementId: supplement.id,
      supplementName: supplement.name,
    );
    if (!mounted || !safetyConfirmed) return;

    final stackNotifier = ref.read(stackProvider.notifier);
    final currentStack = ref.read(stackProvider);
    final stackAsSupplements =
        currentStack.map(_stackEntryToSupplement).toList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Stack wird geprüft...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    DuplicateCheckResult checkResult;
    try {
      checkResult = await ApiService.instance.checkDuplicates(
        newSupplement: supplement,
        stack: stackAsSupplements,
      );
    } finally {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!mounted) return;

    if (!checkResult.hasDuplicates) {
      await stackNotifier.add(supplement, goalContext: _selectedGoal);
      return;
    }

    final duplicates = currentStack
        .where((e) => checkResult.duplicateIds.contains(e.id))
        .toList();

    if (duplicates.isEmpty) {
      await stackNotifier.add(supplement, goalContext: _selectedGoal);
      return;
    }

    final result = await showDialog<DuplicateDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DuplicateDialog(
        newSupplement: supplement,
        duplicates: duplicates,
        reasoning: checkResult.reasoning,
      ),
    );

    if (result == null || result.action == DuplicateAction.cancel) return;

    if (result.action == DuplicateAction.remove) {
      if (result.toRemove.isNotEmpty) {
        await stackNotifier.removeMany(result.toRemove);
      }
      await stackNotifier.add(supplement, goalContext: _selectedGoal);
    } else if (result.action == DuplicateAction.keepBoth) {
      await stackNotifier.addWithDuplicateWarning(supplement);
      await stackNotifier.markDuplicateWarnings(
          duplicates.map((e) => e.id).toList());
    }
  }

  Supplement _stackEntryToSupplement(StackEntry e) => Supplement(
        id: e.id,
        name: e.name,
        substanceName: e.substanceName,
        evidenceLevel: e.evidenceLevel,
        substanceCategory: e.substanceCategory,
        evidenceReason: '',
        dosage: e.dosage,
        intakeTime: e.intakeTime,
        supplementType: e.supplementType,
        enthalteneWirkstoffe: e.enthalteneWirkstoffe,
      );

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(stackProvider);
    final hasGoal = _selectedGoal != null;
    final isRagOnly =
        ref.watch(recommendationModeProvider) == RecommendationMode.ragOnly;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Entdecken',
            subtitle: _selectedGoal == null
                ? 'Personalisierte Empfehlungen für dich'
                : isRagOnly
                    ? 'Datenbank-Modus · Ziel: $_selectedGoal'
                    : 'Ziel: $_selectedGoal',
            bottomPadding: hasGoal ? 0 : 20,
            bottom: hasGoal
                ? Column(
                    children: [
                      GoalSelector(
                        selectedGoal: _selectedGoal,
                        onSelect: _loadRecommendations,
                        onDark: true,
                      ),
                      const SizedBox(height: 10),
                    ],
                  )
                : null,
          ),
          if (hasGoal)
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  SupplementTypeToggle(
                    selected: _typeFilter,
                    onSelect: _onTypeFilterChanged,
                  ),
                  Container(height: 1, color: AppColors.border),
                ],
              ),
            ),
          Expanded(child: _buildBody(stack)),
        ],
      ),
    );
  }

  Widget _buildBody(List<StackEntry> stack) {
    if (_selectedGoal == null) {
      return GoalTileGrid(onSelect: _loadRecommendations);
    }

    if (_isLoading) return const RecommendationsLoadingState();
    if (_error != null) {
      return RecommendationsErrorState(
        message: _error!,
        onRetry: () => _loadRecommendations(_selectedGoal!),
      );
    }

    if (_supplements.isEmpty) {
      return Center(
        child: Text('Keine Empfehlungen gefunden.',
            style: AppTextStyles.bodyMedium),
      );
    }

    final filtered = _supplements
        .where((s) => s.supplementType == _typeFilter)
        .toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceXL),
          child: Text(
            _typeFilter == SupplementType.single
                ? 'Keine Einzel-Supplements geladen.'
                : 'Keine Kombipräparate geladen.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final items = <_ListItem>[];
    for (final s in filtered) {
      items.add(_SupplementItem(s));
    }
    if (_typeFilter == SupplementType.single) {
      if (_isLoadingMore || _hasMore) {
        items.add(_LoadMoreItem());
      } else {
        items.add(_EndItem());
      }
    } else {
      // Kombi-Tab: Synergien-Abschnitt ans Ende anhängen
      items.add(_SynergySection(_synergies, _loadingSynergies));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppConstants.screenPaddingH),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is _SupplementItem) {
          final supplement = item.supplement;
          final isInStack = stack.any((e) => e.id == supplement.id);
          final rank = index < 3 ? index + 1 : null;
          return EvidenceCard(
            supplement: supplement,
            isInStack: isInStack,
            rank: rank,
            communityInsight:
                _communityInsights[supplement.name.toLowerCase()],
            goalContext: _selectedGoal,
            onAddToStack: () => _handleAddToStack(supplement),
            onRemoveFromStack: () =>
                ref.read(stackProvider.notifier).remove(supplement.id),
          );
        }

        if (item is _LoadMoreItem) {
          return LoadMoreIndicator(
            isLoading: _isLoadingMore,
            hasMore: _hasMore,
            onTap: _loadMore,
          );
        }

        if (item is _SynergySection) {
          return _SynergyListSection(
            synergies: item.synergies,
            isLoading: item.isLoading,
          );
        }

        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.spaceL),
          child: Center(
            child: Text(
              'Alle Empfehlungen geladen',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        );
      },
    );
  }

}

// ─── Interne List-Item Typen ─────────────────────────────────────────────────

class _SynergySection extends _ListItem {
  final List<SupplementSynergy> synergies;
  final bool isLoading;
  _SynergySection(this.synergies, this.isLoading);
}

/// Widget das den Synergien-Abschnitt im Kombi-Tab rendert.
class _SynergyListSection extends StatelessWidget {
  final List<SupplementSynergy> synergies;
  final bool isLoading;

  const _SynergyListSection({
    required this.synergies,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spaceL),
        // Abschnitts-Trennlinie
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    'Interessante Synergien',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: const Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: AppConstants.spaceM),

        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppConstants.spaceXL),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7C3AED),
              ),
            ),
          )
        else if (synergies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceL),
            child: Text(
              'Keine Synergien für dieses Ziel gefunden.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...synergies.map((s) => SynergyCard(synergy: s)),

        const SizedBox(height: AppConstants.spaceXL),
      ],
    );
  }
}

// Interne Listentypen — nur fuer den Build-Kontext dieses Screens
abstract class _ListItem {}

class _SupplementItem extends _ListItem {
  final Supplement supplement;
  _SupplementItem(this.supplement);
}

class _LoadMoreItem extends _ListItem {}

class _EndItem extends _ListItem {}
