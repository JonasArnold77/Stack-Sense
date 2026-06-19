import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../onboarding/domain/models/user_profile.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../recommendations/presentation/widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';

// ---------------------------------------------------------------------------
// Tag-Modell für den Filter
// ---------------------------------------------------------------------------

enum _TagType { age, gender, sport, condition, medication, pregnant }

class _FilterTag {
  final String label;
  final _TagType type;
  final dynamic value;

  const _FilterTag({
    required this.label,
    required this.type,
    required this.value,
  });

  @override
  bool operator ==(Object other) =>
      other is _FilterTag && other.label == label && other.type == type;

  @override
  int get hashCode => Object.hash(label, type);
}

// Alle Erkrankungen die per "+" hinzugefügt werden können
const _allConditions = [
  'Hashimoto',
  'Bluthochdruck',
  'Diabetes Typ 2',
  'Schilddrüsenunterfunktion',
  'Osteoporose',
  'Anämie (Eisenmangel)',
  'PCOS',
  'Reizdarm',
  'Depressionen / Burnout',
  'Migräne',
  'Arthritis',
  'Schlafstörungen',
  'Allergien',
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Profil-Empfehlungen Screen — Basis-Supplementierung.
/// Oben: filterbare Profil-Tags (aus Onboarding) + "+" für Extras + Reload.
/// Unten: paginierte Supplement-Liste, "App starten" immer sichtbar.
class ProfileRecommendationsScreen extends ConsumerStatefulWidget {
  final bool fromOnboarding;

  const ProfileRecommendationsScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  ConsumerState<ProfileRecommendationsScreen> createState() =>
      _ProfileRecommendationsScreenState();
}

class _ProfileRecommendationsScreenState
    extends ConsumerState<ProfileRecommendationsScreen> {
  static const int _pageSize = 5;

  // Filter-Tags — aus Profil initialisiert, durch Nutzer veränderbar
  List<_FilterTag> _allTags = [];      // alle verfügbaren Tags (aus Profil + Extras)
  Set<_FilterTag> _activeTags = {};    // aktuell aktive Tags (fließen in API ein)

  // Supplement-Liste
  List<Supplement> _supplements = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(onboardingProvider);
      _initTagsFromProfile(profile);
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // --- Tag-Initialisierung ---

  void _initTagsFromProfile(UserProfile profile) {
    final tags = <_FilterTag>[];

    if (profile.age != null) {
      tags.add(_FilterTag(
        label: '${profile.age} Jahre',
        type: _TagType.age,
        value: profile.age,
      ));
    }
    if (profile.gender != null) {
      tags.add(_FilterTag(
        label: _genderLabel(profile.gender!),
        type: _TagType.gender,
        value: profile.gender,
      ));
    }
    if (profile.sportLevel != null && profile.sportLevel != SportLevel.none) {
      tags.add(_FilterTag(
        label: _sportLabel(profile.sportLevel!),
        type: _TagType.sport,
        value: profile.sportLevel,
      ));
    }
    for (final c in profile.conditions) {
      tags.add(_FilterTag(label: c, type: _TagType.condition, value: c));
    }
    for (final m in profile.medications) {
      tags.add(_FilterTag(label: m, type: _TagType.medication, value: m));
    }
    if (profile.isPregnant) {
      tags.add(_FilterTag(
        label: 'Schwanger / Stillend',
        type: _TagType.pregnant,
        value: true,
      ));
    }

    setState(() {
      _allTags = tags;
      _activeTags = Set.from(tags); // alle starten als aktiv
    });
  }

  // --- Profil aus aktiven Tags rekonstruieren ---

  UserProfile _buildFilteredProfile() {
    int? age;
    Gender? gender;
    SportLevel? sportLevel;
    final conditions = <String>[];
    final medications = <String>[];
    bool isPregnant = false;

    for (final tag in _activeTags) {
      switch (tag.type) {
        case _TagType.age:
          age = tag.value as int;
        case _TagType.gender:
          gender = tag.value as Gender;
        case _TagType.sport:
          sportLevel = tag.value as SportLevel;
        case _TagType.condition:
          conditions.add(tag.value as String);
        case _TagType.medication:
          medications.add(tag.value as String);
        case _TagType.pregnant:
          isPregnant = true;
      }
    }

    return UserProfile(
      age: age,
      gender: gender,
      sportLevel: sportLevel,
      conditions: conditions,
      medications: medications,
      isPregnant: isPregnant,
    );
  }

  // --- Scroll + Pagination ---

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _supplements = [];
      _hasMore = true;
    });

    try {
      final results = await ApiService.instance.getRecommendations(
        profile: _buildFilteredProfile(),
        goal: 'Basis-Supplementierung',
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _supplements = results;
          _hasMore = results.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);

    final excludeIds = _supplements.map((s) => s.id).toList();
    try {
      final results = await ApiService.instance.getRecommendations(
        profile: _buildFilteredProfile(),
        goal: 'Basis-Supplementierung',
        limit: _pageSize,
        excludeIds: excludeIds,
      );
      if (mounted) {
        setState(() {
          _supplements.addAll(results);
          _hasMore = results.length >= _pageSize;
        });
      }
    } catch (_) {
      // Beim Nachladen stumm bleiben
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // --- Stack ---

  void _addToStack(Supplement supplement) {
    final notifier = ref.read(stackProvider.notifier);
    if (ref.read(stackProvider).any((e) => e.id == supplement.id)) return;
    notifier.add(supplement);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${supplement.name} zum Stack hinzugefügt'),
      backgroundColor: AppColors.evidenceGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // --- Navigation ---

  void _finish() {
    if (widget.fromOnboarding) {
      context.go(AppRoutes.heute);
    } else {
      context.pop();
    }
  }

  // --- "+" Bottom Sheet ---

  void _openAddTagSheet() {
    // Alle Erkrankungen die noch NICHT in _allTags sind
    final activeConditionLabels =
        _allTags.where((t) => t.type == _TagType.condition).map((t) => t.label).toSet();

    final available = _allConditions
        .where((c) => !activeConditionLabels.contains(c))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTagSheet(
        availableConditions: available,
        onAdd: (condition) {
          final tag = _FilterTag(
            label: condition,
            type: _TagType.condition,
            value: condition,
          );
          setState(() {
            _allTags = [..._allTags, tag];
            _activeTags = {..._activeTags, tag};
          });
        },
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final existingStack = ref.watch(stackProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
          AppConstants.screenPaddingH,
          AppConstants.spaceS,
          AppConstants.screenPaddingH,
          bottomPadding + AppConstants.spaceM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            const SizedBox(height: AppConstants.spaceM),
            FilledButton.icon(
              onPressed: _finish,
              icon: Icon(
                widget.fromOnboarding
                    ? Icons.rocket_launch_outlined
                    : Icons.check,
                size: 18,
              ),
              label: Text(widget.fromOnboarding ? 'App starten' : 'Fertig'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (widget.fromOnboarding) ...[
              const SizedBox(height: AppConstants.spaceS),
              Text(
                'Du kannst jederzeit weitere Empfehlungen über "Entdecken" abrufen.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient Header
          _RecoGradientHeader(
            profile: profile,
            fromOnboarding: widget.fromOnboarding,
            onBack: () => context.pop(),
          ),

          // Filter-Tag-Leiste
          _FilterBar(
            allTags: _allTags,
            activeTags: _activeTags,
            onToggle: (tag) {
              setState(() {
                if (_activeTags.contains(tag)) {
                  _activeTags = _activeTags.difference({tag});
                } else {
                  _activeTags = {..._activeTags, tag};
                }
              });
            },
            onAdd: _openAddTagSheet,
            onReload: _loadInitial,
          ),

          // Supplement-Liste
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingH,
                vertical: AppConstants.spaceL,
              ),
              children: [
                if (_isLoading) _LoadingList(),

                if (!_isLoading && _error != null)
                  _ErrorCard(error: _error!, onRetry: _loadInitial),

                if (!_isLoading && _error == null && _supplements.isEmpty)
                  _EmptyResult(),

                if (_supplements.isNotEmpty)
                  ...List.generate(_supplements.length, (i) {
                    final s = _supplements[i];
                    final inStack = existingStack.any((e) => e.id == s.id);
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppConstants.spaceS),
                      child: EvidenceCard(
                        supplement: s,
                        isInStack: inStack,
                        rank: i < 3 ? i + 1 : null,
                        onAddToStack: inStack ? null : () => _addToStack(s),
                      ),
                    );
                  }),

                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.spaceL),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                if (!_hasMore && _supplements.isNotEmpty && !_isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spaceL),
                    child: Center(
                      child: Text(
                        'Alle passenden Empfehlungen geladen.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ),

                const SizedBox(height: AppConstants.spaceM),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter-Tag-Leiste
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final List<_FilterTag> allTags;
  final Set<_FilterTag> activeTags;
  final void Function(_FilterTag) onToggle;
  final VoidCallback onAdd;
  final VoidCallback onReload;

  const _FilterBar({
    required this.allTags,
    required this.activeTags,
    required this.onToggle,
    required this.onAdd,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingH,
        vertical: AppConstants.spaceS,
      ),
      child: Row(
        children: [
          // Scrollbare Chip-Zeile
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...allTags.map((tag) {
                    final active = activeTags.contains(tag);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TagChip(
                        label: tag.label,
                        active: active,
                        onTap: () => onToggle(tag),
                      ),
                    );
                  }),

                  // "+" Button am Ende der Chip-Liste
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 1.5),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusRound),
                      ),
                      child: const Icon(Icons.add,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppConstants.spaceS),

          // Reload-Button
          GestureDetector(
            onTap: onReload,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? AppColors.primary : AppColors.textTertiary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "+" Bottom Sheet — zusätzliche Erkrankungen hinzufügen
// ---------------------------------------------------------------------------

class _AddTagSheet extends StatelessWidget {
  final List<String> availableConditions;
  final void Function(String) onAdd;

  const _AddTagSheet({
    required this.availableConditions,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + AppConstants.spaceM,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spaceM),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              AppConstants.spaceM,
              AppConstants.cardPadding,
              AppConstants.spaceS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Erkrankung hinzufügen',
                    style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Tippe auf eine Erkrankung um sie als Filter hinzuzufügen.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (availableConditions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: Text(
                'Alle Erkrankungen sind bereits als Filter aktiv.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Wrap(
                spacing: AppConstants.spaceS,
                runSpacing: AppConstants.spaceS,
                children: availableConditions.map((c) {
                  return GestureDetector(
                    onTap: () {
                      onAdd(c);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusRound),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(c, style: AppTextStyles.labelMedium),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gradient Header
// ---------------------------------------------------------------------------

class _RecoGradientHeader extends StatelessWidget {
  final UserProfile profile;
  final bool fromOnboarding;
  final VoidCallback onBack;

  const _RecoGradientHeader({
    required this.profile,
    required this.fromOnboarding,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: EdgeInsets.only(
        top: topPadding + AppConstants.spaceM,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!fromOnboarding)
            Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
              child: GestureDetector(
                onTap: onBack,
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
            ),

          Text(
            'Basis-Supplementierung',
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Passe die Filter unten an und lade neu.',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white.withOpacity(0.68)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / Error / Empty
// ---------------------------------------------------------------------------

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.evidenceRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.evidenceRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 18, color: AppColors.evidenceRed),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Text(
              'Backend nicht erreichbar — bitte Backend starten',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.evidenceRed),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Text(
        'Keine Empfehlungen für die aktiven Filter gefunden.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

String _genderLabel(Gender g) => switch (g) {
      Gender.male => 'Männlich',
      Gender.female => 'Weiblich',
      Gender.diverse => 'Divers',
    };

String _sportLabel(SportLevel s) => switch (s) {
      SportLevel.none => 'Kein Sport',
      SportLevel.light => 'Wenig Sport',
      SportLevel.moderate => 'Moderat aktiv',
      SportLevel.intense => 'Sehr aktiv',
    };
