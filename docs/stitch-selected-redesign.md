> Visual styling in this document is superseded by [Application design core](app-design-system.md). Stitch references remain layout references only.

# Selected Stitch redesign

Source project: Modern Minimalist Web Redesign (`13284825824866552973`).

Only the 14 selected designs below are applied. The two chat references share one functional household chat; Routines and Mine remain tabs of the existing chores page. The Team tab retains the application theme. Selected routes use a flat bottom navigation bar and page-specific header composition. Account, Karma History, Start New Season, Payments and Season Rewards use their own header; Chores, Household Rewards, Achievements and Leaderboard retain the utility row. Conversation routes retain their own header and show bottom navigation while the keyboard is closed. Unselected routes retain the previous shell and the global application theme is unchanged.

## Visual system

`StitchScreen` scopes the cream background (`#FBF9F6`), white cards, soft borders, rounded controls and bundled Plus Jakarta Sans font to selected screens. Purple filled controls use `#7857F8` with white text for readable contrast. Existing dark-mode surfaces are retained.

Account identity and Karma blocks, reward balance, achievement header, season reward hero, chat canvas, notification rows and Mine status stripes follow the references while displaying live provider data. Existing loading, error, empty and retry states remain functional.

## Source mapping

Paths below are relative to `mobile/lib/features/`.

| Stitch screen | ID | Implementation |
| --- | --- | --- |
| Household Rewards (Redesign) | `28a2e55f90c94ec89944b153b5812332` | `gamification/presentation/screens/reward_catalog_screen.dart` |
| Karma History (Redesign) | `4f5a1249b492421faa785fd4510585e6` | `gamification/presentation/screens/karma_history_screen.dart` |
| Family Chat (Redesign) | `5df15e67e62b403ea2ce4d7bb159a534` | `chat/presentation/screens/chat_room_screen.dart` |
| System Notifications (Redesign) | `74dde9086a304e3aaac6ba15502312bb` | `notifications/presentation/screens/notifications_screen.dart` |
| House Achievements (Redesign) | `82dc79f0aaad4f2e9de230e1f7a843ad` | `gamification/presentation/screens/achievements_screen.dart` |
| Family Group Chat (Redesign) | `938ba135828a4e58aea9eafca7bf2eee` | `chat/presentation/screens/chat_room_screen.dart` |
| Season Rewards (Redesign) | `94d66fe08c1543a68594d2d774a8fc6d` | `gamification/presentation/screens/season_reward_screen.dart` |
| Start New Season (Redesign) | `9c6db8b2d8c64445bd75bea95f88aad6` | `house/presentation/screens/create_season_screen.dart` |
| Payment Obligations (Redesign) | `a6537a5658e6461da9d9d593c6770b15` | `payment/presentation/screens/payment_obligations_screen.dart` |
| AI Assistant Chat (Redesign) | `d0cc92949a19493c96e9212359755acf` | `chat/presentation/screens/assistant_chat_screen.dart` |
| My Account & Karma (Redesign) | `f241dc32b0f8419a93165a2fdd4f8b2c` | `auth/presentation/screens/profile_screen.dart` |
| Personal Chores (Mine - Redesign) | `f303ff6d52f74dcf930e9728203e1858` | `chore/presentation/screens/chore_list_screen.dart (Mine)` |
| Chores - Routines (Redesign) | `f9ec6251b3514c5c8da322ce933914bc` | `chore/presentation/screens/chore_list_screen.dart (Routines)` |
| House Standings & Leaderboard (Redesign) | `feacc427cf4c42f98d6402dec9c928bd` | `gamification/presentation/screens/leaderboard_screen.dart` |

## Excluded reference-only content

- Sample names, balances, messages, ranks and dates are not copied into production.
- XP, weekly streaks, arbitrary household milestones, monthly percentage changes and chore quotas are omitted because the current responses do not provide those values.
- Reward claimed-history tabs, coffee/prize offerings and fake reward inventory are omitted. Existing custom rewards and season reward claims keep their real data and actions.
- Payment expense creation and a shared expense pool are omitted. Existing bounty payment obligations and confirmation rules remain.
- Season carry-over/strict-penalty switches are omitted because the create-season API does not support them.
- Fake online/typing indicators and invented assistant messages are omitted. The private assistant keeps its current supported requests and server availability checks.

The downloaded HTML is design reference material; remote scripts and mock business logic are not imported into Flutter.

## Layout correction pass

- Rebuilt Account with segmented tabs, inline role pill, a separate inset balance panel, three breakdown cells with units, and a full-width history row.
- Added consistent circular back controls and constrained selected page content to a phone-width column on larger displays.
- Rebuilt the podium avatar/rank badges, compact rank cards and contribution rows.
- Moved achievement percentage into a separate header badge; reduced grid height while expanding for larger text.
- Rebuilt season form inputs as labeled white cards and date controls as horizontal icon/value rows.
- Reduced reward card height and moved creation into the page header as well as the existing footer.
- Matched short household conversations to the top of the message area; retained reverse ordering and history pagination.
- Preview coverage now includes the actual shell, household chat, private assistant, notifications, Routines and Mine, alongside the account, reward, ranking and payment pages.

`mobile/build/stitch-review-v2/index.html` compares original Stitch images with rendered Flutter layouts using test fixtures at 390px. The layout test also renders at 320px with text scaled to 120%.
