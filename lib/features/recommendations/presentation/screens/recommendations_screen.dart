import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/domain/models/stack_entry.dart' show StackEntry, IntakeSlot;
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

  // --- KI-basierter Duplikat-Check vor dem Hinzufügen ---
  Future<void> _handleAddToStack(Supplement supplement) async {
    final stackNotifier = ref.read(stackProvider.notifier);
    final currentStack = ref.read(stackProvider);

    // Stack als Supplement-Liste für den API-Call aufbereiten
    final stackAsSupplements = currentStack.map(_stackEntryToSupplement).toList();

    // Lade-Indikator zeigen während KI prüft
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Stack wird geprüft…'),
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
      await stackNotifier.add(supplement);
      return;
    }

    // Duplikate aus dem Stack anhand der IDs holen
    final duplicates = currentStack
        .where((e) => checkResult.duplicateIds.contains(e.id))
        .toList();

    if (duplicates.isEmpty) {
      await stackNotifier.add(supplement);
      return;
    }

    // Dialog anzeigen
    final result = await showDialog<_DuplicateDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DuplicateDialog(
        newSupplement: supplement,
        duplicates: duplicates,
        reasoning: checkResult.reasoning,
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

  /// Konvertiert einen StackEntry in ein minimales Supplement-Objekt für den API-Call.
  Supplement _stackEntryToSupplement(StackEntry e) => Supplement(
        id: e.id,
        name: e.name,
        substanceName: e.substanceName,
        evidenceLevel: e.evidenceLevel,
        evidenceReason: '',
        dosage: e.dosage,
        intakeTime: e.intakeTime,
        supplementType: e.supplementType,
        enthalteneWirkstoffe: e.enthalteneWirkstoffe,
      );

  @override
  Widget build(BuildContext context) {
    final stackNotifier = ref.read(stackProvider.notifier);
    final stack = ref.watch(stackProvider);
    final hasGoal = _selectedGoal != null;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Entdecken',
            subtitle: _selectedGoal == null
                ? 'Personalisierte Empfehlungen für dich'
                : 'Ziel: $_selectedGoal',
            bottomPadding: hasGoal ? 0 : 20,
            bottom: hasGoal
                ? Column(
                    children: [
                      _GoalSelector(
                        selectedGoal: _selectedGoal,
                        onSelect: _loadRecommendations,
                        onDark: true,
                      ),
                      const SizedBox(height: 10),
                    ],
                  )
                : null,
          ),
          // Type-Toggle unter dem Header auf weißem Grund
          if (hasGoal)
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  _TypeToggle(
                    selected: _typeFilter,
                    onSelect: (t) => setState(() => _typeFilter = t),
                  ),
                  Container(height: 1, color: AppColors.border),
                ],
              ),
            ),
          Expanded(child: _buildBody(stackNotifier, stack)),
        ],
      ),
    );
  }

  Widget _buildBody(StackNotifier stackNotifier, List<StackEntry> stack) {
    if (_selectedGoal == null) {
      return _GoalTileGrid(onSelect: _loadRecommendations);
    }
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
  final String reasoning;

  const _DuplicateDialog({
    required this.newSupplement,
    required this.duplicates,
    this.reasoning = '',
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
          if (widget.reasoning.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceM),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF6C00).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF6C00).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFFEF6C00)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.reasoning,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFFEF6C00),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  /// Wenn true: für dunklen (Gradient-)Hintergrund gestylt
  final bool onDark;

  const _GoalSelector({
    required this.selectedGoal,
    required this.onSelect,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingH,
        ),
        itemCount: _goalData.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.spaceS),
        itemBuilder: (context, index) {
          final goal = _goalData[index];
          final selected = selectedGoal == goal.label;

          // Farben je nach Hintergrund
          final bgSelected = onDark
              ? Colors.white.withOpacity(0.22)
              : AppColors.primary;
          final bgUnselected = onDark
              ? Colors.white.withOpacity(0.09)
              : AppColors.surfaceVariant;
          final borderSelected = onDark
              ? Colors.white.withOpacity(0.7)
              : AppColors.primary;
          final borderUnselected = onDark
              ? Colors.white.withOpacity(0.2)
              : AppColors.border;
          final textSelected = onDark ? Colors.white : AppColors.textInverse;
          final textUnselected = onDark
              ? Colors.white.withOpacity(0.75)
              : AppColors.textSecondary;

          return GestureDetector(
            onTap: () => onSelect(goal.label),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? bgSelected : bgUnselected,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(
                  color: selected ? borderSelected : borderUnselected,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      goal.icon,
                      size: 13,
                      color: selected ? textSelected : textUnselected,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      goal.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected ? textSelected : textUnselected,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
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

/// Kachelgitter für die Zielauswahl — erscheint wenn noch kein Ziel gewählt ist.
class _GoalTileGrid extends StatelessWidget {
  final void Function(String) onSelect;
  const _GoalTileGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              AppConstants.spaceL,
              AppConstants.screenPaddingH,
              AppConstants.spaceS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Was beschäftigt dich?',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppConstants.spaceXS),
                Text(
                  'Claude analysiert dein Profil und gibt personalisierte Empfehlungen.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingH,
            vertical: AppConstants.spaceS,
          ),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppConstants.spaceM,
            crossAxisSpacing: AppConstants.spaceM,
            childAspectRatio: 1.35,
            children: _goalData.map((goal) {
              return _GoalTile(goal: goal, onTap: () => onSelect(goal.label));
            }).toList(),
          ),
        ),
        // Etwas Abstand unten
        const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final _GoalData goal;
  final VoidCallback onTap;

  const _GoalTile({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: Icon(
                      goal.icon,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(
                    goal.label,
                    style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Ziel-Daten ----

class _GoalData {
  final String label;
  final IconData icon;
  const _GoalData({required this.label, required this.icon});
}

const _goalData = [
  _GoalData(label: 'Mehr Energie', icon: Icons.bolt_outlined),
  _GoalData(label: 'Besserer Schlaf', icon: Icons.bedtime_outlined),
  _GoalData(label: 'Fokus & Konzentration', icon: Icons.psychology_outlined),
  _GoalData(label: 'Sport & Regeneration', icon: Icons.fitness_center_outlined),
  _GoalData(label: 'Immunsystem stärken', icon: Icons.shield_outlined),
  _GoalData(label: 'Stimmung & Wohlbefinden', icon: Icons.mood_outlined),
  _GoalData(label: 'Herzgesundheit', icon: Icons.favorite_outline),
  _GoalData(label: 'Haut & Haare', icon: Icons.spa_outlined),
  _GoalData(label: 'Gewichtsmanagement', icon: Icons.scale_outlined),
  _GoalData(label: 'Gelenkgesundheit', icon: Icons.elderly_outlined),
  _GoalData(label: 'Frauengesundheit / Zyklus', icon: Icons.female),
  _GoalData(label: 'Hormonbalance', icon: Icons.science_outlined),
];
