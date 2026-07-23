import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_config.dart';
import '../ads/ad_consent.dart';

/// Небольшой статичный баннер (320×50 — самый маленький стандартный размер,
/// не адаптивный/крупноформатный, чтобы не отвлекать от контента). Пока
/// объявление не загрузилось — виджет не занимает места (SizedBox.shrink),
/// а не показывает серую заглушку; если загрузка не удалась — тоже просто
/// схлопывается, а не оставляет пустой блок.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final personalized = await hasPersonalizedAdsConsent();
    final ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(nonPersonalizedAds: !personalized),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AdWidget(ad: ad),
    );
  }
}
