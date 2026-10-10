import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/chat_room_model.dart';
import '../models/document_model.dart';
import '../models/quiz_model.dart';
import '../utils/nav_payloads.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/flashcard_model.dart';
import '../models/study_notes_model.dart';
import '../views/flashcards/flashcard_view.dart';
import '../views/generation_method/generation_method_view.dart';
import '../views/notes/study_notes_view.dart';
import '../views/splash/splash_view.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/auth/auth_view.dart';
import '../views/home/home_view.dart';
import '../views/upload/upload_view.dart';
import '../views/quiz_settings/quiz_settings_view.dart';
import '../views/quiz/quiz_view.dart';
import '../views/result/result_view.dart';
import '../views/review/review_view.dart';
import '../views/history/history_view.dart';
import '../views/profile/profile_view.dart';
import '../views/games/games_view.dart';
import '../views/messages/messages_view.dart';
import '../views/messages/chat_room_view.dart';
import '../views/admin/admin_home_screen.dart';
import '../models/game_match_model.dart';
import '../views/games/chess_game_view.dart';
import '../views/games/dama_game_view.dart';

/// Central route name/path constants.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String upload = '/upload';
  static const String generationMethod = '/generation-method';
  static const String studyNotes = '/study-notes';
  static const String flashcards = '/flashcards';
  static const String quizSettings = '/quiz-settings';
  static const String quiz = '/quiz';
  static const String result = '/result';
  static const String review = '/review';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String games = '/games';
  static const String messages = '/messages';
  static const String chat = '/chat/:roomId';
  static const String admin = '/admin';
  static const String dama = '/dama';
  static const String chess = '/chess';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide router factory.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.splash,
  GlobalKey<NavigatorState>? navigatorKey,
}) => GoRouter(
  navigatorKey: navigatorKey ?? rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashView(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) {
        final auth = Provider.of<AuthViewModel?>(context, listen: true);
        if (auth != null && (auth.currentUser?.isAdmin ?? false)) {
          return const AdminHomeScreen();
        }
        return const HomeView();
      },
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingView(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthView(),
    ),
    GoRoute(
      path: AppRoutes.upload,
      builder: (context, state) => const UploadView(),
    ),
    GoRoute(
      path: AppRoutes.generationMethod,
      builder: (context, state) => GenerationMethodView(
        document: state.extra as DocumentModel?,
      ),
    ),
    GoRoute(
      path: AppRoutes.studyNotes,
      builder: (context, state) {
        if (state.extra is ({StudyNotesModel notes, DocumentModel? document})) {
          final payload = state.extra as ({StudyNotesModel notes, DocumentModel? document});
          return StudyNotesView(notes: payload.notes, document: payload.document);
        } else if (state.extra is StudyNotesModel) {
          return StudyNotesView(notes: state.extra as StudyNotesModel);
        }
        return const StudyNotesView();
      },
    ),
    GoRoute(
      path: AppRoutes.flashcards,
      builder: (context, state) {
        if (state.extra is ({FlashcardDeckModel deck, DocumentModel? document})) {
          final payload = state.extra as ({FlashcardDeckModel deck, DocumentModel? document});
          return FlashcardView(deck: payload.deck, document: payload.document);
        } else if (state.extra is FlashcardDeckModel) {
          return FlashcardView(deck: state.extra as FlashcardDeckModel);
        }
        return FlashcardView(
          deck: FlashcardDeckModel(
            title: 'Study Flashcards',
            sourceFileName: 'Material',
            cards: [],
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.quizSettings,
      builder: (context, state) => QuizSettingsView(
        document: state.extra as DocumentModel?,
      ),
    ),
    GoRoute(
      path: AppRoutes.quiz,
      builder: (context, state) => QuizView(
        quiz: state.extra as QuizModel?,
      ),
    ),
    GoRoute(
      path: AppRoutes.result,
      builder: (context, state) => ResultView(
        payload: state.extra as QuizResultPayload?,
      ),
    ),
    GoRoute(
      path: AppRoutes.review,
      builder: (context, state) => ReviewView(
        payload: state.extra as QuizResultPayload?,
      ),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryView(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileView(),
    ),
    GoRoute(
      path: AppRoutes.games,
      builder: (context, state) => const GamesView(),
    ),
    GoRoute(
      path: AppRoutes.messages,
      builder: (context, state) => const MessagesView(),
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) => ChatRoomView(
        chatRoom: state.extra as ChatRoomModel,
      ),
    ),
    GoRoute(
      path: AppRoutes.admin,
      builder: (context, state) => const AdminHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.dama,
      builder: (context, state) => DamaGameView(
        initialMatch: state.extra as GameMatchModel?,
      ),
    ),
    GoRoute(
      path: AppRoutes.chess,
      builder: (context, state) => const ChessGameView(),
    ),
  ],
);

final GoRouter appRouter = createAppRouter();
