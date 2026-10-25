import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_page_frame.dart';

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({required this.paths, required this.selected, super.key});
  final List<String> paths;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Overview', 'Chore', 'Chat', 'Bonus', 'Bounty'];
    const icons = [
      Icons.home_outlined,
      Icons.checklist_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.star_border_outlined,
      Icons.sell_outlined,
    ];
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: selected == i,
                        child: TextButton(
                          key: ValueKey('house-tab-$i'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 54),
                            padding: EdgeInsets.zero,
                            foregroundColor: selected == i
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.go(paths[i]),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected == i
                                      ? colors.primaryFixed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  icons[i],
                                  size: 21,
                                  color: selected == i
                                      ? AppPageFrame.accent
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontFamily: AppPageFrame.fontFamily,
                                  fontSize: 12,
                                  fontWeight: selected == i
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
