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
    const labels = ['Overview', 'Chore', 'Chat', 'Bonus', 'Bounty'];
    const icons = [
      Icons.home_rounded,
      Icons.checklist_rounded,
      Icons.chat_bubble_rounded,
      Icons.stars_rounded,
      Icons.local_offer_rounded,
    ];
    final colors = Theme.of(context).colorScheme;
    final barColor = colors.surfaceContainerLowest;
    final activeColor = colors.primaryFixed;
    final inkColor = colors.onSurfaceVariant;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final conversation =
        location == '$base/chat/everyone' || location == '$base/chat/assistant';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!keyboard && !conversation)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 7),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      house?.name ?? 'My House',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.expand_more_rounded,
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
                          icon: const Icon(Icons.qr_code_rounded, size: 20),
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
                                shape: const StadiumBorder(),
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
                                        fontSize: 11,
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
      bottomNavigationBar: keyboard || conversation
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: barColor,
                      borderRadius: BorderRadius.circular(36),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              Expanded(
                                child: Semantics(
                                  selected: selected == i,
                                  child: TextButton(
                                    key: ValueKey('house-tab-$i'),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 56),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 6,
                                      ),
                                      shape: const StadiumBorder(),
                                      backgroundColor: selected == i
                                          ? activeColor
                                          : Colors.transparent,
                                      foregroundColor: selected == i
                                          ? colors.onPrimaryFixedVariant
                                          : inkColor,
                                      overlayColor: inkColor.withValues(
                                        alpha: .08,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 10,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () {
                                      if (location != paths[i]) {
                                        context.go(paths[i]);
                                      }
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icons[i], size: 23),
                                        const SizedBox(height: 3),
                                        Text(labels[i], maxLines: 1),
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
              ),
            ),
    );
  }
}
