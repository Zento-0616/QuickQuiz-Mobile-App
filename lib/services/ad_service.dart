import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/interstitial_ad_dialog.dart';

/// Wraps google_mobile_ads. Every method is designed to fail silently —
/// per spec, "if an ad cannot load, the application must continue
/// working." Nothing here ever throws out to a caller; failures just
/// mean no ad shows.
class AdService {
  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;
  bool _interstitialLoading = false;

  /// Ads aren't supported on web via this package; guard every entry
  /// point so the rest of the app doesn't need to know that.
  bool get _adsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (!_adsSupported) return;
    try {
      await MobileAds.instance.initialize();
      preloadInterstitial();
    } catch (_) {
      // Ad SDK failed to initialize (e.g. no network on first launch) —
      // the app continues without ads rather than blocking startup.
    }
  }

  // ---------------------------------------------------------------------
  // Banner ad unit ID resolution (test vs. production, per platform)
  // ---------------------------------------------------------------------
  static String get bannerAdUnitId {
    if (!kIsWeb && Platform.isIOS) {
      return AppConstants.useTestAds
          ? AppConstants.admobBannerIdIosTest
          : AppConstants.admobBannerIdIosProd;
    }
    return AppConstants.useTestAds
        ? AppConstants.admobBannerIdAndroidTest
        : AppConstants.admobBannerIdAndroidProd;
  }

  static String get _interstitialAdUnitId {
    if (!kIsWeb && Platform.isIOS) {
      return AppConstants.useTestAds
          ? AppConstants.admobInterstitialIdIosTest
          : AppConstants.admobInterstitialIdIosProd;
    }
    return AppConstants.useTestAds
        ? AppConstants.admobInterstitialIdAndroidTest
        : AppConstants.admobInterstitialIdAndroidProd;
  }

  // ---------------------------------------------------------------------
  // Interstitial: preload early, show once, fail gracefully.
  // ---------------------------------------------------------------------

  /// Starts loading an interstitial in the background. Call this when a
  /// quiz begins so it's likely ready by the time the user finishes —
  /// never awaited by callers, since a slow/failed load must never block
  /// the UI.
  void preloadInterstitial() {
    if (!_adsSupported || _interstitialLoading || _interstitialReady) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
          _interstitialLoading = false;
        },
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready, then calls
  /// [onComplete]. If no ad is ready (still loading, failed to load, or
  /// ads unsupported on this platform), calls [onComplete] immediately —
  /// callers should always treat this as "the ad step is done" rather
  /// than waiting on ad state themselves.
  ///
  /// Shows the preloaded interstitial if one is ready, then calls
  /// [onComplete]. If no native ad is ready, or on unsupported platforms (like Windows desktop),
  /// displays an in-app simulated interstitial dialog via [context] so users
  /// always experience the post-quiz ad flow.
  ///
  /// Includes an automatic [autoDismissDuration] safety timer (default 3 seconds)
  /// so that users are smoothly transitioned to the results screen without
  /// being trapped on the ad screen.
  ///
  /// For admin accounts ([isAdmin] == true or detected via [context]), all ads
  /// are completely suppressed and [onComplete] is fired immediately.
  void showInterstitial({
    required VoidCallback onComplete,
    BuildContext? context,
    Duration autoDismissDuration = const Duration(seconds: 3),
    bool isAdmin = false,
  }) {
    if (isAdmin) {
      debugPrint('[AdService] Admin account detected via flag. Suppressing ads.');
      onComplete();
      return;
    }

    if (context != null) {
      try {
        final auth = Provider.of<AuthViewModel>(context, listen: false);
        if (auth.currentUser?.isAdmin ?? false) {
          debugPrint('[AdService] Admin account detected via context. Suppressing ads.');
          onComplete();
          return;
        }
      } catch (_) {}
    }

    final ad = _interstitialAd;
    if (_adsSupported && ad != null && _interstitialReady) {
      bool hasCompleted = false;
      Timer? autoDismissTimer;

      void completeOnce() {
        if (hasCompleted) return;
        hasCompleted = true;
        autoDismissTimer?.cancel();
        autoDismissTimer = null;
        preloadInterstitial();
        onComplete();
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('[AdService] Interstitial displayed. Starting ${autoDismissDuration.inSeconds}s safety timer.');
          autoDismissTimer = Timer(autoDismissDuration, () {
            debugPrint('[AdService] Interstitial auto-dismiss safety timer fired.');
            try {
              ad.dispose();
            } catch (_) {}
            _interstitialAd = null;
            _interstitialReady = false;
            completeOnce();
          });
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('[AdService] Interstitial dismissed by user.');
          try {
            ad.dispose();
          } catch (_) {}
          _interstitialAd = null;
          _interstitialReady = false;
          completeOnce();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('[AdService] Interstitial failed to show: $error');
          try {
            ad.dispose();
          } catch (_) {}
          _interstitialAd = null;
          _interstitialReady = false;
          completeOnce();
        },
      );

      _interstitialReady = false; // consumed — prevents double-show races
      try {
        ad.show();
      } catch (e) {
        debugPrint('[AdService] Interstitial show error: $e');
        completeOnce();
      }
      return;
    }

    // Fallback: If native interstitial is unavailable (desktop, loading, or network error),
    // display simulated in-app ad dialog so the post-quiz ad flow is visible and reliable.
    if (context != null && context.mounted) {
      debugPrint('[AdService] Native interstitial unavailable. Showing simulated in-app interstitial ad.');
      preloadInterstitial();
      InterstitialAdDialog.show(
        context,
        onDismissed: onComplete,
        autoDismissDuration: autoDismissDuration,
      );
      return;
    }

    preloadInterstitial();
    onComplete();
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
