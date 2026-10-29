part of 'ad_manager.dart';

extension AdManagerHouseAds on AdManager {
  HouseAd? getRandomHouseBannerAd({String? language, String? country}) {
    return _getRandomAdFromList(_houseBannerAds, language: language, country: country);
  }

  HouseAd? getRandomHouseNativeAd({String? language, String? country}) {
    return _getRandomAdFromList(_houseNativeAds, language: language, country: country);
  }

  HouseAd? _getRandomAdFromList(
    List<HouseAd> adsList, {
    String? language,
    String? country,
  }) {
    if (adsList.isEmpty) return null;

    final targetLang = (language ?? 'es').toLowerCase();
    final targetCountry = (country ?? '').toUpperCase();

    // 1. Filtrar primero por idioma (o fallback a 'es' o 'all')
    List<HouseAd> langAds = adsList.where((ad) {
      final adLang = ad.language.toLowerCase();
      return adLang == targetLang || adLang == 'all';
    }).toList();

    if (langAds.isEmpty) {
      langAds = adsList.where((ad) => ad.language.toLowerCase() == 'es').toList();
    }
    if (langAds.isEmpty) {
      langAds = adsList;
    }

    // 2. Filtrar por País
    if (targetCountry.isNotEmpty) {
      final countrySpecificAds = langAds.where((ad) {
        return ad.countries.any((c) {
          final uc = c.toUpperCase();
          return uc == targetCountry ||
              (targetCountry == 'AR' && uc == 'ARGENTINA') ||
              (targetCountry == 'ARGENTINA' && uc == 'AR') ||
              (targetCountry == 'PY' && uc == 'PARAGUAY') ||
              (targetCountry == 'PARAGUAY' && uc == 'PY');
        });
      }).toList();

      if (countrySpecificAds.isNotEmpty) {
        return _pickAdByWeight(countrySpecificAds);
      }

      final allCountryAds = langAds.where((ad) {
        return ad.countries.map((c) => c.toUpperCase()).contains('ALL') || ad.countries.isEmpty;
      }).toList();

      if (allCountryAds.isNotEmpty) {
        return _pickAdByWeight(allCountryAds);
      }

      return null;
    }

    // 3. Si no se especificó país, solo seleccionar entre anuncios globales 'ALL'
    final allCountryAds = langAds.where((ad) {
      return ad.countries.map((c) => c.toUpperCase()).contains('ALL') || ad.countries.isEmpty;
    }).toList();

    if (allCountryAds.isNotEmpty) {
      return _pickAdByWeight(allCountryAds);
    }

    return null;
  }

  HouseAd _pickAdByWeight(List<HouseAd> ads) {
    if (ads.isEmpty) return ads.first;
    if (ads.length == 1) return ads.first;
    final totalWeight = ads.fold<int>(0, (sum, ad) => sum + (ad.weight > 0 ? ad.weight : 1));
    if (totalWeight <= 0) return ads[_random.nextInt(ads.length)];
    int randomValue = _random.nextInt(totalWeight);
    for (final ad in ads) {
      final w = ad.weight > 0 ? ad.weight : 1;
      if (randomValue < w) return ad;
      randomValue -= w;
    }
    return ads.first;
  }
}
