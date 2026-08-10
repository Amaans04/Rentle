import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_router.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: RentleApp()));
}

/// `appRouter` (core/app_router.dart) is created once, at module load, and
/// MaterialApp.router is the app's actual root — nothing here is ever
/// rebuilt or replaced by Clerk's own internal state changes. See
/// AuthGate's doc comment (app_router.dart) for why that matters: it used
/// to be the other way around (ClerkAuthBuilder wrapping the Router), and
/// that caused a real bug.
class RentleApp extends StatelessWidget {
  const RentleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: Env.clerkPublishableKey),
      child: MaterialApp.router(
        title: 'Rentle',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: appRouter,
      ),
    );
  }
}
