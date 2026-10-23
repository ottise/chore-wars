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
  @override
  Future<bool> initialize({
    debugLogging = false,
    List<platform.SpeechConfigOption>? options,
  }) => ready.future;
  @override
  Future<List<dynamic>> locales() async => ['en_US:English'];
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
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      second.dispose();
    },
  );
}
