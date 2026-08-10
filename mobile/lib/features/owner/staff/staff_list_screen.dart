import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/user_models.dart';
import '../../../core/permissions.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No staff yet. Invite a manager or receptionist to help run this PG.', textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(fullOrgMembersProvider(orgId).future),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = list[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Text(member.displayName[0].toUpperCase()),
                  ),
                  title: Text(member.displayName),
                  subtitle: Text(
                    '${titleCase(member.role)}'
                    '${member.isUnrestricted ? " · All properties" : " · ${member.propertyIds.length} propert${member.propertyIds.length == 1 ? 'y' : 'ies'}"}'
                    '${member.isActive ? '' : ' · Inactive'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => StaffDetailScreen(orgId: orgId, member: member)));
                    ref.invalidate(fullOrgMembersProvider(orgId));
                  },
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
