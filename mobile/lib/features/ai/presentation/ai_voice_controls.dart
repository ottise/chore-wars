import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiVoiceControls extends StatefulWidget {
  const AiVoiceControls({
    super.key,
    required this.controller,
    required this.summary,
    this.disabled = false,
  });
  final TextEditingController controller;
  final String summary;
  final bool disabled;
  @override
  State<AiVoiceControls> createState() => _AiVoiceControlsState();
}

class _AiVoiceControlsState extends State<AiVoiceControls>
    with WidgetsBindingObserver {
  final speech = SpeechToText();
  final tts = FlutterTts();
  bool listening = false, starting = false;
  String? status;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    speech.cancel();
    tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      generation++;
      speech.cancel();
      tts.stop();
      if (mounted) {
        setState(() {
          listening = false;
          starting = false;
        });
      }
    }
  }

  Future<void> listen() async {
    final operation = ++generation;
    setState(() {
      starting = true;
      status = null;
    });
    try {
      await tts.stop();
      if (!mounted || operation != generation) return;
      final ready = await speech.initialize(
        onError: (error) {
          if (mounted && operation == generation) {
            setState(() {
              status = 'Không nhận được giọng nói. Bạn có thể nhập nội dung.';
              listening = false;
            });
          }
        },
        onStatus: (value) {
          if (mounted && operation == generation) {
            setState(() => listening = value == 'listening');
          }
        },
      );
      if (!mounted || operation != generation) return;
      if (!ready) {
        setState(
          () => status = 'Micro hoặc dịch vụ nhận giọng nói chưa sẵn sàng. Bạn vẫn có thể nhập nội dung.',
        );
        return;
      }
      final locales = await speech.locales();
      final vietnamese = locales
          .where((l) => l.localeId.toLowerCase().startsWith('vi'))
          .toList();
      if (!mounted || operation != generation) return;
      if (vietnamese.isEmpty) {
        setState(() => status = 'Thiết bị chưa có nhận giọng nói tiếng Việt.');
        return;
      }
      await speech.listen(
        localeId: vietnamese.first.localeId,
        listenFor: const Duration(seconds: 30),
        onResult: (result) {
          if (!mounted || operation != generation) return;
          final text = result.recognizedWords;
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (_) {
      if (mounted && operation == generation) {
        setState(
          () => status = 'Nhận giọng nói không khả dụng. Hãy nhập nội dung.',
        );
      }
    } finally {
      if (mounted && operation == generation) setState(() => starting = false);
    }
  }

  Future<void> speak() async {
    final operation = ++generation;
    try {
      await speech.cancel();
      if (!mounted || operation != generation) return;
      if (mounted) setState(() => listening = false);
      final available = await tts.isLanguageAvailable('vi-VN');
      if (!mounted || operation != generation) return;
      if (available != true) {
        if (mounted) {
          setState(() => status = 'Thiết bị chưa có giọng đọc tiếng Việt.');
        }
        return;
      }
      await tts.setLanguage('vi-VN');
      if (!mounted || operation != generation) return;
      await tts.speak(widget.summary);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              status = 'Không phát được giọng đọc. Bạn vẫn có thể đọc kết quả.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: widget.disabled || starting
                ? null
                : listening
                ? () async {
                    generation++;
                    await speech.stop();
                    if (mounted) setState(() => listening = false);
                  }
                : listen,
            icon: Icon(listening ? Icons.stop : Icons.mic_none),
            label: Text(listening ? 'Dừng ghi' : 'Nói tiếng Việt'),
          ),
          TextButton.icon(
            onPressed: widget.disabled || widget.summary.isEmpty ? null : speak,
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Đọc kết quả'),
          ),
          TextButton(
            onPressed: () async {
              generation++;
              await speech.cancel();
              await tts.stop();
              if (mounted) setState(() => listening = false);
            },
            child: const Text('Dừng âm thanh'),
          ),
        ],
      ),
      const Text(
        'Bạn có thể sửa bản chép lời trước khi gửi. Nhận giọng nói có thể cần dịch vụ mạng của thiết bị.',
      ),
      if (status != null) Text(status!),
    ],
  );
}
