import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/ui/widgets/navigation/royal_bottom_nav_bar.dart';
import 'package:ahfad_alsahaba/ui/widgets/islamic_quote_card.dart';
import 'package:ahfad_alsahaba/data/models/quote_model.dart';
import 'package:ahfad_alsahaba/ui/dialogs/app_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M7 Royal Bottom Nav Bar & Visual Polish Tests', () {
    testWidgets('RoyalBottomNavBar renders all 5 chivalric tabs and handles taps',
        (WidgetTester tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppCustomTheme.andalusianGold],
          ),
          home: Scaffold(
            bottomNavigationBar: RoyalBottomNavBar(
              currentIndex: 0,
              onTap: (index) {
                tappedIndex = index;
              },
            ),
          ),
        ),
      );

      // Pulse animation repeats infinitely, so we pump frames explicitly
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify all 5 chivalric labels exist
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المكتبة'), findsOneWidget);
      expect(find.text('المجد'), findsOneWidget);
      expect(find.text('المتجر'), findsOneWidget);

      // Verify the center raised crest icon exists
      expect(find.byIcon(Icons.sports_kabaddi_rounded), findsOneWidget);

      // Tap Store (index 4)
      await tester.tap(find.text('المتجر'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tappedIndex, 4);

      // Tap Center Crest (index 2)
      await tester.tap(find.byIcon(Icons.sports_kabaddi_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tappedIndex, 2);
    });

    testWidgets('IslamicQuoteCard renders compact 92px capsule and opens modal sheet on tap',
        (WidgetTester tester) async {
      final sampleQuotes = [
        Quote(
          id: 'q1',
          title: 'حب الله',
          author: 'ابن تيمية',
          text: 'القلب لا يصلح ولا يفلح إلا بعبادة ربه وحده',
          reference: 'مجموع الفتاوى',
        ),
        Quote(
          id: 'q2',
          title: 'قيمة الوقت',
          author: 'ابن القيم',
          text: 'إضاعة الوقت أشد من الموت',
          reference: 'الفوائد',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppCustomTheme.andalusianGold],
          ),
          home: Scaffold(
            body: Center(
              child: IslamicQuoteCard(quotes: sampleQuotes),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify quote text is displayed
      expect(find.textContaining('حب الله'), findsOneWidget);
      expect(find.textContaining('ابن تيمية'), findsOneWidget);

      // Tap the capsule to open the full modal sheet
      await tester.tap(find.byType(IslamicQuoteCard));
      await tester.pumpAndSettle();

      // Verify modal sheet opened with full title and copy button
      expect(find.textContaining('قَبَسٌ مِن نُورِ السَّلَف'), findsOneWidget);
      expect(find.text('نسخ الحكمة المباركة'), findsOneWidget);
    });

    testWidgets('AppDialogs.showExitConfirmationDialog displays royal shield and balanced buttons',
        (WidgetTester tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppCustomTheme.andalusianGold],
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await AppDialogs.showExitConfirmationDialog(
                      context,
                      title: 'هل تود الانسحاب؟',
                      message: 'خروجك الآن يعني فقدان تقدمك في الجولة.',
                      confirmLabel: 'تأكيد الانسحاب',
                      cancelLabel: 'متابعة القتال ⚔️',
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              );
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify royal elements
      expect(find.text('هل تود الانسحاب؟'), findsOneWidget);
      expect(find.text('متابعة القتال ⚔️'), findsOneWidget);
      expect(find.text('تأكيد الانسحاب'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Tap primary continue button
      await tester.tap(find.text('متابعة القتال ⚔️'));
      await tester.pumpAndSettle();

      // Result should be false (do not exit)
      expect(dialogResult, false);
    });
  });
}
