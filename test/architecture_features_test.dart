import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/chat_room_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:quickquiz/services/profanity_filter_service.dart';
import 'package:quickquiz/services/progression_service.dart';
import 'package:quickquiz/services/social_service.dart';

void main() {
  group('1. Profanity Filter & Nickname Validation Tests', () {
    test('ProfanityFilterService catches direct and leetspeak profanity', () {
      expect(ProfanityFilterService.hasProfanity('hello world'), isFalse);
      expect(ProfanityFilterService.hasProfanity('damn you'), isTrue);
      expect(ProfanityFilterService.hasProfanity('b!tch'), isTrue);
      expect(ProfanityFilterService.hasProfanity('sh!t'), isTrue);
      expect(ProfanityFilterService.hasProfanity('f*ck'), isTrue);
    });

    test('ProfanityFilterService validates nickname length and rules', () {
      expect(ProfanityFilterService.validateNickname(''), isNotNull);
      expect(ProfanityFilterService.validateNickname('ab'), isNotNull); // Too short
      expect(ProfanityFilterService.validateNickname('AlexStar'), isNull); // Valid
      expect(ProfanityFilterService.validateNickname('bad_bitch_99'), isNotNull); // Profane
      expect(ProfanityFilterService.validateNickname('Scholar_2026'), isNull); // Valid
    });
  });

  group('2. Gamification, EXP & Progression Engine Tests', () {
    test('calculateExp calculates base, accuracy, multiplier, and perfect bonus', () {
      // 5 questions, 5 correct, 1.0x -> 100 base + 50 perfect bonus = 150
      final expPerfect = ProgressionService.calculateExp(
        questionCount: 5,
        correctCount: 5,
        multiplier: 1.0,
      );
      expect(expPerfect, 150);

      // 10 questions, 5 correct, 2.0x -> (200 * 0.5 * 2.0) = 200 (no perfect bonus)
      final expHalf = ProgressionService.calculateExp(
        questionCount: 10,
        correctCount: 5,
        multiplier: 2.0,
      );
      expect(expHalf, 200);

      // Minimum participation EXP guarantee
      final expZero = ProgressionService.calculateExp(
        questionCount: 5,
        correctCount: 0,
        multiplier: 1.0,
      );
      expect(expZero, greaterThanOrEqualTo(15));
    });

    test('calculateLevelFromExp scales thresholds', () {
      expect(ProgressionService.calculateLevelFromExp(0), 1);
      expect(ProgressionService.calculateLevelFromExp(100), 1);
      expect(ProgressionService.calculateLevelFromExp(150), 2);
      expect(ProgressionService.calculateLevelFromExp(450), 3);
    });

    test('evaluateDailyStreak calculates streak correctly', () {
      final now = DateTime.now();

      // Same day activity: streak maintained
      final streakSame = ProgressionService.evaluateDailyStreak(
        lastActive: now,
        currentStreak: 5,
      );
      expect(streakSame, 5);

      // Yesterday: streak incremented
      final yesterday = now.subtract(const Duration(days: 1));
      final streakNext = ProgressionService.evaluateDailyStreak(
        lastActive: yesterday,
        currentStreak: 5,
      );
      expect(streakNext, 6);

      // 3 days ago: streak reset to 1
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final streakReset = ProgressionService.evaluateDailyStreak(
        lastActive: threeDaysAgo,
        currentStreak: 5,
      );
      expect(streakReset, 1);
    });

    test('UserModel getters compute win rate and level progress correctly', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Alex Vance',
        nickname: 'AlexStar',
        email: 'alex@example.com',
        createdAt: DateTime(2026, 1, 1),
        level: 2,
        exp: 200,
        quizzesPlayed: 10,
        totalCorrect: 8,
        totalQuestions: 10,
        role: 'admin',
      );

      expect(user.isAdmin, isTrue);
      expect(user.winRate, 80);
      expect(user.expForNextLevel, 300); // 2 * 150
      expect(user.currentLevelExp, 200);
      expect(user.levelProgressFraction, closeTo(200 / 300, 0.01));
    });
  });

  group('3. Social, Messaging & Strict Friendship Rules Tests', () {
    final userAlice = UserModel(
      uid: 'user_alice',
      name: 'Alice',
      nickname: 'AliceQ',
      email: 'alice@example.com',
      createdAt: DateTime.now(),
    );

    final userBob = UserModel(
      uid: 'user_bob',
      name: 'Bob',
      nickname: 'BobQ',
      email: 'bob@example.com',
      createdAt: DateTime.now(),
    );

    final userCharlie = UserModel(
      uid: 'user_charlie',
      name: 'Charlie',
      nickname: 'CharlieQ',
      email: 'charlie@example.com',
      createdAt: DateTime.now(),
    );

    test('ChatRoomModel enforces maximum 5 players constraint', () {
      expect(
        () => ChatRoomModel(
          id: 'room_1',
          name: 'Squad',
          memberIds: ['1', '2', '3', '4', '5'],
          memberNicknames: {},
          adminId: '1',
        ),
        returnsNormally,
      );

      expect(
        () => ChatRoomModel(
          id: 'room_2',
          name: 'Squad Too Big',
          memberIds: ['1', '2', '3', '4', '5', '6'],
          memberNicknames: {},
          adminId: '1',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('SocialService STRICT PRIVACY LOCK prevents messaging non-friends', () async {
      final socialService = SocialService();

      // Alice and Bob are NOT friends initially -> getOrCreateOneOnOneChat MUST throw
      expect(
        () => socialService.getOrCreateOneOnOneChat(
          currentUser: userAlice,
          friendUser: userBob,
        ),
        throwsA(
          predicate((e) => e.toString().contains('STRICT PRIVACY LOCK')),
        ),
      );
    });

    test('SocialService accepts friend request and enables 1-on-1 chat', () async {
      final socialService = SocialService();

      // 1. Send Friend Request
      await socialService.sendFriendRequest(
        currentUser: userAlice,
        targetUser: userBob,
      );

      // Status should be pending
      final statusSent = await socialService.getFriendshipStatus(userAlice.uid, userBob.uid);
      expect(statusSent, FriendshipState.pendingSent);

      // 2. Accept Friend Request
      final requests = await socialService.getPendingRequests(userBob.uid);
      final req = requests.firstWhere((r) => r.senderId == userAlice.uid);
      await socialService.acceptFriendRequest(req);

      // Status should now be friends
      final statusFriends = await socialService.getFriendshipStatus(userAlice.uid, userBob.uid);
      expect(statusFriends, FriendshipState.friends);

      // 3. Now 1-on-1 chat creation MUST succeed
      final chat = await socialService.getOrCreateOneOnOneChat(
        currentUser: userAlice,
        friendUser: userBob,
      );
      expect(chat, isNotNull);
      expect(chat.memberIds, containsAll([userAlice.uid, userBob.uid]));
    });

    test('SocialService Group Chat enforces max 5 players and Friend-Only invitations', () async {
      final socialService = SocialService();

      // Alice tries to invite Charlie (who is not a friend) -> MUST throw
      expect(
        () => socialService.createGroupChat(
          currentUser: userAlice,
          groupName: 'Secret Squad',
          invitedFriends: [userCharlie],
        ),
        throwsA(
          predicate((e) => e.toString().contains('Friend-Only Invitations')),
        ),
      );

      // Alice tries to invite > 4 friends (total > 5) -> MUST throw
      final manyUsers = List.generate(
        5,
        (i) => UserModel(
          uid: 'user_dummy_$i',
          name: 'Dummy $i',
          email: 'd$i@test.com',
          createdAt: DateTime.now(),
        ),
      );

      expect(
        () => socialService.createGroupChat(
          currentUser: userAlice,
          groupName: 'Big Squad',
          invitedFriends: manyUsers,
        ),
        throwsA(
          predicate((e) => e.toString().contains('cannot exceed 5 players')),
        ),
      );
    });
  });
}
