import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/gamification_models.dart';

class AchievementShareCard extends StatefulWidget {
  final Achievement achievement;
  const AchievementShareCard({super.key, required this.achievement});
  @override
  State<AchievementShareCard> createState() => _AchievementShareCardState();
}

class _AchievementShareCardState extends State<AchievementShareCard> {
  final _boundary = GlobalKey();
  bool _busy = false;
  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || bytes == null) return;
      final render = context.findRenderObject() as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['chore-wars-achievement.png'],
          sharePositionOrigin: render.localToGlobal(Offset.zero) & render.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share the achievement. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _boundary,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'Chore Wars',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    widget.achievement.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    widget.achievement.description,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.achievement.unlockedAt != null)
                    Text(
                      'Unlocked ${widget.achievement.unlockedAt!.toIso8601String().split('T').first}',
                    ),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy || !widget.achievement.isUnlocked ? null : _share,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PNG'),
          ),
        ],
      ),
    ),
  );
}
