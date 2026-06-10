import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cine_stream/di/injection.dart';
import 'package:cine_stream/presentation/screens/settings/webdav_setup_screen.dart';

import 'package:cine_stream/data/services/log_service.dart';
import 'package:cine_stream/data/services/tts/native_tts_impl.dart';
import 'package:cine_stream/domain/services/tts_service.dart';
import 'package:cine_stream/data/services/tts/tts_service_facade.dart';
import 'package:cine_stream/data/services/tts/openai_tts_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!getIt.isRegistered<SharedPreferences>()) {
      getIt.registerLazySingleton<SharedPreferences>(() => prefs);
    }
    if (!getIt.isRegistered<LogService>()) {
      getIt.registerLazySingleton<LogService>(() => LogService());
    }
    final nativeTts = NativeTtsImpl();
    if (!getIt.isRegistered<NativeTtsImpl>()) {
      getIt.registerSingleton<NativeTtsImpl>(nativeTts);
    }
    if (!getIt.isRegistered<TtsService>()) {
      getIt.registerLazySingleton<TtsService>(
        () => TtsServiceFacade(
          prefs: prefs,
          nativeTts: nativeTts,
          openAiTts: OpenAiTtsImpl(prefs: prefs, nativeFallback: nativeTts),
        ),
      );
    }
  });

  group('AppSettingsScreen UI & Config Tests', () {
    testWidgets('Displays all sections including Voice-over', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: WebdavSetupScreen(),
      ));

      // Đảm bảo hiển thị tiêu đề và QR Section
      expect(find.text('Show QR'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);

      // Section WebDAV
      expect(find.text('WebDAV URL'), findsOneWidget);

      // Section Voice-over
      expect(find.text('Voice-over Engine'), findsOneWidget);
    });

    testWidgets('Progressive Disclosure hides OpenAI fields when System Default is selected', (WidgetTester tester) async {
      // Set test screen size to avoid being off-screen
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MaterialApp(
        home: WebdavSetupScreen(),
      ));

      // Mặc định engine là Native/System Default nên không hiển thị OpenAI Base URL
      expect(find.text('OpenAI Base URL'), findsNothing);
      expect(find.text('OpenAI API Key'), findsNothing);

      // Chọn OpenAI engine từ Dropdown
      final dropdown = find.byKey(const Key('tts_engine_dropdown'));
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Trong flutter tests, khi nhấn DropdownButtonFormField, các DropdownMenuItem 
      // sẽ được đưa vào menu popup. Tìm item có chứa text 'OpenAI Compatible'
      final openAiOption = find.text('OpenAI Compatible').last;
      await tester.tap(openAiOption);
      await tester.pumpAndSettle();

      // Hiện các field cấu hình OpenAI
      expect(find.text('OpenAI Base URL'), findsOneWidget);
      expect(find.text('OpenAI API Key'), findsOneWidget);
      
      // Reset view size sau khi test xong
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
