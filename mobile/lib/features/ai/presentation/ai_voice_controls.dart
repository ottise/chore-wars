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
    this.speechLocale = 'en-US',
  });
  final TextEditingController controller;
  final String summary;
  final bool disabled;
  final bool compact;
  final String speechLocale;
  @override
  State<AiVoiceControls> createState() => _AiVoiceControlsState();
}

class _AiVoiceControlsState extends State<AiVoiceControls>
    with WidgetsBindingObserver {
  final speech = SpeechToText();
  final tts = FlutterTts();
  bool listening = false, starting = false;
  bool speaking = false;
  bool readUnavailable = false;
  String? status;
  int generation = 0;
  bool _disposed = false;
  late String _speechLocale;
  @override
  void initState() {
    super.initState();
    _speechLocale = widget.speechLocale;
    WidgetsBinding.instance.addObserver(this);
    tts.setStartHandler(() {
      if (mounted && !_disposed) setState(() => speaking = true);
    });
    tts.setCompletionHandler(() {
      if (mounted && !_disposed) setState(() => speaking = false);
    });
    tts.setErrorHandler((_) {
      if (mounted && !_disposed) {
        setState(() {
          speaking = false;
          status = 'Read aloud is unavailable right now. You can read the reply on screen.';
        });
      }
    });
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
        speaking = false;
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
      final available = locales
          .where(
            (l) => l.localeId.toLowerCase().startsWith(
              _speechLocale.substring(0, 2),
            ),
          )
          .toList();
      if (!mounted || operation != generation) return;
      if (!kIsWeb && available.isEmpty) {
        setState(
          () => status =
              '${_speechLocale.startsWith('vi') ? 'Vietnamese' : 'English'} speech recognition is unavailable on this device.',
        );
        return;
      }
      await speech.listen(
        localeId: kIsWeb ? _speechLocale : available.first.localeId,
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
      await tts.stop();
      if (!mounted || operation != generation) return;
      setState(() {
        listening = false;
        speaking = false;
        status = null;
      });
      List<Map> voices = [];
      for (var attempt = 0; attempt < (kIsWeb ? 4 : 1); attempt++) {
        final result = await tts.getVoices;
        if (!mounted || operation != generation) return;
        voices = (result is List ? result.whereType<Map>() : <Map>[])
            .where(
              (voice) => voice['locale']
                  .toString()
                  .toLowerCase()
                  .replaceAll('_', '-')
                  .startsWith('en'),
            )
            .toList();
        if (voices.isNotEmpty) break;
        if (kIsWeb && attempt < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (!mounted || operation != generation) return;
      if (voices.isEmpty) {
        setState(() {
          readUnavailable = true;
          status = 'Read aloud is not available: this device has no English voice. You can read replies on screen.';
        });
        return;
      }
      final voice = voices.first;
      await tts.setLanguage(voice['locale'].toString());
      await tts.setVoice({
        'name': voice['name'].toString(),
        'locale': voice['locale'].toString(),
      });
      await tts.setVolume(1.0);
      if (!mounted || operation != generation) return;
      await tts.speak(widget.summary);
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Read aloud is unavailable right now. You can read the reply on screen.',
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
            icon: Icon(
              listening ? Icons.stop_outlined : Icons.mic_none_outlined,
            ),
            label: Text(
              listening
                  ? 'Stop Recording'
                  : widget.compact
                  ? 'Speak'
                  : _speechLocale.startsWith('vi')
                  ? 'Speak Vietnamese'
                  : 'Speak English',
            ),
          ),
          TextButton.icon(
            onPressed:
                widget.disabled || widget.summary.isEmpty || readUnavailable
                ? null
                : speak,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(
              readUnavailable
                  ? 'Read unavailable'
                  : widget.compact
                  ? 'Read'
                  : 'Read Results',
            ),
          ),
          TextButton(
            onPressed: listening || speaking || starting ? _stopAll : null,
            child: Text(widget.compact ? 'Stop' : 'Stop Audio'),
          ),
          DropdownButton<String>(
            value: _speechLocale,
            underline: const SizedBox.shrink(),
            hint: const Text('Voice language'),
            items: const [
              DropdownMenuItem(value: 'vi-VN', child: Text('Vietnamese')),
              DropdownMenuItem(value: 'en-US', child: Text('English')),
            ],
            onChanged: widget.disabled || listening || starting
                ? null
                : (value) {
                    if (value != null) setState(() => _speechLocale = value);
                  },
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
