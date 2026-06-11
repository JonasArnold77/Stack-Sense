import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';

/// Shell-Screen mit Bottom Navigation.
/// Tabs: Heute | Entdecken | Stack | Insights | Profil
/// Check-in ist als CTA in Heute integriert (kein eigener Tab).
class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  // Aktive Tab-Route aus aktuellem Pfad ableiten
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.heute)) return 0;
    if (location.startsWith(AppRoutes.recommendations)) return 1;
    if (location.startsWith(AppRoutes.stack)) return 2;
    if (location.startsWith(AppRoutes.insights)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    // /home und /checkin: kein eigener Tab — Heute als Default
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go(AppRoutes.heute);
              case 1:
                context.go(AppRoutes.recommendations);
              case 2:
                context.go(AppRoutes.stack);
              case 3:
                context.go(AppRoutes.insights);
              case 4:
                context.go(AppRoutes.profile);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Heute',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Entdecken',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.layers_outlined),
              activeIcon: Icon(Icons.layers),
              label: 'Stack',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
