/// Build-time config, passed via --dart-define (see README for the exact
/// command) — never hardcoded in source, even though a Clerk *publishable*
/// key (unlike the secret key) is specifically designed to be safe to embed
/// in a client app.
class Env {
  static const clerkPublishableKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rentle-gdys.onrender.com',
  );
}
