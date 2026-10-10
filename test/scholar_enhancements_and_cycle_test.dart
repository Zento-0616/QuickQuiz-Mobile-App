import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/message_model.dart';
import 'package:quickquiz/services/progression_service.dart';

void main() {
  group('ProgressionService 4:00 PM Daily Cycle Tests', () {
    test('getDailyCycleStart sets start to 16:00 on current day if time >= 16:00', () {
      final dt = DateTime(2026, 9, 10, 16, 30);
      final cycleStart = ProgressionService.getDailyCycleStart(dt);

      expect(cycleStart.year, 2026);
      expect(cycleStart.month, 9);
      expect(cycleStart.day, 10);
      expect(cycleStart.hour, 16);
    });

    test('getDailyCycleStart sets start to 16:00 on previous day if time < 16:00', () {
      final dt = DateTime(2026, 9, 10, 15, 45);
      final cycleStart = ProgressionService.getDailyCycleStart(dt);

      expect(cycleStart.year, 2026);
      expect(cycleStart.month, 9);
      expect(cycleStart.day, 9);
      expect(cycleStart.hour, 16);
    });

    test('isSameDailyCycle returns true if both times are within the same 4:00 PM window', () {
      // Both belong to cycle starting 2026-09-09 16:00
      final evening = DateTime(2026, 9, 9, 20, 0);
      final nextMorning = DateTime(2026, 9, 10, 11, 0);

      expect(ProgressionService.isSameDailyCycle(evening, nextMorning), isTrue);
    });

    test('isSameDailyCycle returns false when crossing the 4:00 PM refresh threshold', () {
      final before4pm = DateTime(2026, 9, 10, 15, 59, 59);
      final after4pm = DateTime(2026, 9, 10, 16, 0, 1);

      expect(ProgressionService.isSameDailyCycle(before4pm, after4pm), isFalse);
    });

    test('evaluateDailyStreak increments across consecutive 4:00 PM cycles', () {
      final yesterdayCycle = DateTime(2026, 9, 9, 18, 0);
      // Simulating evaluateDailyStreak with last active in previous cycle
      final streak = ProgressionService.evaluateDailyStreak(
        lastActive: yesterdayCycle,
        currentStreak: 3,
      );
      // Will evaluate against DateTime.now(), so let's verify difference logic
      final cycleNow = ProgressionService.getDailyCycleStart();
      final diff = cycleNow.difference(ProgressionService.getDailyCycleStart(yesterdayCycle)).inDays;

      if (diff == 0) {
        expect(streak, 3);
      } else if (diff == 1) {
        expect(streak, 4);
      } else {
        expect(streak, 1);
      }
    });
  });

  group('MessageModel EXP Gift Tests', () {
    test('MessageModel supports isExpGift and expGiftAmount fields', () {
      final msg = MessageModel(
        chatRoomId: 'room_123',
        senderId: 'admin_uid',
        senderNickname: 'Admin',
        text: 'Well done on tournament!',
        isExpGift: true,
        expGiftAmount: 750,
        expGiftClaimed: false,
      );

      final json = msg.toJson();
      expect(json['isExpGift'], isTrue);
      expect(json['expGiftAmount'], 750);
      expect(json['expGiftClaimed'], isFalse);

      final restored = MessageModel.fromJson(json);
      expect(restored.isExpGift, isTrue);
      expect(restored.expGiftAmount, 750);
      expect(restored.expGiftClaimed, isFalse);
    });

    test('MessageModel copyWith can mark EXP gift as claimed', () {
      final msg = MessageModel(
        chatRoomId: 'room_123',
        senderId: 'admin_uid',
        senderNickname: 'Admin',
        text: 'Gift',
        isExpGift: true,
        expGiftAmount: 500,
      );

      final claimedMsg = msg.copyWith(expGiftClaimed: true);
      expect(claimedMsg.expGiftClaimed, isTrue);
      expect(claimedMsg.expGiftAmount, 500);
    });
  });
}
