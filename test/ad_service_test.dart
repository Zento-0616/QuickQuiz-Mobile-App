import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/services/ad_service.dart';

void main() {
  group('AdService Post-Exam Interstitial Ad Tests', () {
    test('showInterstitial calls onComplete immediately when no ad is loaded or ready', () {
      final adService = AdService();
      bool completed = false;

      adService.showInterstitial(
        onComplete: () {
          completed = true;
        },
      );

      expect(completed, isTrue);
    });

    test('showInterstitial accepts autoDismissDuration without throwing', () {
      final adService = AdService();
      bool completed = false;

      adService.showInterstitial(
        onComplete: () {
          completed = true;
        },
        autoDismissDuration: const Duration(seconds: 3),
      );

      expect(completed, isTrue);
    });
  });
}
