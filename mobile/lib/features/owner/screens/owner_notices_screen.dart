import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/notice_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerNoticesProvider = FutureProvider.autoDispose<List<NoticeModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getNotices();
});

class OwnerNoticesScreen extends ConsumerWidget {
  const OwnerNoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(ownerNoticesProvider);

    return Scaffold(
      appBar: RentleAppBar(
        title: 'Notice Board',
        fallbackRoute: '/owner/more',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateNotice(context, ref),
          ),
        ],
      ),
      body: notices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('No notices yet', style: GoogleFonts.inter()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final notice = list[index];
              return PressableCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(notice.body, style: GoogleFonts.inter()),
                    if (notice.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat.yMMMd().format(notice.createdAt!),
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateNotice(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String target = 'all';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Body'),
              ),
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: 'Target'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(value: 'tenant', child: Text('Tenants')),
                  DropdownMenuItem(value: 'manager', child: Text('Managers')),
                ],
                onChanged: (v) => target = v!,
              ),
              const SizedBox(height: 16),
              RentleButton(
                label: 'Post Notice',
                onPressed: () async {
                  try {
                    await ref.read(ownerRepositoryProvider).createNotice(
                          title: titleController.text.trim(),
                          body: bodyController.text.trim(),
                          targetRole: target,
                        );
                    ref.invalidate(ownerNoticesProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
