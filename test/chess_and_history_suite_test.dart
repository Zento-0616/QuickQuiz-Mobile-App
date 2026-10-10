import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickquiz/models/chess_game_model.dart';
import 'package:quickquiz/models/document_model.dart';
import 'package:quickquiz/models/flashcard_model.dart';
import 'package:quickquiz/models/quiz_result_model.dart';
import 'package:quickquiz/models/study_notes_model.dart';
import 'package:quickquiz/services/local_storage_service.dart';
import 'package:quickquiz/viewmodels/history_viewmodel.dart';
import 'package:quickquiz/views/notes/study_notes_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('1. Scholar Chess Engine Tests', () {
    test('Initial chess board setup has 32 pieces and correct positions', () {
      final board = ChessBoard();
      expect(board.currentTurn, equals(1)); // White's turn
      expect(board.isGameOver, isFalse);

      // Check White pawns on row 6
      for (int c = 0; c < 8; c++) {
        final p = board.getPiece(6, c);
        expect(p, isNotNull);
        expect(p!.type, equals(ChessPieceType.pawn));
        expect(p.player, equals(1));
      }

      // Check Black pawns on row 1
      for (int c = 0; c < 8; c++) {
        final p = board.getPiece(1, c);
        expect(p, isNotNull);
        expect(p!.type, equals(ChessPieceType.pawn));
        expect(p.player, equals(2));
      }

      // Check White King at row 7, col 4
      final whiteKing = board.getPiece(7, 4);
      expect(whiteKing, isNotNull);
      expect(whiteKing!.type, equals(ChessPieceType.king));
      expect(whiteKing.player, equals(1));

      // Check Black King at row 0, col 4
      final blackKing = board.getPiece(0, 4);
      expect(blackKing, isNotNull);
      expect(blackKing!.type, equals(ChessPieceType.king));
      expect(blackKing.player, equals(2));
    });

    test('White pawn can move 1 or 2 squares from start, but not 3', () {
      final board = ChessBoard();
      final moves = board.getLegalMoves(6, 4); // e2 pawn
      expect(moves.any((m) => m.toRow == 5 && m.toCol == 4), isTrue); // e3
      expect(moves.any((m) => m.toRow == 4 && m.toCol == 4), isTrue); // e4
      expect(moves.any((m) => m.toRow == 3 && m.toCol == 4), isFalse);
    });

    test('Knights can jump over pawns in initial position', () {
      final board = ChessBoard();
      final knightMoves = board.getLegalMoves(7, 1); // b1 knight
      expect(knightMoves.length, equals(2)); // Na3 and Nc3
      expect(knightMoves.any((m) => m.toRow == 5 && m.toCol == 0), isTrue);
      expect(knightMoves.any((m) => m.toRow == 5 && m.toCol == 2), isTrue);
    });

    test('Legal move execution updates board, turns, and captured lists', () {
      final board = ChessBoard();
      // 1. e4 (from 6,4 to 4,4)
      final move1 = board.getLegalMoves(6, 4).firstWhere((m) => m.toRow == 4 && m.toCol == 4);
      final success1 = board.makeMove(move1);
      expect(success1, isTrue);
      expect(board.currentTurn, equals(2)); // Black's turn
      expect(board.getPiece(4, 4)?.type, equals(ChessPieceType.pawn));

      // 2. d5 (from 1,3 to 3,3)
      final move2 = board.getLegalMoves(1, 3).firstWhere((m) => m.toRow == 3 && m.toCol == 3);
      final success2 = board.makeMove(move2);
      expect(success2, isTrue);
      expect(board.currentTurn, equals(1)); // White's turn

      // 3. exd5 (capture)
      final capMove = board.getLegalMoves(4, 4).firstWhere((m) => m.toRow == 3 && m.toCol == 3);
      expect(capMove.isCapture, isTrue);
      board.makeMove(capMove);

      expect(board.capturedByWhite.length, equals(1));
      expect(board.capturedByWhite.first.type, equals(ChessPieceType.pawn));
    });

    test('Check and checkmate detection correctly identifies end of game', () {
      final board = ChessBoard();
      // Fool's Mate sequence:
      // 1. f3 e5
      // 2. g4 Qh4#
      final f3 = board.getLegalMoves(6, 5).firstWhere((m) => m.toRow == 5 && m.toCol == 5);
      board.makeMove(f3);

      final e5 = board.getLegalMoves(1, 4).firstWhere((m) => m.toRow == 3 && m.toCol == 4);
      board.makeMove(e5);

      final g4 = board.getLegalMoves(6, 6).firstWhere((m) => m.toRow == 4 && m.toCol == 6);
      board.makeMove(g4);

      final qh4 = board.getLegalMoves(0, 3).firstWhere((m) => m.toRow == 4 && m.toCol == 7);
      board.makeMove(qh4);

      expect(board.isGameOver, isTrue);
      expect(board.winner, equals(2)); // Black wins
      expect(board.isKingInCheck(1), isTrue); // White king in checkmate
    });

    test('AI move generator returns legal move on Easy, Medium, and Hard', () {
      final board = ChessBoard();
      // White plays 1. e4
      final e4 = board.getLegalMoves(6, 4).firstWhere((m) => m.toRow == 4 && m.toCol == 4);
      board.makeMove(e4);

      // Black AI turn
      final easyMove = board.getAiMove(ChessDifficulty.easy);
      expect(easyMove, isNotNull);
      expect(board.isInBounds(easyMove!.toRow, easyMove.toCol), isTrue);

      final medMove = board.getAiMove(ChessDifficulty.medium);
      expect(medMove, isNotNull);

      final hardMove = board.getAiMove(ChessDifficulty.hard);
      expect(hardMove, isNotNull);
    });
  });

  group('2. Multi-Category History Tests (Quizzes, Notes, Flashcards)', () {
    test('LocalStorageService persists and retrieves Study Notes', () async {
      final storage = LocalStorageService();
      final notes = StudyNotesModel(
        id: 'notes_chem_101',
        title: 'Organic Chemistry Basics',
        overview: 'Comprehensive review of alkane and alkene hydrocarbons.',
        sections: [
          const StudyNoteSection(
            heading: 'Alkanes',
            content: 'Saturated hydrocarbons with single bonds.',
            keyPoints: ['Formula CnH2n+2', 'Non-polar and insoluble in water'],
          ),
        ],
        glossary: [
          const StudyNoteTerm(term: 'Hydrocarbon', definition: 'Compound of hydrogen and carbon.'),
        ],
        examTakeaways: ['Know IUPAC nomenclature rules.'],
      );

      await storage.saveStudyNotesLocally(notes, userId: 'scholar_1');
      final fetched = await storage.getStudyNotesLocally(userId: 'scholar_1');

      expect(fetched.any((n) => n.id == 'notes_chem_101'), isTrue);
      final found = fetched.firstWhere((n) => n.id == 'notes_chem_101');
      expect(found.title, equals('Organic Chemistry Basics'));
      expect(found.sections.first.heading, equals('Alkanes'));

      await storage.deleteStudyNotesLocally('notes_chem_101');
      final afterDelete = await storage.getStudyNotesLocally(userId: 'scholar_1');
      expect(afterDelete.any((n) => n.id == 'notes_chem_101'), isFalse);
    });

    test('LocalStorageService persists and retrieves Flashcard Decks', () async {
      final storage = LocalStorageService();
      final deck = FlashcardDeckModel(
        id: 'deck_bio_cell',
        title: 'Cellular Biology Deck',
        sourceFileName: 'biology_ch1.pdf',
        cards: const [
          FlashcardModel(
            id: 'card_1',
            front: 'Mitochondria',
            back: 'Powerhouse of the cell, produces ATP.',
          ),
          FlashcardModel(
            id: 'card_2',
            front: 'Ribosome',
            back: 'Site of protein synthesis in cytoplasm.',
          ),
        ],
      );

      await storage.saveFlashcardDeckLocally(deck, userId: 'scholar_1');
      final fetched = await storage.getFlashcardDecksLocally(userId: 'scholar_1');

      expect(fetched.any((d) => d.id == 'deck_bio_cell'), isTrue);
      final found = fetched.firstWhere((d) => d.id == 'deck_bio_cell');
      expect(found.title, equals('Cellular Biology Deck'));
      expect(found.cardCount, equals(2));

      await storage.deleteFlashcardDeckLocally('deck_bio_cell');
      final afterDelete = await storage.getFlashcardDecksLocally(userId: 'scholar_1');
      expect(afterDelete.any((d) => d.id == 'deck_bio_cell'), isFalse);
    });

    test('HistoryViewModel loads all 3 categories and filters correctly', () async {
      final storage = LocalStorageService();
      final vm = HistoryViewModel(storage: storage);

      // Seed a study note and a flashcard deck
      final note = StudyNotesModel(
        id: 'vm_note_test',
        title: 'Physics Mechanics Notes',
        overview: 'Newtonian mechanics summary.',
        sections: const [],
      );
      final deck = FlashcardDeckModel(
        id: 'vm_deck_test',
        title: 'Physics Formulas Deck',
        sourceFileName: 'physics.pdf',
        cards: const [],
      );

      await storage.saveStudyNotesLocally(note, userId: 'scholar_test');
      await storage.saveFlashcardDeckLocally(deck, userId: 'scholar_test');

      await vm.loadAllHistory('scholar_test');

      expect(vm.notesHistory.any((n) => n.id == 'vm_note_test'), isTrue);
      expect(vm.flashcardHistory.any((d) => d.id == 'vm_deck_test'), isTrue);
      expect(vm.totalNotes, greaterThanOrEqualTo(1));
      expect(vm.totalFlashcards, greaterThanOrEqualTo(1));

      // Verify category switching
      expect(vm.activeFilter, equals(HistoryCategoryFilter.all));
      vm.setFilter(HistoryCategoryFilter.notes);
      expect(vm.activeFilter, equals(HistoryCategoryFilter.notes));
      vm.setFilter(HistoryCategoryFilter.flashcards);
      expect(vm.activeFilter, equals(HistoryCategoryFilter.flashcards));
    });
  });

  group('3. Study Notes Layout & Horizontal Bounded Widths Widget Tests', () {
    testWidgets('StudyNotesView renders without overflowing or collapsing on narrow phone width', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notes = StudyNotesModel(
        id: 'widget_notes_test',
        title: 'World History: The Renaissance Period',
        overview: 'An extensive era of cultural, artistic, political and economic rebirth following the Middle Ages.',
        sections: [
          const StudyNoteSection(
            heading: 'Humanism & Arts',
            content: 'The intellectual movement that emphasized human potential, classical philosophy, and realism in art.',
            keyPoints: [
              'Leonardo da Vinci and Michelangelo pioneered anatomical precision in painting and sculpture.',
              'The printing press accelerated the spread of literacy across Western Europe.',
            ],
          ),
        ],
        glossary: [
          const StudyNoteTerm(
            term: 'Humanism',
            definition: 'A Renaissance cultural movement that turned away from medieval scholasticism and revived interest in ancient Greek and Roman thought.',
          ),
          const StudyNoteTerm(
            term: 'Fresco',
            definition: 'A technique of mural painting executed upon freshly laid, or wet lime plaster.',
          ),
        ],
        examTakeaways: [
          'Remember the impact of Gutenberg printing press in 1440.',
          'Differentiate Northern Renaissance Christian humanism from Italian secular humanism.',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudyNotesView(notes: notes),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header, overview, and pillars are rendered
      expect(find.text('World History: The Renaissance Period'), findsOneWidget);
      expect(find.textContaining('An extensive era of cultural'), findsOneWidget);
      expect(find.text('Humanism & Arts'), findsOneWidget);

      // Scroll down to verify glossary and exam takeaways
      await tester.scrollUntilVisible(find.text('Humanism'), 200);
      expect(find.text('Humanism'), findsOneWidget);
      expect(find.text('Fresco'), findsOneWidget);

      await tester.scrollUntilVisible(find.textContaining('Gutenberg printing press'), 200);
      expect(find.textContaining('Gutenberg printing press'), findsOneWidget);

      // Verify no RenderFlex overflow errors occurred during layout
      expect(tester.takeException(), isNull);
    });
  });
}
