import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TenantShell extends StatelessWidget {
  const TenantShell({super.key, required this.child});

  final Widget child;

  int _index(String location) {
    if (location.startsWith('/tenant/payments')) return 1;
    if (location.startsWith('/tenant/more') ||
        location.startsWith('/settings')) {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index(location),
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/tenant/dashboard');
            case 1:
              context.go('/tenant/payments');
            case 2:
              context.go('/tenant/more');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
