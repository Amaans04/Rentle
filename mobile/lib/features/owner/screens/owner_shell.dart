import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.child});

  final Widget child;

  int _index(String location) {
    if (location.startsWith('/owner/rooms')) return 1;
    if (location.startsWith('/owner/tenants')) return 2;
    if (location.startsWith('/owner/more') ||
        location.startsWith('/owner/staff') ||
        location.startsWith('/owner/complaints') ||
        location.startsWith('/owner/notices') ||
        location.startsWith('/owner/rent-records') ||
        location.startsWith('/settings')) {
      return 3;
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
              context.go('/owner/dashboard');
            case 1:
              context.go('/owner/rooms');
            case 2:
              context.go('/owner/tenants');
            case 3:
              context.go('/owner/more');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.meeting_room_rounded),
            label: 'Rooms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Tenants',
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
