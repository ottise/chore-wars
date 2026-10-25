# Assistant user flows

AI setup, learning/model status and evaluation dashboards are internal. The app
does not fetch them. Old settings/evaluation links redirect to Assistant.
Background telemetry and evaluation workers retain their authorization and consent
checks. No new consent is granted when a user opens Assistant.

## Private Assistant and household chat

Private requests use the server's AI configuration, independently of the household
background-analysis switch. In household chat, mention Assistant or choose the
header's **Ask Assistant** action to open the same prompt/voice flow in a sheet
without leaving the conversation. Member mentions are
preserved as names in the AI request.

For urgent tasks, type or speak the work, named participants and a time budget or
an absolute event time. Assistant supports Vietnamese voice input and an English/
Vietnamese speech-language selector. A party at 22:00 tonight means preparation
must finish by that fixed time in Vietnam. Guest count is separate from workers;
ten guests never become ten household assignees. Assistant
asks for missing details, then prepares a plan for the current active season.
Explicit assignees are retained; an unavailable assignee makes the plan infeasible
rather than moving their task to another person. No resources or participants are
invented. The existing planner still checks availability, capacity and dependencies.

When a plan is feasible, the backend's `urgent/request` operation creates one
idempotent proposal and notifies its targets automatically. Retrying the same
request does not send duplicate invitations. The sender sees the plan and its
timeline; no second send-plan button is required. Each target sees a task request in
Assistant and Household Chat. Notification taps open Assistant. The campaign
starts only after all required members approve. The event deadline stays fixed
when approval arrives later; an elapsed or infeasible deadline requires a new
request. Fixed-time event invitations remain pending until the event deadline;
immediate-duration requests retain the existing short approval window.
Rejecting a request does not
assign its tasks. Confirmations and existing schedule/household checks remain.

## Media and empty states

- Read aloud selects an installed English voice, including locales other than
  en-US. If none exists, it shows **Read unavailable**. Browser/device speech
  services are required; a provider key does not supply a device voice.
- Speech recognition reports microphone/service failures and keeps typed input.
- Photo attachments in private Assistant are not implemented. Photo upload in
  Household Chat and chore evidence remains a separate supported flow.
- Avatar selection previews image bytes and uploads multipart bytes through
  `/api/user/avatar`; it does not use browser blob URLs as filesystem paths.
- Bounty posting lists only the signed-in member's assigned, overdue or critically
  overdue chores. The backend remains responsible for final authorization.
- Empty bounty suggestions show **No bounty suggestions yet** and do not generate
  placeholder recommendations.

See [local service setup](ai-local-setup.md) for operational configuration. Credentials
remain in ignored local files or deployment environment variables.

## Verification (2026-10-24)

- Flutter: 70 tests pass; `flutter analyze lib test` reports no issues.
- Python: 17 capability and language-provider tests pass, including UTC deadline
  serialization and strict validation after simplifying Gemini's generation schema.
- Backend: 22 related cases passed in the initial run; the two new cases passed
  after correcting test-fixture setup and an assertion against a stale tracked
  object. These include consent/authorization and idempotent targeted requests.
- A real Core-to-Python-to-Gemini interpretation passed using a disposable test
  database, without household AI settings or chat-analysis consent.
- The Vietnamese party prompt was also tested through real Core, Python and
  Gemini: ten guests, two workers, a fixed 22:00 Vietnam deadline, a targeted
  notification for Trinh, and approval ten minutes later. New tasks were created
  only after approval and retained the original deadline. These records were in
  a disposable test database, not the user's household.
- Debug web build succeeds. Backend readiness and the local web app return 200.
- Review renders cover 320px at 120% text and 390px at normal text, with actual
  Be Vietnam Pro and Material icon fonts loaded.
- Audible output on the user's physical device has not been verified. Voice
  selection, playback invocation and the missing-voice state are covered by tests.
