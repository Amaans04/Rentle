import 'package:flutter/material.dart';
import 'pressable.dart';

/// Rounded, softly-shadowed row replacing bare `ListTile` + `Divider` rows
/// across list screens — a tinted leading icon circle, title/subtitle,
/// trailing chevron, press feedback via [Pressable].
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.leadingColor,
    this.trailing,
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final Color? leadingColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = leadingColor ?? scheme.primary;
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(leadingIcon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
