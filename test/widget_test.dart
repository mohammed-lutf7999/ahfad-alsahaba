import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/main.dart';

void main() {
  testWidgets('App loads successfully and displays splash screen', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const IslamicQuizApp());

    // Verify MaterialApp loaded
    expect(find.byType(MaterialApp), findsOneWidget);

    // Advance timer past splash screen delay to resolve pending timers
    await tester.pump(const Duration(seconds: 4));
  });
}
