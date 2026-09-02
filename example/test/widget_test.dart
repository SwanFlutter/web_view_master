// Widget test for the example app's launcher page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_view_master_example/main.dart';

void main() {
  testWidgets('launcher offers a button per platform plus an address field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    // One button per supported platform, labelled with the platform name.
    for (final target in kTargets) {
      expect(find.text(target.label), findsOneWidget, reason: target.label);
    }

    // The address field is pre-filled with the bundled test page and the
    // quick-pick chips offer the payment-gateway URLs.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, kLocalTestPage);
    expect(find.text('نمایش در WebView'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(kQuickLinks.length));
  });
}
