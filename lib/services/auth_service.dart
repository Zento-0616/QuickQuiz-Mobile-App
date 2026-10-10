import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown for auth failures we want the ViewModel layer to handle with a
/// specific, friendly message rather than a raw Firebase exception.
class AuthException implements Exception {
  final String message;
  final bool userCancelled;
  const AuthException(this.message, {this.userCancelled = false});

  @override
  String toString() => message;
}

/// The boundary file that imports firebase_auth / google_sign_in directly.
class AuthService {
  final fb_auth.FirebaseAuth? _customAuth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    fb_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _customAuth = firebaseAuth,
        _googleSignIn = googleSignIn ??
            (kIsWeb
                ? GoogleSignIn(
                    clientId: "385294000922-7rk0gageodfjmg4fb9pq99ktopb7k9go.apps.googleusercontent.com",
                    scopes: ['email', 'profile'],
                  )
                : GoogleSignIn(
                    serverClientId: "385294000922-7rk0gageodfjmg4fb9pq99ktopb7k9go.apps.googleusercontent.com",
                    scopes: ['email', 'profile'],
                  ));

  fb_auth.FirebaseAuth get _firebaseAuth => _customAuth ?? fb_auth.FirebaseAuth.instance;

  Stream<fb_auth.User?> authStateChanges() {
    try {
      return _firebaseAuth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  fb_auth.User? get currentUser {
    try {
      return _firebaseAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Native Email & Password Authentication
  // -------------------------------------------------------------------

  Future<fb_auth.User> registerWithEmailPassword({
    required String email,
    required String password,
    required String realName,
    required int age,
    required String nickname,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Registration failed. Please try again.');
      }

      // Update user display name with nickname / real name
      try {
        await user.updateDisplayName(nickname.isNotEmpty ? nickname : realName);
      } catch (_) {}

      // Attempt to send email verification
      try {
        await user.sendEmailVerification();
      } catch (_) {}

      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException register: ${e.code} - ${e.message}");
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Registration error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<fb_auth.User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Sign-in failed. Please try again.');
      }
      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException signIn: ${e.code} - ${e.message}");
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign-in error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      throw AuthException('Could not send password reset email: $e');
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } on fb_auth.FirebaseAuthException catch (e) {
        throw AuthException(_mapFirebaseError(e));
      }
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('No user is currently signed in.');
    }
    try {
      final cred = fb_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to change password: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> seedDefaultAdminAccount() async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: 'admin@quickquiz.com',
        password: 'admin123',
      );
    } catch (_) {
      // Admin account already exists or offline
    }
  }

  // -------------------------------------------------------------------
  // Google Sign-In
  // -------------------------------------------------------------------

  Future<fb_auth.User> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = fb_auth.GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) {
          throw const AuthException('Sign-in failed. Please try again.');
        }
        return user;
      }

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Sign-in cancelled.', userCancelled: true);
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Sign-in failed. Please try again.');
      }
      return user;
    } on AuthException {
      rethrow;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException: ${e.code} - ${e.message}");
      throw AuthException(_mapFirebaseError(e));
    } on PlatformException catch (e) {
      debugPrint("Google Sign-In PlatformException: [${e.code}] ${e.message}");
      final msg = e.message ?? '';
      if (msg.contains('ApiException: 10') || msg.contains(': 10')) {
        throw const AuthException(
          'Google Sign-In configuration error (ApiException: 10). '
          'Please ensure your SHA-1 certificate fingerprint is added in Firebase Console.',
        );
      } else if (msg.contains('ApiException: 12500') || msg.contains(': 12500')) {
        throw const AuthException(
          'Google Sign-In failed (ApiException: 12500). '
          'Please check your Google Play Services and Firebase project settings.',
        );
      } else if (e.code == 'sign_in_canceled' || e.code == 'popup_closed_by_user') {
        throw const AuthException('Sign-in cancelled.', userCancelled: true);
      } else if (e.code == 'network_error' || msg.toLowerCase().contains('network')) {
        throw const AuthException('Network error during Google Sign-In. Please check your connection.');
      }
      throw AuthException('Google Sign-In failed: ${e.message ?? e.code}');
    } catch (e, stack) {
      debugPrint("Google Sign-In Error: $e\n$stack");
      throw AuthException(
        'Something went wrong signing in: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _firebaseAuth.signOut();
      } else {
        await Future.wait([
          _firebaseAuth.signOut(),
          _googleSignIn.signOut(),
        ]);
      }
    } catch (_) {
      throw const AuthException('Could not sign out. Please try again.');
    }
  }

  String _mapFirebaseError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address. Try logging in instead.';
      case 'invalid-email':
        return 'The email address is invalid. Please enter a valid email.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please check your spelling or register.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'invalid-credential':
        return 'Invalid credentials. Please verify your email and password.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to a different sign-in method.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}