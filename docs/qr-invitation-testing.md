# Test house invitations with two accounts

Use A (house owner) and B (a user who has not joined that house) in separate browser profiles. Signing in as the owner on both tabs cannot test joining: the server correctly rejects an existing member.

## Upload a QR image on a computer

1. A opens the house QR button in the header or **House settings → Show QR Code**.
2. Save a screenshot containing the whole black-and-white code, including its white margin. The QR does not need to fill the screenshot.
3. B opens **My houses → Scan QR to join**, or **Join a house → Or scan QR code**.
4. B selects **Choose QR image** and chooses the screenshot (PNG, JPG or WebP, below 10 MB).
5. Check that the confirmation shows A's house name and its member count. At this point B must still have no membership.
6. Select **Cancel**: no join request should be sent. Choose the image again and select **Join house**: B returns to My houses and sees the new house as a member.

Image decoding happens locally. The image is not uploaded to the API; only the decoded invite code is sent to the authenticated preview and join endpoints. Upload does not require camera permission, including when the camera permission prompt has not been answered.

## Scan using a webcam

1. Open the app through localhost on the computer or HTTPS. Allow the site's camera permission and close other applications using that webcam.
2. Display A's QR on a phone or a second display facing the webcam, or print it. The laptop webcam cannot see its own laptop screen unless you physically show it another copy.
3. Keep the complete code and white margin visible. Hold it steady, avoid reflections, and move it farther away if the image is out of focus. Desktop scanning defaults to the front camera; **Switch camera** selects another direction where available.
4. Check the same confirmation and join behavior as image upload. Keeping the same QR visible after canceling must not repeatedly open the dialog. Select **Scan again** to retry that code.

Browser cameras require a secure context and permission. Plain HTTP on a LAN IP is not equivalent to localhost. See [MDN getUserMedia security requirements](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia#privacy_and_security).

## Negative cases

| Case | Expected result |
| --- | --- |
| Cancel image picker | Remain on scanner; no API request and controls become available. |
| Photo with no QR / corrupt image | Clear error; choose another image or enter the code manually. |
| Unrelated QR such as a restaurant menu | Reject as a non-house invitation; no join or navigation to that URL. |
| QR mirrored or rotated | Decode a clear code normally. |
| Owner rotates invite after B sees the preview | Old code fails when joining; request the new QR. |
| Already an active member | Show the server rejection; no duplicate membership. |
| House full, archived or member banned | Preserve the server's membership restrictions; no join. |
| Camera blocked or unavailable | Choose QR image and manual invite entry stay available. |
| Repeated camera detections | One preview at a time; no automatic join. |

## Automated coverage

- `mobile/test/features/qr_image_decoder_test.dart`: real generated QR PNGs, mirror/rotation, invitation links, unrelated QR content, blank/corrupt/oversized images.
- `mobile/test/features/qr_join_flow_test.dart`: actual image decoder plus a simulated picker/scanner/API; preview/cancel/confirm, permissions denied or unanswered, API rejection, duplicate detections and desktop layout.
- `mobile/test/features/chat_mentions_test.dart`: invite-code parsing, including Flutter hash-route invitation links and malformed input.
- `backend/tests/IntegrationTests/Infrastructure/HouseNavigationTests.cs`: real registration/login, authenticated read-only preview, owner-only rotation, rotated-code rejection, membership creation and duplicate rejection in an isolated PostgreSQL test database.

Physical webcam focus, lighting and permissions on the user's device require the manual webcam check above. Simulated scanner events do not prove that a particular webcam can focus on a particular screen.
