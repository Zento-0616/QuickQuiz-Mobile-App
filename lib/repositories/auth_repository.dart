import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Clean boundary between ViewModels and AuthService. Converts Firebase's
/// `User` into our own `UserModel` so nothing above this layer needs to
/// know Firebase Auth exists.
class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  Stream<UserModel?> authStateChanges() {
    return _authService.authStateChanges().map(_toUserModel);
  }

  UserModel? get currentUser => _toUserModel(_authService.currentUser);

  fb_auth.User? get rawFirebaseUser => _authService.currentUser;

  Future<UserModel> registerWithEmailPassword({
    required String email,
    required String password,
    required String realName,
    required int age,
    required String nickname,
  }) async {
    final user = await _authService.registerWithEmailPassword(
      email: email,
      password: password,
      realName: realName,
      age: age,
      nickname: nickname,
    );
    return _toUserModel(user)!.copyWith(
      name: realName,
      nickname: nickname,
      age: age,
    );
  }

  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = await _authService.signInWithEmailPassword(
      email: email,
      password: password,
    );
    return _toUserModel(user)!;
  }

  Future<UserModel> signInWithGoogle() async {
    final user = await _authService.signInWithGoogle();
    return _toUserModel(user)!;
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);

  Future<void> sendEmailVerification() =>
      _authService.sendEmailVerification();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<void> seedDefaultAdminAccount() =>
      _authService.seedDefaultAdminAccount();

  Future<void> signOut() => _authService.signOut();

  UserModel? _toUserModel(fb_auth.User? user) {
    if (user == null) return null;
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? 'Student',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      nickname: user.displayName ?? 'Scholar',
    );
  }
}
