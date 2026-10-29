import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/utils/image_url_helper.dart';

void main() {
  group('ImageUrlHelper Tests', () {
    test('returns empty string for null or empty input', () {
      expect(ImageUrlHelper.getOptimizedImageUrl(null), '');
      expect(ImageUrlHelper.getOptimizedImageUrl(''), '');
      expect(ImageUrlHelper.getOptimizedImageUrl('   '), '');
    });

    test('ignores data URIs, SVGs, and already optimized URLs', () {
      const dataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAE';
      expect(ImageUrlHelper.getOptimizedImageUrl(dataUri), dataUri);

      const svgUrl = 'https://example.com/icon.svg';
      expect(ImageUrlHelper.getOptimizedImageUrl(svgUrl), svgUrl);

      const wsrvUrl = 'https://wsrv.nl/?url=https%3A%2F%2Fexample.com%2Fimg.jpg&w=350';
      expect(ImageUrlHelper.getOptimizedImageUrl(wsrvUrl), wsrvUrl);
    });

    test('transforms standard HTTP/HTTPS image URL with WebP, width, quality and progressive loading', () {
      const raw = 'https://http2.mlstatic.com/D_NQ_NP_781570-MLA99818457923_112025-F.jpg';
      final result = ImageUrlHelper.getOptimizedImageUrl(raw, targetWidth: 450, quality: 85);

      expect(result.startsWith('https://wsrv.nl/?url='), isTrue);
      expect(result.contains('w=450'), isTrue);
      expect(result.contains('output=webp'), isTrue);
      expect(result.contains('q=85'), isTrue);
      expect(result.contains('&we'), isTrue);
      expect(result.contains('&il'), isTrue);
    });

    test('encodes query parameters in original URL properly', () {
      const complexUrl = 'https://images.example.com/item?id=123&token=abc#frag';
      final result = ImageUrlHelper.getOptimizedImageUrl(complexUrl);

      expect(result.contains(Uri.encodeComponent(complexUrl)), isTrue);
    });
  });
}
