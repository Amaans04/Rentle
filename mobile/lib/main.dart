import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'core/config/env.dart';
import 'features/owner/dashboard/home_screen.dart';

void main() {
  runApp(const RentleApp());
}

class RentleApp extends StatelessWidget {
  const RentleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: Env.clerkPublishableKey),
      child: MaterialApp(
        title: 'Rentle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), useMaterial3: true),
        home: const Scaffold(
          body: SafeArea(
            child: ClerkErrorListener(
              child: ClerkAuthBuilder(
                signedInBuilder: _signedIn,
                signedOutBuilder: _signedOut,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _signedIn(BuildContext context, ClerkAuthState authState) {
    return HomeScreen(authState: authState);
  }

  static Widget _signedOut(BuildContext context, ClerkAuthState authState) {
    return const ClerkAuthentication();
  }
}
