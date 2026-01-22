import 'package:flutter_test/flutter_test.dart';

import 'package:suivi_kine/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SuiviKineApp());

    // Verify that the app title is displayed
    expect(find.text('Kinésithérapie 2025-2026'), findsOneWidget);
  });
}
