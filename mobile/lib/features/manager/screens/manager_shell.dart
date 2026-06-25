import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagerShell extends StatelessWidget {
  const ManagerShell({super.key, required this.child});

  final Widget child;

  int _index(String location) {
    if (location.startsWith('/manager/complaints')) return 1;
    if (location.startsWith('/manager/more') ||
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
              context.go('/manager/dashboard');
            case 1:
              context.go('/manager/complaints');
            case 2:
              context.go('/manager/more');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem_rounded),
            label: 'Complaints',
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
