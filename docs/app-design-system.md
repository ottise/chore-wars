# Application design core

This core replaces the earlier independent Stitch styling throughout the Flutter app. Screen layouts continue to follow the selected references where applicable, while all pages share `AppTheme`.

| Role | Token |
| --- | --- |
| App background | `#F8F6F2` |
| Surface | `#FFFFFF` |
| Main text | `#27232F` |
| Secondary text | `#6D6775` |
| Border | `#E7E2EA` |
| Primary purple | `#6845D6` |
| Light purple | `#F0EBFA` |

## Typography

Be Vietnam Pro is bundled locally in Regular (400), Medium (500) and Semibold (600). Screen titles use 24px, section/item names 16px semibold, body copy 14–15px, and secondary information 12–13px. Large numerical balances may use display styles. Text scaling remains enabled.

Fonts come from the [Google Fonts Be Vietnam Pro source](https://github.com/google/fonts/tree/main/ofl/bevietnampro); its OFL license is bundled with the assets. Runtime font downloads are not required.

## Components

- Screen inset: 20px. Spacing inside groups: 8–12px. Group separation: 24px.
- Controls: 10–12px corners; content cards: 14–16px corners.
- Ordinary cards, navigation, message bubbles and buttons have no shadow. Menus, dialogs and sheets can have elevation.
- Material outlined icons are used where available. Generic icon tiles are removed; status accents remain conditional on real state.
- Solid purple identifies the main action. Repeated actions use text/outlined variants. Green/red/amber are retained for real success, error, overdue and pending states.
- `AppPageFrame` controls layout width only and inherits `AppTheme`; it does not install a second color or typography system.
- `AppPageBar` and `AppBottomBar` are shared application components. The same bottom bar is used across house routes.
- `/profile`, opened from My Houses, shows account information only: avatar, display name, email, editing and sign out. It never infers a household from the last selected house or requests household data. Karma, house role, chores, notifications and schedule tabs belong to `/houses/:houseId/account`, using that explicit route's household.

## Verification

The layout suite renders representative pages at 390px with normal text and at 320px with 120% text. Contrast and inherited-theme checks prevent divergence between page layouts and the app core. The local machine has no Android platform-tools in its standard SDK path; physical-device verification remains outstanding.
