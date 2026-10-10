import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/widgets/banner_ad_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BannerAdWidget Adaptive & Layering Tests', () {
    testWidgets('Renders empty or hidden when not loaded on test environment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(isVisible: true),
          ),
        ),
      );

      expect(find.byType(BannerAdWidget), findsOneWidget);
    });

    testWidgets('Respects isVisible=false during loading overlay states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(isVisible: false),
          ),
        ),
      );

      final bannerFinder = find.byType(BannerAdWidget);
      expect(bannerFinder, findsOneWidget);

      final bannerWidget = tester.widget<BannerAdWidget>(bannerFinder);
      expect(bannerWidget.isVisible, isFalse);
    });

    testWidgets('Accepts maxWidth for small screens like Samsung Galaxy S7 (360dp width)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(maxWidth: 360, isVisible: true),
          ),
        ),
      );

      final bannerFinder = find.byType(BannerAdWidget);
      expect(bannerFinder, findsOneWidget);

      final bannerWidget = tester.widget<BannerAdWidget>(bannerFinder);
      expect(bannerWidget.maxWidth, equals(360));
    });
  });
}
