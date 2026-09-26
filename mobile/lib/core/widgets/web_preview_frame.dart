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
      color: const Color(0xFFEDEBF7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.canvas,
              boxShadow: [
                BoxShadow(
                  color: Color(0x220F0A2A),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
