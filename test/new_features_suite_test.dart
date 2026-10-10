import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickquiz/models/dama_game_model.dart';
import 'package:quickquiz/models/document_model.dart';
import 'package:quickquiz/models/question_model.dart';
import 'package:quickquiz/models/quiz_model.dart';
import 'package:quickquiz/models/quiz_settings_model.dart';
import 'package:quickquiz/models/study_notes_model.dart';
import 'package:quickquiz/viewmodels/quiz_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Multi-File Upload & DocumentModel Tests', () {
    test('Combining up to 3 documents merges contents, preserves sources, and updates metadata', () {
      const doc1 = DocumentModel(
        fileName: 'Lecture 1.pdf',
        extractedText: 'Content of lecture 1',
        type: DocumentType.pdf,
        fileSizeBytes: 1024 * 500,
      );
      const doc2 = DocumentModel(
        fileName: 'Notes.docx',
        extractedText: 'Content of notes docx',
        type: DocumentType.docx,
        fileSizeBytes: 1024 * 300,
      );
      const doc3 = DocumentModel(
        fileName: 'Slides.pptx',
        extractedText: 'Content of slides pptx',
        type: DocumentType.pptx,
        fileSizeBytes: 1024 * 1200,
      );

      final combined = DocumentModel.combine([doc1, doc2, doc3]);

      expect(combined.sourceDocuments, isNotNull);
      expect(combined.sourceDocuments!.length, 3);
      expect(combined.fileName, contains('Lecture 1.pdf'));
      expect(combined.fileName, contains('Notes.docx'));
      expect(combined.fileName, contains('Slides.pptx'));
      expect(combined.fileCount, 3);
      expect(combined.extractedText, contains('=== SOURCE FILE 1: Lecture 1.pdf'));
      expect(combined.extractedText, contains('=== SOURCE FILE 2: Notes.docx'));
      expect(combined.extractedText, contains('=== SOURCE FILE 3: Slides.pptx'));
    });

    test('Single document combine returns identical single source document', () {
      const doc = DocumentModel(
        fileName: 'Single.pdf',
        extractedText: 'Single document content',
        type: DocumentType.pdf,
        fileSizeBytes: 1024 * 200,
      );

      final combined = DocumentModel.combine([doc]);
      expect(combined.sourceDocuments, isNotNull);
      expect(combined.sourceDocuments!.length, 1);
      expect(combined.fileName, 'Single.pdf');
      expect(combined.extractedText, 'Single document content');
    });
  });

  group('2. Study Notes Model & Markdown Generation Tests', () {
    test('StudyNotesModel holds structured chapters, glossaries, and exports clean markdown', () {
      final notes = StudyNotesModel(
        title: 'Physics 101 Study Notes',
        sourceFileNames: ['Lecture 1.pdf', 'Lecture 2.pdf'],
        overview: 'Comprehensive overview of classical mechanics and kinematics.',
        sections: [
          const StudyNoteSection(
            heading: 'Newtonian Dynamics',
            content: 'Core principles of forces, inertia, and momentum.',
            keyPoints: [
              'First law: An object at rest stays at rest.',
              'Second law: F = ma.',
              'Third law: Equal and opposite reaction.',
            ],
          ),
        ],
        glossary: [
          const StudyNoteTerm(
            term: 'Inertia',
            definition: 'Resistance of any physical object to any change in its velocity.',
          ),
        ],
        examTakeaways: [
          'Master calculating net force vectors.',
          'Memorize units for force (Newtons = kg*m/s^2).',
        ],
      );

      final markdown = notes.toMarkdown();
      expect(markdown, contains('# Physics 101 Study Notes'));
      expect(markdown, contains('Newtonian Dynamics'));
      expect(markdown, contains('Second law: F = ma.'));
      expect(markdown, contains('**Inertia**: Resistance of any physical object'));
      expect(markdown, contains('High-Yield Exam Takeaways'));
    });
  });

  group('3. Hard Mode Quiz: MCQs, Fill-in-the-Blank & Strict Locking', () {
    test('Fill-in-the-blank questions accurately evaluate acceptable answers and formulas', () {
      const question = QuestionModel(
        id: 'q1',
        question: 'According to Newton, the formula for force is ______.',
        options: [],
        correctAnswerIndex: -1,
        type: QuestionType.fillInBlank,
        acceptableAnswers: ['F = ma', 'f=ma', 'F=ma', 'f = m * a', 'Force = mass * acceleration'],
        explanation: 'F = ma describes Newton\'s second law.',
      );

      expect(question.isFillInBlank, isTrue);
      // Case, whitespace and symbol normalization
      expect(question.checkFillInBlankCorrectness('F = ma'), isTrue);
      expect(question.checkFillInBlankCorrectness('f = ma'), isTrue);
      expect(question.checkFillInBlankCorrectness('F=ma'), isTrue);
      expect(question.checkFillInBlankCorrectness('force = mass * acceleration'), isTrue);
      // Incorrect answer
      expect(question.checkFillInBlankCorrectness('E = mc^2'), isFalse);
    });

    test('QuizViewModel strictly locks answers on Hard difficulty after submission', () {
      final questions = [
        const QuestionModel(
          id: 'q1',
          question: 'The unit of electrical resistance is the ______.',
          options: [],
          correctAnswerIndex: -1,
          type: QuestionType.fillInBlank,
          acceptableAnswers: ['Ohm', 'ohm', 'ohms', 'Ω'],
          explanation: 'Ohm is the SI unit of electrical resistance.',
        ),
        const QuestionModel(
          id: 'q2',
          question: 'What is the powerhouse of the cell?',
          options: ['Nucleus', 'Mitochondria', 'Ribosome', 'Vacuole'],
          correctAnswerIndex: 1,
          explanation: 'Mitochondria generate most of the chemical energy needed to power the cell.',
        ),
      ];

      final quiz = QuizModel(
        id: 'test_quiz',
        title: 'Hard Rigor Exam',
        sourceFileName: 'biology_notes.pdf',
        questions: questions,
        difficulty: QuizDifficulty.hard,
      );

      final vm = QuizViewModel(quiz);

      // Question 1: Fill in blank
      expect(vm.isAnswerLocked, isFalse);
      vm.submitTextAnswer('Ohm');

      // Now answered on Hard mode -> must be locked!
      expect(vm.currentQuestion.isAnswered, isTrue);
      expect(vm.currentQuestion.isCorrect, isTrue);
      expect(vm.isAnswerLocked, isTrue);

      // Attempting to change locked answer must be ignored
      vm.submitTextAnswer('Ampere');
      expect(vm.currentQuestion.userTextAnswer, 'Ohm');

      // Navigate to Question 2 (MCQ)
      vm.goToNext();
      expect(vm.currentIndex, 1);
      expect(vm.isAnswerLocked, isFalse);

      final correctIdx = vm.currentQuestion.correctAnswerIndex;
      vm.selectAnswer(correctIdx);
      expect(vm.currentQuestion.isAnswered, isTrue);
      expect(vm.currentQuestion.isCorrect, isTrue);
      expect(vm.isAnswerLocked, isTrue);

      // Attempting to switch MCQ option on Hard mode must be ignored
      final otherIdx = (correctIdx + 1) % vm.currentQuestion.options.length;
      vm.selectAnswer(otherIdx);
      expect(vm.currentQuestion.selectedAnswerIndex, correctIdx);

      vm.dispose();
    });
  });

  group('4. Dama Game Engine: Multiple Moves & Chained Captures', () {
    test('Dama board properly alternates turns on standard non-capture moves', () {
      final board = DamaBoard();
      expect(board.currentTurn, 1);

      // Move piece from [5, 2] to [4, 1]
      final moveP1 = const DamaMove(fromRow: 5, fromCol: 2, toRow: 4, toCol: 1);
      final okP1 = board.makeMove(moveP1);
      expect(okP1, isTrue);
      expect(board.currentTurn, 2);
      expect(board.multiCapturePiece, isNull);

      // Move P2 piece from [2, 1] to [3, 2]
      final moveP2 = const DamaMove(fromRow: 2, fromCol: 1, toRow: 3, toCol: 2);
      final okP2 = board.makeMove(moveP2);
      expect(okP2, isTrue);
      expect(board.currentTurn, 1);
      expect(board.multiCapturePiece, isNull);
    });

    test('Consecutive multi-jump capture preserves turn until sequence is finished', () {
      final board = DamaBoard();
      // Clear board for a clean multi-jump scenario
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));

      // Player 1 piece at [5, 2]
      // Enemy 1 at [4, 3], landing at [3, 4] empty
      // Enemy 2 at [2, 5], landing at [1, 6] empty
      board.grid[5][2] = DamaPiece(player: 1);
      board.grid[4][3] = DamaPiece(player: 2);
      board.grid[2][5] = DamaPiece(player: 2);
      board.currentTurn = 1;

      // First hop: [5, 2] -> [3, 4]
      final moves = board.getLegalMoves(5, 2);
      expect(moves.length, 1);
      final hop1 = moves.first;
      expect(hop1.toRow, 3);
      expect(hop1.toCol, 4);

      final success1 = board.makeMove(hop1);
      expect(success1, isTrue);
      expect(board.grid[5][2], isNull);
      expect(board.grid[4][3], isNull); // Enemy 1 captured!
      expect(board.grid[3][4]?.player, 1); // Piece landed
      expect(board.capturedByP1, 1);

      // Chained jump must be active!
      expect(board.multiCapturePiece, const Point(3, 4));
      expect(board.currentTurn, 1); // Turn must stay with Player 1!

      // Legal moves now should only be for [3, 4]
      final chainedMoves = board.getLegalMoves(3, 4);
      expect(chainedMoves.length, 1);
      final hop2 = chainedMoves.first;
      expect(hop2.toRow, 1);
      expect(hop2.toCol, 6);

      // Execute second hop
      final success2 = board.makeMove(hop2);
      expect(success2, isTrue);
      expect(board.grid[3][4], isNull);
      expect(board.grid[2][5], isNull); // Enemy 2 captured!
      expect(board.grid[1][6]?.player, 1);
      expect(board.capturedByP1, 2);

      // No more captures from [1, 6], so turn completes!
      expect(board.multiCapturePiece, isNull);
      expect(board.currentTurn, 2); // Now switched to Player 2
    });

    test('AI Bot prioritizes captures and never returns null when moves are available', () {
      final board = DamaBoard();
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));

      // AI (Player 2) at [2, 1]
      // Player 1 at [3, 2], landing at [4, 3] empty
      board.grid[2][1] = DamaPiece(player: 2);
      board.grid[3][2] = DamaPiece(player: 1);
      board.currentTurn = 2;

      final aiMove = board.getAiMove(DamaDifficulty.hard);
      expect(aiMove, isNotNull);
      expect(aiMove!.isCapture, isTrue);
      expect(aiMove.toRow, 4);
      expect(aiMove.toCol, 3);

      final ok = board.makeMove(aiMove);
      expect(ok, isTrue);
      expect(board.capturedByP2, 1);
      expect(board.grid[3][2], isNull);
    });

    test('AI handles no-move game-over situation cleanly without freezing', () {
      final board = DamaBoard();
      board.grid = List.generate(DamaBoard.size, (_) => List.filled(DamaBoard.size, null));

      // AI has 0 pieces left
      board.grid[7][0] = DamaPiece(player: 1);
      board.currentTurn = 2;

      final aiMove = board.getAiMove(DamaDifficulty.hard);
      expect(aiMove, isNull);
      expect(board.isGameOver, isTrue);
      expect(board.winner, 1);
    });
  });
}
