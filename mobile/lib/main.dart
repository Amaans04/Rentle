import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/env.dart';
import 'package:rentle/core/theme/app_theme.dart';
import 'package:rentle/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts are bundled in assets/google_fonts; never fetch them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  await dotenv.load(fileName: '.env');

  final apiUrl = Env.apiBaseUrl;
  if (apiUrl.isEmpty || apiUrl == 'http://localhost:3000') {
    debugPrint(
      'Warning: API_BASE_URL is $apiUrl. On a physical device, set your '
      "laptop's LAN IP in mobile/.env (e.g. http://192.168.1.41:3000).",
    );
  }

  if (Env.isFirebaseConfigured) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        authDomain: Env.firebaseAuthDomain,
        projectId: Env.firebaseProjectId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        appId: Env.firebaseAppId,
      ),
    );
  }

  runApp(const ProviderScope(child: RentleApp()));
}

class RentleApp extends ConsumerWidget {
  const RentleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Rentle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
