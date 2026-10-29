import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/config/theme.dart';

void main() {
  group('Text Styles and Theme Audit Tests', () {
    test('Light theme typography and colorScheme are properly configured', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppTheme.primaryGreen));
      expect(theme.textTheme.bodyMedium, isNotNull);
      expect(theme.textTheme.headlineMedium, isNotNull);
    });

    test('Dark theme typography and colorScheme are properly configured', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.colorScheme.primary, equals(AppTheme.darkPrimaryGreen));
      expect(darkTheme.textTheme.bodyMedium, isNotNull);
    });
  });
}
