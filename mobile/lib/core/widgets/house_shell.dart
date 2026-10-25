import 'app_page_frame.dart';
import 'app_bottom_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/house/presentation/providers/house_providers.dart';
import '../../features/notifications/presentation/widgets/notification_bell.dart';
import '../../features/notifications/presentation/widgets/chat_notification_banner.dart';

class HouseShell extends ConsumerWidget {
  const HouseShell({
    required this.houseId,
    required this.location,
    required this.child,
    super.key,
  });
  final String houseId, location;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = '/houses/$houseId';
    final redesigned =
        [
          '$base/account',
          '$base/chores',
          '$base/rewards',
          '$base/achievements',
          '$base/karma/history',
          '$base/payments',
          '$base/seasons/new',
          '$base/chat/everyone',
          '$base/chat/assistant',
          '$base/chat/notifications',
        ].contains(location) ||
        RegExp('^${RegExp.escape(base)}/seasons/[^/]+/(leaderboard|rewards)\$')
            .hasMatch(location);
    final house = ref.watch(houseDetailProvider(houseId)).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final paths = [
      base,
      '$base/chores',
      '$base/chat',
      '$base/bonus',
      '$base/bounties',
    ];
    final section = location.startsWith('$base/')
        ? location.substring(base.length + 1).split('/').first
        : '';
    final selected = switch (section) {
      '' => 0,
      'chores' || 'urgent-event' || 'unresolved-chores' => 1,
      'chat' || 'ai' => 2,
      'bonus' || 'rewards' || 'achievements' || 'karma' => 3,
      'seasons'
          when location.endsWith('/leaderboard') ||
              location.endsWith('/rewards') =>
        3,
      'bounties' || 'payments' => 4,
      _ => null,
    };
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final conversation =
        location == '$base/chat/everyone' || location == '$base/chat/assistant';
    final selfContainedHeader =
        redesigned &&
        ([
              '$base/account',
              '$base/karma/history',
              '$base/seasons/new',
              '$base/payments',
            ].contains(location) ||
            RegExp('^${RegExp.escape(base)}/seasons/[^/]+/rewards\$')
                .hasMatch(location));
    return Scaffold(
      backgroundColor: redesigned ? AppPageFrame.background : null,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!keyboard && !conversation && !selfContainedHeader)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: redesigned ? 480 : 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.go('/houses'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                backgroundColor: colors.primaryFixed,
                                foregroundColor: colors.onPrimaryFixedVariant,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle_outlined, size: 7),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      house?.name ?? 'My House',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.expand_more_outlined,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'House Invite QR Code',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            maximumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            backgroundColor: colors.surfaceContainerLowest,
                            foregroundColor: colors.onSurfaceVariant,
                          ),
                          onPressed: house == null
                              ? null
                              : () => context.push(
                                  '$base/qr-invite',
                                  extra: house,
                                ),
                          icon: const Icon(Icons.qr_code_outlined, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(width: 44, child: NotificationBell()),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 72,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('$base/account'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                backgroundColor: colors.surfaceContainerLowest,
                                foregroundColor: colors.onSurface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.onPrimary,
                                    child: Text(
                                      profile?.displayName.isNotEmpty == true
                                          ? profile!
                                                .displayName
                                                .characters
                                                .first
                                                .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      profile?.displayName ?? 'Me',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
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
            Expanded(
              child: ChatNotificationBanner(location: location, child: child),
            ),
          ],
        ),
      ),
      bottomNavigationBar: keyboard
          ? null
          : AppBottomBar(paths: paths, selected: selected),
    );
  }
}
