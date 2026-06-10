import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';

/// Shell-Screen mit Bottom Navigation.
/// Die eigentlichen Inhalte kommen vom ShellRoute als [child].
class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  // Aktive Tab-Route aus aktuellem Pfad ableiten
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.recommendations)) return 1;
    if (location.startsWith(AppRoutes.checkin)) return 2;
    if (location.startsWith(AppRoutes.insights)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0; // Stack (default)
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
                context.go(AppRoutes.stack);
              case 1:
                context.go(AppRoutes.recommendations);
              case 2:
                context.go(AppRoutes.checkin);
              case 3:
                context.go(AppRoutes.insights);
              case 4:
                context.go(AppRoutes.profile);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.layers_outlined),
              activeIcon: Icon(Icons.layers),
              label: 'Stack',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Entdecken',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Check-in',
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
