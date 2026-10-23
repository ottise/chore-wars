import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiVoiceControls extends StatefulWidget {
  const AiVoiceControls({
    super.key,
    required this.controller,
    required this.summary,
    this.disabled = false,
    this.compact = false,
  });
  final TextEditingController controller;
  final String summary;
  final bool disabled;
  final bool compact;
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
  bool _disposed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    _stopAll();
    super.dispose();
  }

  Future<void> _stopAll() async {
    generation++;
    try {
      await speech.cancel();
    } catch (_) {}
    try {
      await tts.stop();
    } catch (_) {}
    if (mounted && !_disposed) {
      setState(() {
        listening = false;
        starting = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      generation++;
      _stopAll();
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
      try {
        await tts.stop();
      } catch (_) {
        /* Recognition remains usable without a TTS engine. */
      }
      if (!mounted || operation != generation) return;
      speech.errorListener = (error) {
        if (mounted && !_disposed) {
          setState(() {
            status =
                'Speech recognition failed (${error.errorMsg}). Check microphone permissions, network connection and speech services.';
            listening = false;
          });
        }
      };
      speech.statusListener = (value) {
        if (mounted && !_disposed) {
          setState(() => listening = value == 'listening');
        }
      };
      final ready = await speech.initialize(
        onError: speech.errorListener,
        onStatus: speech.statusListener,
      );
      if (!mounted || operation != generation) return;
      if (!ready) {
        setState(
          () => status = 'Microphone or speech services are unavailable. You can still type your message.',
        );
        return;
      }
      final locales = kIsWeb ? <LocaleName>[] : await speech.locales();
      final english = locales
          .where((l) => l.localeId.toLowerCase().startsWith('en'))
          .toList();
      if (!mounted || operation != generation) return;
      if (!kIsWeb && english.isEmpty) {
        setState(
          () => status =
              'English speech recognition is unavailable on this device.',
        );
        return;
      }
      await speech.listen(
        localeId: kIsWeb ? 'en-US' : english.first.localeId,
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
          () => status =
              'Speech recognition is unavailable. Please type your message.',
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
      final available = await tts.isLanguageAvailable('en-US');
      if (!mounted || operation != generation) return;
      if (available != true) {
        if (mounted) {
          setState(
            () => status = 'An English voice is unavailable on this device.',
          );
        }
        return;
      }
      await tts.setLanguage('en-US');
      if (!mounted || operation != generation) return;
      await tts.speak(widget.summary);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              status = 'Unable to play speech. You can still read the result.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: widget.compact ? 0 : 8,
        children: [
          TextButton.icon(
            onPressed: widget.disabled || starting
                ? null
                : listening
                ? () async {
                    await speech.stop();
                    if (mounted) setState(() => listening = false);
                  }
                : listen,
            icon: Icon(listening ? Icons.stop : Icons.mic_none),
            label: Text(
              listening
                  ? 'Stop Recording'
                  : widget.compact
                  ? 'Speak'
                  : 'Speak English',
            ),
          ),
          TextButton.icon(
            onPressed: widget.disabled || widget.summary.isEmpty ? null : speak,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(widget.compact ? 'Read' : 'Read Results'),
          ),
          TextButton(
            onPressed: _stopAll,
            child: Text(widget.compact ? 'Stop' : 'Stop Audio'),
          ),
        ],
      ),
      if (!widget.compact)
        const Text(
          'You can edit the transcript before sending. Speech recognition may use your device network services.',
        ),
      if (status != null) Text(status!),
    ],
  );
}
