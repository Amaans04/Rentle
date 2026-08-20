import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/notice_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../owner_providers.dart';
import 'notice_form_sheet.dart';

String noticeAudienceLabel(String audience) => switch (audience) {
  'ALL_TENANTS' => 'Every tenant',
  'PROPERTY' => 'This property',
  'FLOOR' => 'One floor',
  'ROOM' => 'One room',
  _ => titleCase(audience),
};

class NoticesListScreen extends ConsumerWidget {
  const NoticesListScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  PropertyKey get _key => (orgId: orgId, propertyId: property.id);

  Future<void> _edit(BuildContext context, WidgetRef ref, Notice notice) async {
    final saved = await NoticeFormSheet.show(context, orgId: orgId, propertyId: property.id, existing: notice);
    if (saved == true) ref.invalidate(noticesProvider(_key));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Notice notice) async {
    final confirmed = await confirmDelete(context, title: 'Delete this notice?', message: '"${notice.title}" will no longer be visible to tenants.');
    if (!confirmed) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/$orgId/notices/${notice.id}');
      ref.invalidate(noticesProvider(_key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticesProvider(_key));

    return AsyncValueView<List<Notice>>(
      value: notices,
      onRetry: () => ref.invalidate(noticesProvider(_key)),
      data: (context, list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.campaign,
            title: 'No notices yet',
            subtitle: 'Post one to reach every tenant, or just one floor/room.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(noticesProvider(_key).future),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final notice = list[index];
              return StaggeredEntrance(
                index: index,
                child: AppListCard(
                  leadingIcon: Icons.campaign,
                  title: notice.title,
                  subtitle: '${noticeAudienceLabel(notice.audience)} · ${formatDate(notice.createdAt)}',
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit' ? _edit(context, ref, notice) : _delete(context, ref, notice),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => _edit(context, ref, notice),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
