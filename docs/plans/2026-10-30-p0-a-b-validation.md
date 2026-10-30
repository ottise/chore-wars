# P0-A / P0-B implementation and validation

Scope: A01–A06 and B01–B10 from the supplied `fix.txt`. Chat unread, membership redistribution, bounty payment/deadline policy, and other priority groups are outside this change.

## Occurrence links and evidence

| Entry point | Behavior |
| --- | --- |
| Home, calendar, Mine, Team | Open `/houses/:houseId/chores/:occurrenceId`. |
| Bonus | Opens the occurrence detail; claiming remains a separate action. |
| Bounty board and detail | Open the original occurrence through the house route. |
| CHORE notifications | Existing house/occurrence route retained. |
| Chat action cards | No independent chore-detail link or template-as-occurrence link found. |
| Legacy `/chores/:occurrenceId` | Resolve the occurrence with the membership-protected API, then replace the URL with its actual house route. Query labels and the selected house do not identify the occurrence. |

Detail loads its own occurrence, including house, season, assignee, snapshot values, deadline and planned start. It does not require the current season's definitions. A mismatched house route is rejected. The backend supplies completion and photo-upload capabilities, including overdue and completed evidence rules. Completion uses the occurrence's evidence ID; photo capture/gallery use the existing persistent evidence upload/attach flow. New timestamps are displayed with Vietnam time labels; missing, ambiguous or invalid API timestamps do not become today's date.

Bounty create/detail Back buttons pop when possible and otherwise open the board with the same house. The board falls back to the house overview. Successful writes can return from a direct URL without a `pop` exception.

## Creation and existing data

Active owners and members can create chores in an unarchived house. Administrative permissions stay with the owner. The normal UI has Mine / Team / Bonus, defaults to Mine, and exposes Add chore in the header. The form creates a real season chore, with type, effort, Karma, recurrence start date, deadline and optional repeated/custom dates. The old routine toggle and routine import UI are removed. Old `?routine=true` creation links still reach this form.

Creation adds only the new chore's occurrences. DRAFT keeps existing generated rows. REVIEWING increments the revision and resets every active member's approval to pending for that revision. ACTIVE adds future dates within the season, honors declared availability, date exceptions, existing occupied slots and capacity, and preserves existing assignments and history. Manual seasons or impossible allocations return `needs_assignment` with a reason; Team exposes an owner-only assignment action. Active assignments enforce availability/capacity as well.

Create requests use a client request UUID scoped to house and actor. The existing PostgreSQL house mutation coordinator serializes mutations. Retrying a committed request returns the same chore and occurrence IDs; reusing a key with changed content is rejected. Occurrence IDs are deterministic per season/chore/date. Expected revision is supported for callers that need to reject a stale schedule.

Legacy routine definitions remain intact. The compatibility import endpoint is an explicit action, maps `SourceTemplateId` to one season snapshot, generates only after that action, and deduplicates retries. An existing empty snapshot can generate its missing schedule without creating another definition. Nothing bulk-imports routines on startup or deletes history. No schema migration is required.

## Validation

- Backend unit suite: **139 passed**.
- PostgreSQL integration selection: **8 passed**, using disposable local databases. Covers concurrent creates/retries, reviewing approvals, both legacy import cases, owner assignment, authenticated evidence persistence, and automatic/manual household season journeys.
- Flutter suite: **144 passed, 1 skipped**. The skipped live-network test requires its separate disposable Kestrel fixture. Includes legacy deep links, wrong-house rejection, historical occurrence loading, Vietnam midnight conversion, malformed timestamps, member/owner creation UI, direct bounty Back/success, camera controls, and narrow-screen layouts.
- Dart analysis and `git diff --check` run on the final changes.
- UI review applied the relevant accessibility, loading/error state, navigation and layout rules from the Web Interface Guidelines to the changed Flutter widgets; palette and BeVietnamPro font retained.

The machine has .NET SDK 10.0.401 while the repository pins 10.0.302. Verification used a temporary working-directory SDK override without editing the project's `global.json`. NuGet reports the existing AutoMapper advisory; dependency upgrades are outside this task.

Not deployed. Physical-device camera permissions and a manual production-browser refresh are not exercised by the automated tests. Deploy the backend and Flutter client together so the new occurrence capability and house fields are available.
