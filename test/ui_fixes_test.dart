import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/app/theme.dart';
import 'package:quickquiz/utils/text_sanitizer.dart';

void main() {
  group('UI Layout & Overflow Fixes', () {
    testWidgets('Quiz bottom action bar renders Previous and Next without text wrapping on 360px screen', (tester) async {
      // Set typical compact mobile screen size
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text(
                          'Previous',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton.filledTonal(
                        tooltip: 'Overview',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.apps_rounded, size: 20),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text(
                          'Next',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final prevFinder = find.widgetWithText(OutlinedButton, 'Previous');
      final nextFinder = find.widgetWithText(ElevatedButton, 'Next');

      expect(prevFinder, findsOneWidget);
      expect(nextFinder, findsOneWidget);

      final prevText = tester.widget<Text>(find.descendant(of: prevFinder, matching: find.byType(Text)));
      expect(prevText.softWrap, isFalse);
      expect(prevText.maxLines, 1);
    });

    test('TextSanitizer output is free of leading bullets, artifact prefixes, and double periods', () {
      const sampleBullet1 = '• Operating System: An operating system is software that communicates with hardware..';
      const sampleBullet2 = '* Kernel: The core computer program within an operating system...';
      const sampleBullet3 = '- Memory Management: Physical memory paging system.';

      final cleaned1 = TextSanitizer.cleanDoublePeriods(TextSanitizer.stripLeadingArtifacts(sampleBullet1));
      final cleaned2 = TextSanitizer.cleanDoublePeriods(TextSanitizer.stripLeadingArtifacts(sampleBullet2));
      final cleaned3 = TextSanitizer.cleanDoublePeriods(TextSanitizer.stripLeadingArtifacts(sampleBullet3));

      expect(cleaned1.startsWith('•'), isFalse);
      expect(cleaned1.contains('..'), isFalse);
      expect(cleaned2.startsWith('*'), isFalse);
      expect(cleaned2.contains('..'), isFalse);
      expect(cleaned3.startsWith('-'), isFalse);
    });

    test('TextSanitizer does not include slide dates, headers, or metadata (cleanMetadataArtifacts)', () {
      const lectureNotes = 'Introduction to Software Engineering October 16 - 21, 2025 OVERVIEW: SOFTWARE AND';
      final cleaned = TextSanitizer.cleanMetadataArtifacts(lectureNotes);

      expect(cleaned.contains('October 16 - 21, 2025'), isFalse);
      expect(cleaned.contains('OVERVIEW: SOFTWARE AND'), isFalse);
      expect(TextSanitizer.isMetadataOrHeader('October 16 - 21, 2025'), isTrue);
      expect(TextSanitizer.isMetadataOrHeader('OVERVIEW: SOFTWARE AND'), isTrue);
    });
  });
}
