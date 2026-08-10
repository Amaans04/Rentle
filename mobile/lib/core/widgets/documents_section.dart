import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../models/document_models.dart';
import 'async_value_view.dart';

/// Shared "Documents" list + upload button, used by both the staff-side
/// tenant detail screen and the tenant's own home screen — same shape,
/// different endpoints underneath (see core/document_upload.dart).
class DocumentsSection extends StatelessWidget {
  const DocumentsSection({super.key, required this.documents, required this.onUpload});

  final AsyncValue<List<TenantDocument>> documents;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Documents', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(onPressed: onUpload, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
          ],
        ),
        AsyncValueView<List<TenantDocument>>(
          value: documents,
          data: (context, list) {
            if (list.isEmpty) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No documents uploaded yet.'));
            }
            return Column(
              children: list
                  .map(
                    (d) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(d.fileName),
                      subtitle: Text('${titleCase(d.type)} · ${formatDate(d.createdAt)}'),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
