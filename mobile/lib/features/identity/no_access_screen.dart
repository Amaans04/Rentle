import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/signed_in_header.dart';

/// Shown when GET /me came back with zero staff memberships and no locally
/// remembered tenant tenancy — a brand-new user Rentle doesn't have context
/// on yet. Managers don't land here: accepting a Clerk org invitation (by
/// email link, or just signing up with the invited email) gives them a
/// membership automatically, before this screen would ever be reached.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rentle')),
      body: Column(
        children: [
          const SignedInHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_work_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "You're signed in — one more thing",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tell us which of these is you:', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/register-pg'),
                      icon: const Icon(Icons.apartment),
                      label: const Text("I'm a PG owner — register my PG"),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/tenant/accept'),
                      icon: const Icon(Icons.key),
                      label: const Text("I'm a tenant with an invite code"),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/discover-pg'),
                      icon: const Icon(Icons.search),
                      label: const Text("I'm a tenant — find my PG"),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Staff invited by an owner don't need either — you'll get access "
                      'automatically once you accept the invite from your owner/manager. '
                      "If you were just invited, it can take a minute to show up — try refreshing.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
