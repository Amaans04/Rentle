import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'providers/api_providers.dart';
import 'widgets/async_value_view.dart';

const _documentTypes = ['ID_PROOF', 'AGREEMENT', 'OTHER'];

const _extensionToMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'webp': 'image/webp',
};

String _guessMimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return _extensionToMime[ext] ?? 'application/octet-stream';
}

/// Full flow for attaching a tenant document (ID scan, signed agreement):
/// pick a document type, pick an image (camera or gallery), request a
/// Supabase signed upload URL from our server, PUT the bytes straight to
/// Supabase (the signed URL's token is the only credential it needs — no
/// Supabase key belongs on this client, matching the "server owns Supabase"
/// architecture), then confirm so the server writes the TenantDocument row.
///
/// [requestPath] and [confirmPath] are the staff (`.../tenancies/:id/documents`)
/// or tenant-self (`.../tenant/documents`) endpoints — same request/response
/// shape either way.
Future<bool> pickAndUploadDocument({
  required BuildContext context,
  required WidgetRef ref,
  required String requestPath,
  required String confirmPath,
}) async {
  final type = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Document type'),
      children: _documentTypes
          .map((t) => SimpleDialogOption(onPressed: () => Navigator.of(context).pop(t), child: Text(t)))
          .toList(),
    ),
  );
  if (type == null || !context.mounted) return false;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return false;

  final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
  if (picked == null) return false;

  try {
    final bytes = await picked.readAsBytes();
    final fileName = picked.name;
    final mimeType = _guessMimeType(fileName);

    final api = ref.read(apiClientProvider);
    final requestRes = await api.dio.post(requestPath, data: {'fileName': fileName, 'type': type});
    final signedUrl = requestRes.data['data']['signedUrl'] as String;
    final storageKey = requestRes.data['data']['storageKey'] as String;

    // A bare Dio instance, deliberately not our authenticated `api.dio` —
    // this PUT goes straight to Supabase, not our API, and needs no
    // Authorization header at all: the token embedded in `signedUrl` is
    // the sole credential Supabase's signed-upload endpoint checks.
    await Dio().put(signedUrl, data: bytes, options: Options(headers: {'content-type': mimeType}));

    await api.dio.post(
      confirmPath,
      data: {'storageKey': storageKey, 'type': type, 'fileName': fileName, 'mimeType': mimeType, 'sizeBytes': bytes.length},
    );
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}
