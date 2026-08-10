import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/api/api_client.dart';
import 'core/app_router.dart';
import 'core/config/env.dart';
import 'core/providers/api_providers.dart';

void main() {
  runApp(const ProviderScope(child: RentleApp()));
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
              child: ClerkAuthBuilder(signedInBuilder: _signedIn, signedOutBuilder: _signedOut),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _signedIn(BuildContext context, ClerkAuthState authState) {
    return _SignedInRoot(authState: authState);
  }

  static Widget _signedOut(BuildContext context, ClerkAuthState authState) {
    return const ClerkAuthentication();
  }
}

/// One ApiClient + one GoRouter per signed-in session, scoped via a nested
/// ProviderScope override — everything under here can `ref.watch(apiClientProvider)`
/// without knowing anything about Clerk's session-token shape.
class _SignedInRoot extends StatefulWidget {
  const _SignedInRoot({required this.authState});

  final ClerkAuthState authState;

  @override
  State<_SignedInRoot> createState() => _SignedInRootState();
}

class _SignedInRootState extends State<_SignedInRoot> {
  late final ApiClient _apiClient = ApiClient(
    getToken: () async {
      final token = await widget.authState.sessionToken();
      return token.jwt;
    },
  );
  late final GoRouter _router = buildAppRouter();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_apiClient),
        clerkAuthStateProvider.overrideWithValue(widget.authState),
      ],
      child: Router.withConfig(config: _router),
    );
  }
}
