// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static String get _apiKey =>
      dotenv.env['FIREBASE_API_KEY'] ?? 'AIzaSyCgHzSabFkA-ZjlYTg_P7H0r_CxkBncFDU';

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _apiKey,
    appId: dotenv.env['FIREBASE_WEB_APP_ID'] ?? '1:385294000922:web:828ad3e652466fd78e42a3',
    messagingSenderId: '385294000922',
    projectId: 'quickquiz-27a7c',
    authDomain: 'quickquiz-27a7c.firebaseapp.com',
    storageBucket: 'quickquiz-27a7c.firebasestorage.app',
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:385294000922:android:828ad3e652466fd78e42a3',
    messagingSenderId: '385294000922',
    projectId: 'quickquiz-27a7c',
    storageBucket: 'quickquiz-27a7c.firebasestorage.app',
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _apiKey,
    appId: dotenv.env['FIREBASE_IOS_APP_ID'] ?? '1:385294000922:ios:828ad3e652466fd78e42a3',
    messagingSenderId: '385294000922',
    projectId: 'quickquiz-27a7c',
    storageBucket: 'quickquiz-27a7c.firebasestorage.app',
    iosBundleId: 'com.example.quickquiz',
  );
}