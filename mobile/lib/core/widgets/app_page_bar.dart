import 'package:flutter/material.dart';

class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    required this.title,
    this.subtitle,
    this.actions,
    this.centerTitle = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: preferredSize.height,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 0, 14),
        child: BackButton(
          style: IconButton.styleFrom(
            backgroundColor: colors.surfaceContainerLowest,
            foregroundColor: colors.onSurface,
            side: BorderSide(color: colors.outlineVariant),
            iconSize: 19,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      titleSpacing: 12,
      centerTitle: centerTitle,
      title: Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: subtitle == null ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actions: actions == null
          ? null
          : [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
                ),
              ),
            ],
    );
  }
}
