// lib/services/ad_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_constants.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ============================================================
  // APP OPEN AD
  // ============================================================
  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenAdLoadTime;

  Future<void> loadAppOpenAd() async {
    await AppOpenAd.load(
      adUnitId: AdConstants.appOpenAdId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd gagal load: ${error.message}');
          _appOpenAd = null;
        },
      ),
    );
  }

  bool _isAppOpenAdAvailable() {
    if (_appOpenAd == null) return false;
    if (_appOpenAdLoadTime == null) return false;
    // Iklan kadaluarsa setelah 4 jam
    final now = DateTime.now();
    final diff = now.difference(_appOpenAdLoadTime!);
    return diff.inHours < 4;
  }

  void showAppOpenAd() {
    if (!_isAppOpenAdAvailable() || _isShowingAppOpenAd) return;
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAppOpenAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // Preload berikutnya
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );
    _appOpenAd!.show();
  }

  // ============================================================
  // INTERSTITIAL AD
  // ============================================================
  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  static const int _maxFailedLoadAttempts = 3;

  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: AdConstants.interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          if (_interstitialLoadAttempts < _maxFailedLoadAttempts) {
            loadInterstitialAd();
          }
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onAdDismissed}) {
    if (_interstitialAd == null) {
      onAdDismissed?.call();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
    );
    _interstitialAd!.show();
  }

  // ============================================================
  // REWARDED AD
  // ============================================================
  RewardedAd? _rewardedAd;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: AdConstants.rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd gagal load: ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdNotAvailable,
  }) {
    if (_rewardedAd == null) {
      onAdNotAvailable?.call();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdNotAvailable?.call();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onUserEarnedReward(reward);
    });
  }

  // ============================================================
  // NATIVE AD LOADER
  // ============================================================
  NativeAd? createNativeAd({
    required NativeAdListener listener,
    required NativeTemplateStyle templateStyle,
  }) {
    return NativeAd(
      adUnitId: AdConstants.nativeAdId,
      listener: listener,
      request: const AdRequest(),
      nativeTemplateStyle: templateStyle,
    );
  }

  // ============================================================
  // INITIALIZE
  // ============================================================
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Preload semua iklan
    await Future.wait([
      loadAppOpenAd(),
      loadInterstitialAd(),
      loadRewardedAd(),
    ]);
  }

  void dispose() {
    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
