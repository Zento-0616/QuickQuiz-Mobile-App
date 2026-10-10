import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/services/reward_effect_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardCelebrationPayload Tests', () {
    test('Constructs with expected properties and default values', () {
      const payload = RewardCelebrationPayload(
        id: 'quiz_123',
        title: 'Quiz Completed!',
        rewardText: '+25 XP',
        subtitle: 'Great performance',
        type: RewardType.xp,
        icon: Icons.emoji_events_rounded,
        badgeColor: Colors.amber,
      );

      expect(payload.id, 'quiz_123');
      expect(payload.title, 'Quiz Completed!');
      expect(payload.rewardText, '+25 XP');
      expect(payload.subtitle, 'Great performance');
      expect(payload.type, RewardType.xp);
      expect(payload.icon, Icons.emoji_events_rounded);
      expect(payload.customIcon, Icons.emoji_events_rounded);
      expect(payload.badgeColor, Colors.amber);
      expect(payload.accentColor, Colors.amber);
    });
  });

  group('RewardEffectService Deduplication Tests', () {
    late RewardEffectService service;

    setUp(() {
      service = RewardEffectService();
      service.clearHistory();
    });

    test('isAlreadyAwarded and markAwarded prevent duplicate triggers', () {
      expect(service.isAlreadyAwarded('quiz_complete_1'), false);

      service.markAwarded('quiz_complete_1');
      expect(service.isAlreadyAwarded('quiz_complete_1'), true);

      // Clearing history resets awarded IDs
      service.clearHistory();
      expect(service.isAlreadyAwarded('quiz_complete_1'), false);
    });

    testWidgets('showCelebration honors deduplication for same reward ID', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    final first = service.showCelebration(
                      context,
                      const RewardCelebrationPayload(
                        id: 'dedup_test_reward',
                        title: 'Achievement!',
                        rewardText: '+50 XP',
                      ),
                    );
                    expect(first, true);

                    // Second attempt with same ID should be suppressed/deduplicated
                    final second = service.showCelebration(
                      context,
                      const RewardCelebrationPayload(
                        id: 'dedup_test_reward',
                        title: 'Achievement Duplicate!',
                        rewardText: '+50 XP',
                      ),
                    );
                    expect(second, false);
                  },
                  child: const Text('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(service.isAlreadyAwarded('dedup_test_reward'), true);
    });
  });
}
