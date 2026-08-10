import 'dart:math';

/// A fresh key per user-initiated mutation (invoice generation, payment
/// recording) — sent as `Idempotency-Key`, backed by the server's
/// idempotency_keys table, so a double-tap or a retried request after a
/// dropped connection can't double-record the same action.
String newIdempotencyKey() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
