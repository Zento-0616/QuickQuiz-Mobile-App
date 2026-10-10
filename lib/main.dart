import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/routes.dart';
import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'widgets/friendly_error_widget.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterNativeSplash.remove();

      ErrorWidget.builder = (details) => FriendlyErrorWidget(details: details);

      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('Note: .env file not found or failed to load: $e');
      }

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 3));
        debugPrint('Firebase initialized successfully');
      } catch (e) {
        debugPrint('Firebase Initialization Warning: $e');
      }

      final adService = AdService();
      try {
        await adService.initialize().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('AdService initialization failed or timed out: $e');
      }

      FlutterNativeSplash.remove();

      runApp(
        QuickQuizApp(
          initialRoute: AppRoutes.splash,
          providers: [
            ChangeNotifierProvider<AuthViewModel>(
              create: (_) => AuthViewModel(),
            ),
            Provider<AdService>.value(value: adService),
          ],
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Uncaught async error: $error\n$stackTrace');
    },
  );
}
