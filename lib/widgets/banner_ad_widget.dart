import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../viewmodels/auth_viewmodel.dart';

class BannerAdWidget extends StatefulWidget {
  final bool isVisible;
  final double? maxWidth;

  const BannerAdWidget({
    super.key,
    this.isVisible = true,
    this.maxWidth,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;
  Orientation? _currentOrientation;

  bool get _adsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool _isAdminUser() {
    try {
      final auth = Provider.of<AuthViewModel?>(context, listen: false);
      return auth?.currentUser?.isAdmin ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isAdminUser()) return;
    if (!_adsSupported) return;

    final orientation = MediaQuery.of(context).orientation;
    if (_currentOrientation != orientation) {
      _currentOrientation = orientation;
      _loadAdaptiveAd();
    }
  }

  Future<void> _loadAdaptiveAd() async {
    if (_isAdminUser()) return;
    if (!_adsSupported) return;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    final screenWidth = widget.maxWidth ?? MediaQuery.of(context).size.width;
    final availableWidth = (screenWidth - 32).clamp(280.0, 728.0).truncate();

    AdSize? adaptiveSize;
    try {
      adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        availableWidth,
      );
    } catch (e) {
      debugPrint('[BannerAdWidget] Error calculating adaptive ad size: $e');
    }

    adaptiveSize ??= AdSize.banner;

    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
            _adSize = adaptiveSize;
          });
          debugPrint('[BannerAdWidget] Adaptive banner loaded: ${adaptiveSize?.width}x${adaptiveSize?.height}');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
              _bannerAd = null;
            });
          }
        },
      ),
    );

    _bannerAd = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _isAdminUser()) {
      return const SizedBox.shrink();
    }

    final ad = _bannerAd;
    final size = _adSize;

    if (_isLoaded && ad != null && size != null) {
      return Center(
        child: Container(
          alignment: Alignment.center,
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: AdWidget(ad: ad),
        ),
      );
    }

    return _buildFallbackBanner(context);
  }

  Widget _buildFallbackBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 56),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QuickQuiz Study Sponsor',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Master your curriculum 10x faster with AI-powered smart decks.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C42F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Learn More',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
