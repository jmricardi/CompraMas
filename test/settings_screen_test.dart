import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:compramas/core/cache/hive_manager.dart';
import 'package:compramas/services/locale_service.dart';
import 'package:compramas/services/settings_service.dart';
import 'package:compramas/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Tests', () {
    late LocaleService localeService;
    late SettingsService settingsService;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('compramas_settings_test_');
      await HiveManager.init(tempDir.path);

      localeService = LocaleService();
      settingsService = SettingsService();
    });

    tearDown(() async {
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    Widget createTestableWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeService),
          ChangeNotifierProvider.value(value: settingsService),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      );
    }

    testWidgets('no contiene tarjetas o ChoiceChips de distancia fija y muestra el Slider',
        (tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('500 m'), findsNothing);
      expect(find.text('2 km'), findsNothing);
      expect(find.text('3 km'), findsNothing);
      expect(find.text('5 km'), findsNothing);
      expect(find.text('10 km'), findsNothing);

      expect(find.byType(Slider), findsWidgets);
    });
  });
}
