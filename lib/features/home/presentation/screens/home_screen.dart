import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../settings/data/tenant_config_provider.dart';
import '../../../settings/domain/models/feature_keys.dart';

/// Shell-Screen mit Bottom Navigation.
/// Tabs: Heute | Stack | Rezepte | Insights | Profil
/// "Entdecken" (Problemfelder) hat keinen eigenen Tab mehr — erreichbar über
/// den "Was möchtest du hinzufügen?"-Dialog auf dem Heute-Screen
/// (siehe GoalProgressPanel). "Rezepte" und "Insights" werden ausgegraut,
/// wenn das jeweilige Feature für die aktuelle Partei deaktiviert ist — siehe
/// FeatureKeys/TenantConfig. "Heute", "Stack" und "Profil" sind immer aktiv,
/// da sie keinem der konfigurierbaren Features entsprechen.
class HomeScreen extends ConsumerStatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  // HomeScreen wird von ShellRoute.builder direkt im ROOT-Navigator gebaut
  // (bevor der Shell-eigene, innere Navigator für Heute/Rezepte/Insights/...
  // beginnt) — ModalRoute.of(context) liefert hier also genau die Seite, auf
  // der Push-Routen wie Basissupplementierung/Phasenziele landen. Darüber
  // hält shellCoveredProvider fest, ob die ganze Shell (inkl. Heute-Screen
  // darunter) gerade verdeckt ist — siehe LevelUpOverlay.
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // didPushNext/didPopNext können synchron während eines laufenden
  // Rebuilds der Router-Navigation feuern (z.B. wenn context.push() direkt
  // aus einem Build-abhängigen Zustand heraus einen neuen Eintrag ins
  // Navigator-Widget-Tree einfügt) — Riverpod verbietet das direkte
  // Modifizieren eines Providers währenddessen ("Tried to modify a
  // provider while the widget tree was building"). Deshalb hier immer erst
  // nach dem aktuellen Frame anwenden.
  void _setShellCovered(bool covered) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(shellCoveredProvider.notifier).state = covered;
    });
  }

  @override
  void didPushNext() => _setShellCovered(true);

  @override
  void didPopNext() => _setShellCovered(false);

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.heute)) return 0;
    if (location.startsWith(AppRoutes.stack)) return 1;
    if (location.startsWith(AppRoutes.recipes)) return 2;
    if (location.startsWith(AppRoutes.insights)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index, Set<int> disabledIndices) {
    if (disabledIndices.contains(index)) return;
    switch (index) {
      case 0: context.go(AppRoutes.heute);
      case 1: context.go(AppRoutes.stack);
      case 2: context.go(AppRoutes.recipes);
      case 3: context.go(AppRoutes.insights);
      case 4: context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final tenantConfig = ref.watch(tenantConfigProvider);
    final disabledIndices = <int>{
      if (!tenantConfig.featureEnabled(FeatureKeys.rezepte)) 2,
      if (!tenantConfig.featureEnabled(FeatureKeys.insights)) 3,
    };

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _StackSenseNavBar(
        selectedIndex: selectedIndex,
        disabledIndices: disabledIndices,
        onTap: (i) => _onTap(context, i, disabledIndices),
      ),
    );
  }
}

// ─── Custom NavigationBar ────────────────────────────────────────────────────

class _StackSenseNavBar extends StatelessWidget {
  final int selectedIndex;
  final Set<int> disabledIndices;
  final ValueChanged<int> onTap;

  const _StackSenseNavBar({
    required this.selectedIndex,
    required this.onTap,
    this.disabledIndices = const {},
  });

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Heute',
    ),
    _NavItem(
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
      label: 'Stack',
    ),
    _NavItem(
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu_rounded,
      label: 'Rezepte',
    ),
    _NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Insights',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.asMap().entries.map((e) {
              final index = e.key;
              final item = e.value;
              final isSelected = selectedIndex == index;
              final isDisabled = disabledIndices.contains(index);
              return _NavBarItem(
                item: item,
                isSelected: isSelected,
                isDisabled: isDisabled,
                onTap: () => onTap(index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDisabled
        ? AppColors.textTertiary.withOpacity(0.35)
        : (isSelected ? AppColors.primary : AppColors.textTertiary);

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected && !isDisabled
                ? AppColors.primary.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  size: 24,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected && !isDisabled ? FontWeight.w700 : FontWeight.w400,
                  color: iconColor,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
