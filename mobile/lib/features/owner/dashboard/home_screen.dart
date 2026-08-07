import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

/// First real screen — proves the whole chain works end to end: Clerk
/// sign-in, a bearer token attached automatically, and a real call to our
/// own server/ API (GET /me). Everything past this is real feature UI.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.authState});

  final ClerkAuthState authState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api;
  Map<String, dynamic>? _me;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      getToken: () async {
        final token = await widget.authState.sessionToken();
        return token.jwt;
      },
    );
    _loadMe();
  }

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.dio.get('/me');
      setState(() => _me = response.data['data'] as Map<String, dynamic>?);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentle'),
        actions: [const ClerkUserButton(), const SizedBox(width: 12)],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Could not reach the server:\n$_error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _loadMe, child: const Text('Retry')),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  Text('Signed in as ${_me?['user']?['email'] ?? 'unknown'}'),
                  const SizedBox(height: 8),
                  Text('Memberships: ${(_me?['memberships'] as List?)?.length ?? 0}'),
                ],
              ),
      ),
    );
  }
}
