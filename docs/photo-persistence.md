# Photo persistence and viewing

## Chore evidence

After **Use This Photo** or choosing a photo, the client uploads the bytes and saves the returned evidence ID onto that occurrence. **Photo saved to this chore** appears only after both operations succeed. The retained client request ID allows upload retries without duplicating a successful upload; **Save photo** retries a failed save. Returning from the evidence screen refreshes chore detail, where the saved image appears automatically and can be enlarged.

Saving is separate from optional AI feedback and chore completion. The assignee can add evidence to a chore they completed, without changing its completion status or awarding karma again. Skipped chores, other assignees, inactive members and non-started/cancelled seasons remain restricted. AI settings and inference authorization remain unchanged; an AI failure shows that the photo is saved and does not prevent manual completion.

Images stay in private media storage. `POST /api/occurrences/{id}/evidence/{evidenceId}/attach` revalidates actor, occurrence, house and season in a household mutation transaction. Existing `GET /api/evidence/{id}` membership rules still control image viewing.

## Chat photos

The household chat header has **Photo history**. `GET /api/chat/rooms/{roomId}/photos` returns only sent image messages, newest first, with pagination independent of currently loaded chat messages. Selecting an image opens an enlarged view. An empty room says that no photos have been shared. The gallery and image downloads require room access; drafts do not appear in history. Media caches follow the signed-in session.

## Account avatar

`UserProfileResponse` includes `avatarUrl` on upload, profile update and reload. Uploads use the server content root consistently. The current user retrieves their saved image through authenticated `GET /api/user/avatar-image`; no new public-file permissions are introduced. Profile, edit profile and the household header display the returned bytes. Saving waits for the refreshed profile before returning success. Local avatar files are ignored by Git.

## Verification

- Real authenticated HTTP and isolated PostgreSQL tests cover avatar upload/profile reload/image bytes, unauthenticated denial, evidence attach/read/retry, post-completion evidence without extra karma, photo-only history and non-member denial.
- Flutter camera tests simulate capture and verify automatic persistence without completion, retained saved status on AI failure, and reopening existing evidence without another upload.
- Gallery widget tests cover pagination, empty/error states and enlarging a photo. Camera hardware itself still needs a manual device check.
