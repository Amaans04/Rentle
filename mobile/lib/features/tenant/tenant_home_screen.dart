import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/document_upload.dart';
import '../../core/format.dart';
import '../../core/models/complaint_models.dart';
import '../../core/models/notice_models.dart';
import '../../core/models/tenancy_models.dart';
import '../../core/widgets/app_list_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/documents_section.dart';
import '../../core/widgets/status_badge.dart';
import '../owner/tenants/tenants_list_screen.dart' show tenancyStatusColor;
import '../owner/complaints/complaints_list_screen.dart' show complaintStatusColor;
import '../owner/notices/notices_list_screen.dart' show noticeAudienceLabel;
import 'tenant_providers.dart';
import 'file_complaint_screen.dart';
import 'tenant_complaint_detail_screen.dart';

class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancy = ref.watch(tenantMeProvider(orgId));
    final complaints = ref.watch(tenantComplaintsProvider(orgId));
    final notices = ref.watch(tenantNoticesProvider(orgId));

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.large(
            title: const Text('My tenancy'),
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            actions: const [ClerkUserButton(), SizedBox(width: 12)],
          ),
        ],
        body: AsyncValueView<Tenancy>(
          value: tenancy,
          onRetry: () => ref.invalidate(tenantMeProvider(orgId)),
          data: (context, t) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tenantMeProvider(orgId));
                ref.invalidate(tenantComplaintsProvider(orgId));
                ref.invalidate(tenantNoticesProvider(orgId));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(label: titleCase(t.status), color: tenancyStatusColor(context, t.status)),
                          const SizedBox(height: 8),
                          Text('Bed ${t.bedLabel ?? '—'}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Rent: ${formatMoney(t.rentAmount)}/mo'),
                          Text('Deposit: ${formatMoney(t.depositAmount)}'),
                          Text('Move-in: ${formatDate(t.moveInDate)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AsyncValueView<List<Notice>>(
                    value: notices,
                    data: (context, list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notices', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...list.map(
                            (n) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.campaign, size: 18, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(n.body),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${noticeAudienceLabel(n.audience)} · ${formatDate(n.createdAt)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('My complaints', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => FileComplaintScreen(orgId: orgId)),
                          );
                          ref.invalidate(tenantComplaintsProvider(orgId));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('File one'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AsyncValueView<List<Complaint>>(
                    value: complaints,
                    data: (context, list) {
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No complaints filed yet.'),
                        );
                      }
                      return Column(
                        children: list
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppListCard(
                                  leadingIcon: Icons.report_problem,
                                  leadingColor: complaintStatusColor(context, c.status),
                                  title: c.title,
                                  trailing: StatusBadge(label: titleCase(c.status), color: complaintStatusColor(context, c.status)),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TenantComplaintDetailScreen(orgId: orgId, complaintId: c.id),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  DocumentsSection(
                    documents: ref.watch(tenantDocumentsProvider(orgId)),
                    onUpload: () async {
                      final uploaded = await pickAndUploadDocument(
                        context: context,
                        ref: ref,
                        requestPath: '/organizations/$orgId/tenant/documents',
                        confirmPath: '/organizations/$orgId/tenant/documents/confirm',
                      );
                      if (uploaded) ref.invalidate(tenantDocumentsProvider(orgId));
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
