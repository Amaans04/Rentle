import 'dart:convert';

/// The onboarding token the server signs is scoped by orgId, and the accept
/// endpoint needs both (POST /organizations/:orgId/tenant/onboarding/accept)
/// — but a tenant has no independent way to know the orgId. Rather than
/// standing up a hosted web page just to carry a deep link (out of scope,
/// costs money to host reliably), the two are bundled into one opaque code
/// the owner copies and shares (WhatsApp/SMS/etc.) and the tenant pastes
/// into the app.
class InviteCode {
  InviteCode({required this.organizationId, required this.token});

  final String organizationId;
  final String token;

  String encode() => base64Url.encode(utf8.encode(jsonEncode({'orgId': organizationId, 'token': token})));

  static InviteCode? tryDecode(String raw) {
    try {
      final normalized = raw.trim();
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(normalized)))) as Map<String, dynamic>;
      final orgId = decoded['orgId'] as String?;
      final token = decoded['token'] as String?;
      if (orgId == null || orgId.isEmpty || token == null || token.isEmpty) return null;
      return InviteCode(organizationId: orgId, token: token);
    } catch (_) {
      return null;
    }
  }
}
