import '../../features/chore/presentation/providers/chore_providers.dart';
import '../../features/bounty/presentation/providers/bounty_providers.dart';
import '../../features/supplies/presentation/providers/supplies_providers.dart';
import '../../features/house/presentation/providers/household_summary_provider.dart';
import '../../features/notifications/presentation/providers/notification_providers.dart';
import 'app_page_frame.dart';
import 'app_bottom_bar.dart';
import 'assistant_shortcut.dart';
import '../../features/chat/presentation/widgets/urgent_campaign_notification.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/avatar_provider.dart';
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
    ref.listen(
      notificationNotifierProvider.select((state) => state.latestArrival),
      (previous, next) {
        if (next != null && next.houseId == houseId && !next.isChat) {
          refreshHouseState(ref, houseId: houseId);
          refreshChoreState(ref, houseId);
          ref.invalidate(bountyBoardProvider(houseId));
          ref.invalidate(purchaseDebtsProvider(houseId));
          ref.invalidate(householdSummaryProvider);
        }
      },
    );
    final base = '/houses/$houseId';
    final redesigned =
        [
          '$base/account',
          '$base/account/payments',
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
        location.startsWith('$base/supplies') ||
        location.startsWith('$base/orders') ||
        RegExp('^${RegExp.escape(base)}/seasons/[^/]+/(leaderboard|rewards)\$')
            .hasMatch(location);
    final house = ref.watch(houseDetailProvider(houseId)).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final avatar = profile?.avatarUrl?.isNotEmpty == true
        ? ref.watch(accountAvatarProvider(profile!.avatarUrl!)).asData?.value
        : null;
    final paths = [
      base,
      '$base/chores',
      '$base/chat/everyone',
      '$base/orders',
      '$base/bounties',
    ];
    final section = location.startsWith('$base/')
        ? location.substring(base.length + 1).split('/').first
        : '';
    final selected = switch (section) {
      '' => 0,
      'supplies' || 'orders' => 3,
      'chores' || 'urgent-event' || 'unresolved-chores' => 1,
      'chat' || 'ai' => 2,
      'bonus' || 'rewards' || 'achievements' || 'karma' => 1,
      'seasons'
          when location.endsWith('/leaderboard') ||
              location.endsWith('/rewards') =>
        1,
      'bounties' || 'payments' => 4,
      _ => null,
    };
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final conversation =
        location == '$base/chat/everyone' || location == '$base/chat/assistant';
    final assistantShortcutPage =
        location == base || location == '$base/chores';
    final selfContainedHeader =
        redesigned &&
        ([
              '$base/account',
              '$base/account/payments',
              '$base/karma/history',
              '$base/seasons/new',
              '$base/payments',
            ].contains(location) ||
            location.startsWith('$base/supplies') ||
            location.startsWith('$base/orders') ||
            RegExp('^${RegExp.escape(base)}/seasons/[^/]+/rewards\$')
                .hasMatch(location));
    return Scaffold(
      backgroundColor: redesigned ? AppPageFrame.background : null,
      resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: keyboard || conversation || !assistantShortcutPage
          ? null
          : AssistantShortcut(houseId: houseId),
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
                      horizontal: 10,
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
                                minimumSize: const Size(0, 38),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
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
                                  const Icon(Icons.circle_outlined, size: 8),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      house?.name ?? 'My House',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.expand_more_outlined,
                                    size: 17,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'House Invite QR Code',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(38, 38),
                            maximumSize: const Size(38, 38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            backgroundColor: colors.surfaceContainerLowest,
                            foregroundColor: colors.onSurfaceVariant,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          onPressed: house == null
                              ? null
                              : () => context.push(
                                  '$base/qr-invite',
                                  extra: house,
                                ),
                          icon: const Icon(Icons.qr_code_outlined, size: 19),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'Season Ranking',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(38, 38),
                            maximumSize: const Size(38, 38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            backgroundColor: colors.surfaceContainerLowest,
                            foregroundColor: const Color(0xFFD97706),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          onPressed: house == null
                              ? null
                              : () async {
                                  final cached = ref
                                      .read(activeSeasonProvider(houseId))
                                      .asData
                                      ?.value;
                                  final season =
                                      cached ??
                                      await ref
                                          .read(
                                            activeSeasonProvider(
                                              houseId,
                                            ).future,
                                          )
                                          .catchError((_) => null);
                                  if (!context.mounted) return;
                                  final seasonId = season?['id']?.toString();
                                  if (seasonId != null && seasonId.isNotEmpty) {
                                    context.push(
                                      '$base/seasons/$seasonId/leaderboard',
                                    );
                                  } else {
                                    context.push('$base/more');
                                  }
                                },
                          icon: const Icon(
                            Icons.emoji_events_outlined,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: NotificationBell(
                            houseId: houseId,
                            iconSize: 19,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(38, 38),
                              maximumSize: const Size(38, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              backgroundColor: colors.surfaceContainerLowest,
                              foregroundColor: colors.onSurfaceVariant,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'House Settings',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(38, 38),
                            maximumSize: const Size(38, 38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            backgroundColor: colors.surfaceContainerLowest,
                            foregroundColor: colors.onSurfaceVariant,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          onPressed: () => context.push('$base/settings'),
                          icon: const Icon(Icons.settings_outlined, size: 19),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: profile?.displayName ?? 'Account',
                          child: InkWell(
                            onTap: () => context.push('$base/account'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.onPrimary,
                                    backgroundImage: avatar != null
                                        ? MemoryImage(avatar)
                                        : null,
                                    child: avatar != null
                                        ? null
                                        : Text(
                                            profile?.displayName.isNotEmpty ==
                                                    true
                                                ? profile!
                                                      .displayName
                                                      .characters
                                                      .first
                                                      .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                  if (MediaQuery.sizeOf(context).width > 420 &&
                                      (profile?.displayName.isNotEmpty ??
                                          false)) ...[
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 72,
                                      ),
                                      child: Text(
                                        profile!.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
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
            if (!keyboard)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: redesigned ? 480 : 800),
                  child: UrgentCampaignNotification(
                    key: ValueKey(houseId),
                    houseId: houseId,
                  ),
                ),
              ),
            Expanded(
              child: ChatNotificationBanner(
                location: location,
                houseId: houseId,
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: keyboard
          ? null
          : AppBottomBar(
              chatUnread:
                  ref.watch(unreadChatCountProvider(houseId)) +
                  ref.watch(unreadAssistantCountProvider(houseId)),
              paths: paths,
              selected: selected,
            ),
    );
  }
}
