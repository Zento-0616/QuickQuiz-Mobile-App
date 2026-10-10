import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/tournament_model.dart';
import 'package:quickquiz/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('1. Dama Tournament Model & Rules', () {
    test('Dama tournament model preserves rules and rewards', () {
      final tournament = TournamentModel(
        title: 'Grand Scholar Dama Championship',
        topic: 'Dama & Strategic Checkers',
        startDateTime: DateTime.now(),
        durationMinutes: 15,
        teamSize: 1,
        winnerExpReward: 1500,
        runnerUpExpReward: 700,
        participantExpReward: 200,
        gameType: 'dama',
      );

      expect(tournament.teamSize, 1);
      expect(tournament.winnerExpReward, 1500);
      expect(tournament.isDama, isTrue);
    });
  });

  group('2. Scholar Nickname & Profile Length Safety (Overflow Prevention)', () {
    test('User with long nickname and email formats safely without error', () {
      final longScholar = UserModel(
        uid: 'scholar_long_name',
        name: 'Reynaldo Seroje Professional Scholar of Engineering',
        email: 'lazarus.aeo16@global-scholars-university.edu.ph',
        nickname: 'Reynaldo Seroje Long Academic Title',
        createdAt: DateTime.now(),
        level: 4,
        exp: 1250,
      );

      expect(longScholar.effectiveNickname, 'Reynaldo Seroje Long Academic Title');
      expect(longScholar.effectiveNickname.length, greaterThan(20));
      expect(longScholar.level, 4);
      expect(longScholar.exp, 1250);
    });
  });
}
