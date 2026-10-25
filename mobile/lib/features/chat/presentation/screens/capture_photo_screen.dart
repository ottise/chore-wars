import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CapturePhotoScreen extends StatefulWidget {
  const CapturePhotoScreen({
    super.key,
    this.title = 'Capture & Send Photo',
    this.captureLabel = 'Capture & Send',
  });

  final String title;
  final String captureLabel;

  @override
  State<CapturePhotoScreen> createState() => _CapturePhotoScreenState();
}

class _CapturePhotoScreenState extends State<CapturePhotoScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _opening = false;
  bool _capturing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    setState(() {
      _opening = true;
      _error = null;
    });
    CameraController? camera;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw StateError('No camera found.');
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      camera = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted || generation != _generation) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (error) {
      await camera?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is CameraException
              ? 'Unable to open camera. Check camera permissions in your browser or app settings.'
              : 'No camera found. You can choose a photo from your gallery.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _generation++;
      final camera = _camera;
      setState(() {
        _camera = null;
        _opening = false;
      });
      if (camera != null) unawaited(camera.dispose());
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        !_opening &&
        !_capturing) {
      unawaited(_open());
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_capturing || camera == null || !camera.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      if (mounted) Navigator.of(context).pop(photo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to capture photo. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    final camera = _camera;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _opening
                  ? const CircularProgressIndicator()
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _open,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _camera != null
                  ? CameraPreview(_camera!)
                  : const Text('Camera is paused'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _camera == null || _capturing ? null : _capture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_capturing ? 'Capturing…' : widget.captureLabel),
            ),
          ),
        ],
      ),
    ),
  );
}
