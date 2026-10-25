import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({required this.builder, super.key});
  final WidgetBuilder builder;

  static const background = AppTheme.canvas;
  static const accent = AppTheme.purple;
  static const fontFamily = AppTheme.fontFamily;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Builder(builder: builder),
      ),
    ),
  );
}
