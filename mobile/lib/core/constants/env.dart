import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

  static String get firebaseApiKey =>
      dotenv.env['FIREBASE_API_KEY'] ?? '';

  static String get firebaseAuthDomain =>
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';

  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';

  static String get firebaseAppId =>
      dotenv.env['FIREBASE_APP_ID'] ?? '';

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
}
