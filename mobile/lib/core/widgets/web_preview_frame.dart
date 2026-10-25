import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class WebPreviewFrame extends StatelessWidget {
  const WebPreviewFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.uiPreview) return child;
    return ColoredBox(
      color: AppTheme.surfaceContainer,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppTheme.canvas),
            child: child,
          ),
        ),
      ),
    );
  }
}
