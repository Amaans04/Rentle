import 'package:shared_preferences/shared_preferences.dart';

/// Staff identity is derived fresh from GET /me's memberships every launch —
/// no persistence needed. A tenant has no equivalent "which orgs am I a
/// tenant of" endpoint (tenant-self routes all require an orgId up front),
/// so the org id they last accepted an invite into is remembered locally.
class TenantPrefs {
  static const _key = 'tenant_organization_id';
  // Separate from _key: set the moment a join request is submitted (before
  // any Tenancy exists), so IdentityGate knows to check its status on next
  // launch instead of falling through to "no access". Cleared once the
  // request resolves (approved/rejected/cancelled) — see
  // join_request_status_screen.dart.
  static const _pendingJoinKey = 'tenant_pending_join_organization_id';

  static Future<String?> getOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> setOrgId(String orgId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, orgId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<String?> getPendingJoinOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingJoinKey);
  }

  static Future<void> setPendingJoinOrgId(String orgId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingJoinKey, orgId);
  }

  static Future<void> clearPendingJoinOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingJoinKey);
  }
}
