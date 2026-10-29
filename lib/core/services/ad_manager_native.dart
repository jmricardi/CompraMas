part of 'ad_manager.dart';

extension AdManagerNative on AdManager {
  Future<void> loadNativeFeedAd() async {
    if (!showNativeAds) return;
    try {
      await AdManager._channel.invokeMethod('loadNativeFeedAd');
    } catch (e) {
      debugPrint('[AdManager] Error invocando loadNativeFeedAd: $e');
    }
  }

  Future<void> loadNativeAnalysisAd() async {
    if (!showNativeAds) return;
    try {
      await AdManager._channel.invokeMethod('loadNativeAnalysisAd');
    } catch (e) {
      debugPrint('[AdManager] Error invocando loadNativeAnalysisAd: $e');
    }
  }

  Future<int> getNativeFeedAdCount() async {
    try {
      return await AdManager._channel.invokeMethod<int>('getNativeFeedAdCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getNativeAnalysisAdCount() async {
    try {
      return await AdManager._channel.invokeMethod<int>('getNativeAnalysisAdCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
