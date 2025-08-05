// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prescription_reminder/main.dart';

void main() {
  testWidgets('App starts with correct title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is correct.
    expect(find.text('MedAssist'), findsOneWidget);

    // Verify that we see the empty state initially
    expect(find.text('No Prescriptions Yet'), findsOneWidget);

    // Verify that the floating action button is present
    expect(find.byIcon(Icons.add_alert), findsOneWidget);
  });
}
