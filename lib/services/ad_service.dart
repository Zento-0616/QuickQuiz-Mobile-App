import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/interstitial_ad_dialog.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;
  bool _interstitialLoading = false;

  bool get _adsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (!_adsSupported) return;
    try {
      await MobileAds.instance.initialize();
      preloadInterstitial();
    } catch (_) {
    }
  }

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

      _interstitialReady = false;
      try {
        ad.show();
      } catch (e) {
        debugPrint('[AdService] Interstitial show error: $e');
        completeOnce();
      }
      return;
    }

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
