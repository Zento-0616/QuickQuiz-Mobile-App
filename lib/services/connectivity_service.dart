import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus. Used for a fast pre-flight check
/// before network-heavy operations (quiz generation) so the user gets an
/// immediate "no internet" message instead of waiting out a long timeout.
///
/// Deliberately NOT used to block reading local files (Upload/parsing
/// needs no network) or to gate the whole app — only the specific calls
/// where failing fast materially improves the experience.
class ConnectivityService {
  Future<bool> hasConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      // If the check itself fails, don't block the user on it — let the
      // actual network call proceed and fail (or succeed) on its own.
      return true;
    }
  }
}
