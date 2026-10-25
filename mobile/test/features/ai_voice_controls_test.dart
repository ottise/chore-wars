import 'dart:async';
import 'dart:convert';

import 'package:chore_wars/features/ai/presentation/ai_voice_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart'
    as platform;

class _Speech extends platform.SpeechToTextPlatform {
  final ready = Completer<bool>();
  int listens = 0;
  String? lastLocale;
  @override
  Future<bool> initialize({
    debugLogging = false,
    List<platform.SpeechConfigOption>? options,
  }) => ready.future;
  @override
  Future<List<dynamic>> locales() async => [
    'en_US:English',
    'vi_VN:Vietnamese',
  ];
  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    platform.SpeechListenOptions? options,
  }) async {
    listens++;
    lastLocale = localeId;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    onTextRecognition?.call(
      jsonEncode({
        'alternates': [
          {'recognizedWords': 'Tối nay tôi bận', 'confidence': 1.0},
        ],
        'finalResult': true,
      }),
    );
    onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    onStatus?.call('notListening');
  }
}

void main() {
  testWidgets(
    'read uses an available English locale rather than requiring en-US',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          calls.add(call);
          if (call.method == 'getVoices') {
            return [
              {'name': 'English UK', 'locale': 'en-GB'},
            ];
          }
          return 1;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        ),
      );
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceControls(
              controller: controller,
              summary: 'Your household task plan is ready.',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Read Results'));
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (call) => call.method == 'setLanguage' && call.arguments == 'en-GB',
        ),
        isTrue,
      );
      expect(calls.any((call) => call.method == 'speak'), isTrue);
      expect(
        calls.any((call) => call.method == 'isLanguageAvailable'),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'read shows an honest unavailable state without an English voice',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async => call.method == 'getVoices' ? [] : 1,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        ),
      );
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceControls(controller: controller, summary: 'Reply'),
          ),
        ),
      );
      await tester.tap(find.text('Read Results'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('this device has no English voice'),
        findsOneWidget,
      );
      expect(find.text('Read unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'permission dialog does not cancel initialization; final words survive stop and another widget can listen',
    (tester) async {
      final previous = platform.SpeechToTextPlatform.instance;
      final speech = _Speech();
      platform.SpeechToTextPlatform.instance = speech;
      addTearDown(() => platform.SpeechToTextPlatform.instance = previous);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (_) async => 1,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        ),
      );
      final first = TextEditingController();
      final second = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceControls(
              key: const ValueKey('first'),
              controller: first,
              summary: '',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Speak English'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      speech.ready.complete(true);
      await tester.pumpAndSettle();
      expect(speech.listens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Stop Recording'));
      await tester.pumpAndSettle();
      expect(first.text, 'Tối nay tôi bận');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceControls(
              key: const ValueKey('second'),
              controller: second,
              summary: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speak English'));
      await tester.pumpAndSettle();
      expect(speech.listens, 2);
      expect(SpeechToText().isAvailable, isTrue);
      expect(find.text('Stop Recording'), findsOneWidget);
      await tester.tap(find.text('Stop Recording'));
      await tester.pumpAndSettle();
      expect(second.text, 'Tối nay tôi bận');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceControls(
              key: const ValueKey('vietnamese'),
              controller: second,
              summary: '',
              speechLocale: 'vi-VN',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speak Vietnamese'));
      await tester.pumpAndSettle();
      expect(speech.lastLocale, 'vi_VN');
      await tester.tap(find.text('Stop Recording'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      second.dispose();
    },
  );
}
