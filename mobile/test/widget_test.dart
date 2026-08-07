// Minimal smoke test — replaces the default counter-app test from
// `flutter create`, which no longer matches this app. Deeper widget tests
// (sign-in flow, screens) come once there's more to test; this just proves
// the app boots without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('RentleApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RentleApp());
    await tester.pump();
    // Signed-out state should show something — we're not asserting exact
    // content here since the Clerk widget's first frame depends on async
    // initialization; just confirming the widget tree builds at all.
    expect(tester.takeException(), isNull);
  });
}
