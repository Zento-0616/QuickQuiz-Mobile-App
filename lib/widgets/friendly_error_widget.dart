import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Replaces Flutter's default red error screen. Per spec: "Do not show
/// raw technical exceptions to the user" — this applies just as much to
/// unexpected bugs as to handled service failures. In debug mode we
/// still show the real error (so developers aren't debugging blind); in
/// release mode we show a friendly, branded fallback instead.
class FriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const FriendlyErrorWidget({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      // Developers still get the real stack trace during development.
      return Material(
        color: Colors.red.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            details.toString(),
            style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }

    return Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                const Text(
                  "Something went wrong. Please try again.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
