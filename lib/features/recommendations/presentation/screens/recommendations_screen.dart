import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';
import '../../../onboarding/data/onboarding_provider.dart';

const _pageSize = 5;

/// Entdecken-Screen — Ziel auswählen → Claude liefert Empfehlungen (paginiert).
/// Zeigt zwei Sektionen: "Einzelne Wirkstoffe" und "Kombipräparate".
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

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

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  Future<void> _loadRecommendations(String goal) async {
    setState(() {
      _selectedGoal = goal;
      _isLoading = true;
      _error = null;
      _supplements.clear();
      _hasMore = true;
    });

    final profile = ref.read(onboardingProvider);

    try {
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: goal,
        limit: _pageSize,
        excludeIds: const [],
      );
      if (mounted) {
        setState(() {
          _supplements.addAll(results);
          // B-Komplex wird immer angehängt → echte Singles zählen für hasMore
          final singleCount =
              results.where((s) => s.supplementType == SupplementType.single).length;
          _hasMore = singleCount >= _pageSize;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
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
      );
      if (mounted) {
        setState(() {
          _supplements.addAll(results);
          final singleCount =
              results.where((s) => s.supplementType == SupplementType.single).length;
          _hasMore = singleCount >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  // --- Duplikat-Check vor dem Hinzufügen ---
  Future<void> _handleAddToStack(Supplement supplement) async {
    final stackNotifier = ref.read(stackProvider.notifier);

    final duplicates = stackNotifier.findDuplicates(supplement);

    if (duplicates.isEmpty) {
      await stackNotifier.add(supplement);
      return;
    }

    if (!mounted) return;

    // Dialog anzeigen
    final result = await showDialog<_DuplicateDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DuplicateDialog(
        newSupplement: supplement,
        duplicates: duplicates,
      ),
    );

    if (result == null || result.action == _DuplicateAction.cancel) return;

    if (result.action == _DuplicateAction.remove) {
      if (result.toRemove.isNotEmpty) {
        await stackNotifier.removeMany(result.toRemove);
      }
      await stackNotifier.add(supplement);
    } else if (result.action == _DuplicateAction.keepBoth) {
      await stackNotifier.addWithDuplicateWarning(supplement);
      await stackNotifier.markDuplicateWarnings(
          duplicates.map((e) => e.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final stackNotifier = ref.read(stackProvider.notifier);
    final stack = ref.watch(stackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              _GoalSelector(
                selectedGoal: _selectedGoal,
                onSelect: _loadRecommendations,
              ),
              _TypeToggle(
                selected: _typeFilter,
                onSelect: (t) => setState(() => _typeFilter = t),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(stackNotifier, stack),
    );
  }

  Widget _buildBody(StackNotifier stackNotifier, List<StackEntry> stack) {
    if (_selectedGoal == null) return const _EmptyState();
    if (_isLoading) return const _LoadingState();
    if (_error != null) {
      return _ErrorState(
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

    // Nach aktivem Typ-Filter filtern
    final filtered = _supplements
        .where((s) => s.supplementType == _typeFilter)
        .toList();

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

    // Liste aufbauen: Items + Lade-Indikator
    final items = <_ListItem>[];
    for (final s in filtered) {
      items.add(_SupplementItem(s));
    }
    // Pagination nur für Einzel-Supplements relevant
    if (_typeFilter == SupplementType.single) {
      if (_isLoadingMore || _hasMore) {
        items.add(_LoadMoreItem());
      } else {
        items.add(_EndItem());
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppConstants.screenPaddingH),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is _SectionHeaderItem) {
          return _SectionHeader(label: item.label);
        }

        if (item is _SupplementItem) {
          final supplement = item.supplement;
          final isInStack = stack.any((e) => e.id == supplement.id);
          return EvidenceCard(
            supplement: supplement,
            isInStack: isInStack,
            onAddToStack: () => _handleAddToStack(supplement),
            onRemoveFromStack: () =>
                ref.read(stackProvider.notifier).remove(supplement.id),
          );
        }

        if (item is _LoadMoreItem) {
          return _LoadMoreIndicator(
            isLoading: _isLoadingMore,
            hasMore: _hasMore,
            onTap: _loadMore,
          );
        }

        // _EndItem
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

// --- Liste Typen (sealed pattern ohne sealed keyword) ---
abstract class _ListItem {}

class _SectionHeaderItem extends _ListItem {
  final String label;
  _SectionHeaderItem(this.label);
}

class _SupplementItem extends _ListItem {
  final Supplement supplement;
  _SupplementItem(this.supplement);
}

class _LoadMoreItem extends _ListItem {}

class _EndItem extends _ListItem {}

// ---- Duplikat-Dialog ----

enum _DuplicateAction { remove, keepBoth, cancel }

class _DuplicateDialogResult {
  final _DuplicateAction action;
  final List<String> toRemove; // IDs der zu entfernenden Einträge
  const _DuplicateDialogResult({required this.action, this.toRemove = const []});
}

class _DuplicateDialog extends StatefulWidget {
  final Supplement newSupplement;
  final List<StackEntry> duplicates;

  const _DuplicateDialog({
    required this.newSupplement,
    required this.duplicates,
  });

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  // Checkbox-Zustand: standardmäßig alle markiert
  late Map<String, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {for (final e in widget.duplicates) e.id: true};
  }

  List<String> get _selectedIds =>
      _checked.entries.where((e) => e.value).map((e) => e.key).toList();

  String get _duplicateNames => widget.duplicates.map((e) => e.name).join(', ');

  @override
  Widget build(BuildContext context) {
    final isMultiple = widget.duplicates.length > 1;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00), size: 22),
          SizedBox(width: 8),
          Text('Wirkstoff bereits vorhanden'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMultiple
                ? 'Diese Wirkstoffe sind bereits in deinem Stack und werden durch '
                    '${widget.newSupplement.name} abgedeckt.\n\n'
                    'Welche möchtest du entfernen?'
                : '${widget.duplicates.first.name} ist bereits in deinem Stack '
                    'und wird durch ${widget.newSupplement.name} abgedeckt.\n\n'
                    'Möchtest du ${widget.duplicates.first.name} entfernen?',
            style: AppTextStyles.bodyMedium,
          ),
          if (isMultiple) ...[
            const SizedBox(height: AppConstants.spaceM),
            ...widget.duplicates.map((entry) => CheckboxListTile(
                  dense: true,
                  title: Text(entry.name, style: AppTextStyles.bodyMedium),
                  subtitle: entry.substanceName != null
                      ? Text(entry.substanceName!, style: AppTextStyles.caption)
                      : null,
                  value: _checked[entry.id] ?? true,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) =>
                      setState(() => _checked[entry.id] = val ?? false),
                )),
          ],
        ],
      ),
      actions: [
        // Abbrechen
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _DuplicateDialogResult(action: _DuplicateAction.cancel),
          ),
          child: const Text('Abbrechen'),
        ),

        // Beides behalten
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _DuplicateDialogResult(action: _DuplicateAction.keepBoth),
          ),
          child: Text(
            'Beides behalten',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),

        // Ja, entfernen
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _DuplicateDialogResult(
              action: _DuplicateAction.remove,
              toRemove: _selectedIds,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(isMultiple ? 'Markierte entfernen' : 'Ja, entfernen'),
        ),
      ],
    );
  }
}

// ---- Sub-Widgets ----

/// Toggle zwischen "Einzelne Wirkstoffe" und "Kombipräparate"
class _TypeToggle extends StatelessWidget {
  final SupplementType selected;
  final void Function(SupplementType) onSelect;

  const _TypeToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        0,
        AppConstants.screenPaddingH,
        10,
      ),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _ToggleOption(
              label: 'Einzelwirkstoffe',
              icon: Icons.science_outlined,
              isSelected: selected == SupplementType.single,
              onTap: () => onSelect(SupplementType.single),
            ),
            _ToggleOption(
              label: 'Kombipräparate',
              icon: Icons.layers_outlined,
              isSelected: selected == SupplementType.group,
              onTap: () => onSelect(SupplementType.group),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.textInverse
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceM,
        bottom: AppConstants.spaceS,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onTap;

  const _LoadMoreIndicator({
    required this.isLoading,
    required this.hasMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spaceXL),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppConstants.spaceS),
              Text('Weitere Supplements laden…'),
            ],
          ),
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM),
        child: Center(
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.expand_more),
            label: const Text('Mehr laden'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _GoalSelector extends StatelessWidget {
  final String? selectedGoal;
  final void Function(String) onSelect;

  const _GoalSelector(
      {required this.selectedGoal, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingH,
          vertical: 10,
        ),
        itemCount: _goalCategories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.spaceS),
        itemBuilder: (context, index) {
          final goal = _goalCategories[index];
          final selected = selectedGoal == goal;
          return GestureDetector(
            onTap: () => onSelect(goal),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  goal,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.textInverse
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppConstants.spaceL),
          Text('Claude analysiert dein Profil...',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppConstants.spaceS),
          Text('Dauert ~8 Sekunden',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppConstants.spaceL),
            Text('Verbindungsfehler',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceXL),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nochmal versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.border),
            const SizedBox(height: AppConstants.spaceM),
            Text('Wähle ein Thema aus',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Claude analysiert dann dein Profil und gibt '
              'dir personalisierte Empfehlungen.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

const _goalCategories = [
  'Mehr Energie',
  'Besserer Schlaf',
  'Fokus & Konzentration',
  'Immunsystem',
  'Sport & Regeneration',
  'Stimmung & Wohlbefinden',
  'Herzgesundheit',
  'Frauengesundheit',
];
