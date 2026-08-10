import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';

/// Replaces the bare `ClerkUserButton()` used across a few screens with
/// something that actually answers "who am I signed in as, and how do I get
/// out" at a glance — read directly from Clerk's already-loaded session
/// (`ClerkAuthState.user`), no extra network round trip needed just to show
/// an email. `signOut()` is reactive: `ClerkAuthState` is a ChangeNotifier
/// that `ClerkAuthBuilder` (main.dart) is already listening to, so the app
/// falls back to the sign-in screen on its own — no manual navigation here.
/// A plain widget (not an AppBar) so it can sit either as its own strip
/// under an existing AppBar, or standalone on screens that don't have one.
class SignedInHeader extends ConsumerWidget {
  const SignedInHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthStateHolderProvider);
    if (authState == null) return const SizedBox.shrink();
    final user = authState.user;
    final identity = user?.email ?? user?.username ?? '';
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                identity.isNotEmpty ? identity[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                identity,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => authState.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
