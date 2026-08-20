import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Always-false [ValueListenable] used when a sheet has nothing to save
/// (e.g. a picker), so the close button is never gated.
class _AlwaysFalse implements ValueListenable<bool> {
  const _AlwaysFalse();
  @override
  bool get value => false;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Standardized bottom sheet chrome: HIG-style grabber, title row with a
/// close button, rounded top corners, safe-area padding.
///
/// Also closes a real gap: plain `showModalBottomSheet` lets a user
/// swipe-to-dismiss or tap the scrim away mid-save, which (per
/// docs/PROGRESS.md's 2026-08-11 entry) produced a genuine
/// duplicate-property-create bug once a save was in flight elsewhere in the
/// app. `PopScope` does NOT intercept a sheet's own drag/tap-outside
/// dismissal — that's a different mechanism from the back button/gesture it
/// guards — so the fix here is structural instead: `isDismissible` and
/// `enableDrag` are always off, and the only way out is this shell's own
/// close button (or the sheet content's own Cancel/Save), both of which can
/// check `saving` before popping.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required WidgetBuilder builder,
    ValueListenable<bool>? saving,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AppBottomSheetShell(title: title, saving: saving, builder: builder),
    );
  }
}

class _AppBottomSheetShell extends StatelessWidget {
  const _AppBottomSheetShell({required this.title, required this.saving, required this.builder});

  final String title;
  final ValueListenable<bool>? saving;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: saving ?? const _AlwaysFalse(),
                      builder: (context, isSaving, _) => IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: builder(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
