import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/user_models.dart';
import '../../../core/permissions.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../owner_providers.dart';
import 'staff_detail_screen.dart';
import 'staff_invite_screen.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(fullOrgMembersProvider(orgId));
    final me = ref.watch(meProvider);
    final canManage = me.valueOrNull != null && roleCan(membershipForOrg(me.value!, orgId)?.role ?? '', Perm.staffWrite);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: AsyncValueView<List<OrgMember>>(
        value: members,
        onRetry: () => ref.invalidate(fullOrgMembersProvider(orgId)),
        data: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No staff yet',
              subtitle: 'Invite a manager or receptionist to help run this PG.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(fullOrgMembersProvider(orgId).future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final member = list[index];
                final scheme = Theme.of(context).colorScheme;
                return StaggeredEntrance(
                  index: index,
                  child: AppListCard(
                    leadingIcon: Icons.person,
                    leadingColor: member.isActive ? scheme.primary : scheme.outline,
                    title: member.displayName,
                    subtitle:
                        '${titleCase(member.role)}'
                        '${member.isUnrestricted ? " · All properties" : " · ${member.propertyIds.length} propert${member.propertyIds.length == 1 ? 'y' : 'ies'}"}'
                        '${member.isActive ? '' : ' · Inactive'}',
                    onTap: () async {
                      await Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => StaffDetailScreen(orgId: orgId, member: member)));
                      ref.invalidate(fullOrgMembersProvider(orgId));
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final invited = await Navigator.of(
                  context,
                ).push<bool>(MaterialPageRoute(builder: (_) => StaffInviteScreen(orgId: orgId)));
                if (invited == true) ref.invalidate(fullOrgMembersProvider(orgId));
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Invite staff'),
            )
          : null,
    );
  }
}
