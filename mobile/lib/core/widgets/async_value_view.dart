import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_exception.dart';

/// Common loading/error/data scaffolding for an AsyncValue, used across every
/// list/detail screen so error handling doesn't get reimplemented per screen.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Crossfades loading -> content/error instead of an abrupt cut — the one
    // AsyncValue state change every list/detail screen in the app goes
    // through, so it's the single highest-leverage animation in the app.
    // Keyed on the *kind* of state (not the data itself), so a pull-to-refresh
    // that yields new data of the same kind doesn't re-trigger the fade —
    // that would be seen dozens of times a session and read as flicker, not
    // polish.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: value.when(
        data: (d) => KeyedSubtree(key: const ValueKey('data'), child: data(context, d)),
        loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
        error: (err, stackTrace) => Center(
          key: const ValueKey('error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(ApiException.from(err).message, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
                // Pilot-stage escape hatch: an unexpected (non-server) error
                // is exactly the case where the friendly message above isn't
                // enough to debug from a screenshot — this makes the real
                // exception + stack trace visible without needing a live
                // debugger attached to the device.
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text('Details', style: TextStyle(fontSize: 12)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(
                        '$err\n\n$stackTrace',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiException.from(error).message)));
}
