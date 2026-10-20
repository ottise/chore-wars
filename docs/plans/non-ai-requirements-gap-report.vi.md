# ĐỐI CHIẾU YÊU CẦU MÔN VÀ SRS/BR — PHẦN KHÔNG AI

Ngày kiểm tra source: 18/10/2026. Nhóm có 4 người, tối thiểu 12 giao diện.

## 1. Cách hiểu kết quả

Đây là **kiểm tra tĩnh source**, chưa chạy APK/server/test/DB. “Có code” không đồng nghĩa “đã PASS”; “chưa thấy” là chưa tìm thấy implementation trong vùng source đã khảo sát, không kết luận về bản triển khai bên ngoài repository.

Theo xác nhận của bạn, nhóm đã hoàn thiện BE/FE. Bản này chỉ ghi khoảng cách quan sát được giữa source đang mở với yêu cầu, để nhóm có danh sách nghiệm thu cụ thể; không đánh dấu lại toàn bộ module là chưa làm.

Kế hoạch chạy test tương ứng: [non-ai-full-system-test-plan.vi.md](non-ai-full-system-test-plan.vi.md). Kế hoạch AI đầy đủ: [ai-python-full-implementation-plan.vi.md](ai-python-full-implementation-plan.vi.md).

## 2. Năm yêu cầu môn học

| Yêu cầu | Bằng chứng source hiện tại | Kết luận hiện tại | Cần để nghiệm thu |
|---|---|---|---|
| 1. Dịch vụ thanh toán | `BountyService.SettlePaymentAsync` cho debtor/creditor đổi obligation sang PAID; chưa thấy provider client/checkout/webhook khi tìm trong backend/mobile | **Khoảng trống quan trọng:** tracking/settle có code, chưa có bằng chứng dịch vụ thanh toán tích hợp | Một provider gắn nghiệp vụ, server verify kết quả, idempotency và demo sandbox/production ghi đúng môi trường |
| 2. Đăng nhập | Auth controller/service, secure storage và Dio refresh interceptor có source | **Có implementation, chưa test runtime** | Register/login/logout/reopen/refresh/revoke đạt trên APK thật |
| 3. 3 giao diện/người | Có 38 file `*screen.dart` dưới features; team 4 người nên cần 12 | **Có ứng viên đủ về số file; chưa xác nhận từng người/route/chức năng** | Bảng tên người → 3 màn riêng → route/commit/video, không đếm file trùng |
| 4. Product hoàn chỉnh | Có module household, season, chore, bounty, Karma, reward, chat, notification | **Chưa thể xác nhận chỉ từ source; có điểm lệch rule cần test** | APK release dùng API thật, E2E, không crash/đứt luồng, dữ liệu bền vững |
| 5. Ít nhất 3 ngoại vi | Có `mobile_scanner`, `image_picker` và QR camera screen; chưa thấy luồng mic/audio playback/TTS hoặc dependency tương ứng | **Chưa có bằng chứng đủ 3 loại; mới xác định camera trong code** | Camera + Micro + Loa hoạt động trên điện thoại, có permission/fallback và video |

**Ưu tiên trực tiếp cho điểm môn: dịch vụ thanh toán, Micro, Loa và bảng phân công 12 màn.** Camera quét QR/chụp ảnh tính một loại; loa không được tính chỉ bằng icon thông báo.

SRS/BR ghi “MVP chỉ tracking, không cần payment gateway” không tự đáp ứng yêu cầu môn “dịch vụ thanh toán”. Cần cập nhật phạm vi nghiệm thu: có provider thật hoặc có xác nhận giảng viên về hình thức được chấp nhận. Không cần chuyển tiền thật để lập/test kế hoạch; không báo sandbox là giao dịch tiền thật.

Gợi ý không-AI để đủ audio: ghi voice note trong chat bằng Micro rồi phát voice note bằng Loa. Đây là phương án cần implement nếu chọn, không phải chức năng đã có. Voice AI tương lai không được tính là ngoại vi hiện tại đã đạt.

## 3. Điểm lệch nghiệp vụ quan trọng có dấu hiệu trong code

Các ID dưới đây liên kết đến test trong kế hoạch. “Quan sát trực tiếp” là thấy logic cụ thể; tác động runtime vẫn cần ca tái hiện. “Nguy cơ” là chưa đủ cơ chế bảo vệ trong đoạn đọc, không tuyên bố race đã tái hiện.

| ID/ưu tiên | Yêu cầu | Quan sát source | Test cần chạy |
|---|---|---|---|
| G01/P0 | All required members confirm rồi active | `SeasonService.cs:425` đặt ACTIVE ngay trong một confirmation; `:111` có đường start từ draft | SEASON-03/04/06 |
| G02/P1 | Manual phải do thành viên tự chia | `SeasonService.cs:367` gọi allocator khi generate không phân nhánh method | ALLOC-04 |
| G03/P1 | Workload chính là Karma | `ChoreAllocationService.cs:70,164,283` dùng phút và summary phút; chưa có assigned Karma summary | ALLOC-02/07/11 |
| G04/P0 | Auto không giao người bận/vượt constraint | `ChoreAllocationService.cs:123–134` fallback bỏ constraint rồi lấy mọi member | ALLOC-05/06 |
| G05/P1 | Manual không bị availability chặn | `ChoreAllocationService.cs:231–233` từ chối người được đánh dấu unavailable | ALLOC-03; rule BR-AVAIL-03 |
| G06/P1 | Availability có giờ; normal chore có deadline cấu hình | Entity availability chỉ có thứ/bool; `Chore`/CreateChoreRequest chưa có deadline time; generation `:131` đặt 23:59 | ALLOC-01, CHORE-03 |
| G07/P1 | Hỗ trợ toàn bộ frequency trong BR | Enum có 9 loại; generation switch chỉ có daily/every-X-days/weekly/specific-days, default xử lý chung | GEN-04/05/06 |
| G08/P0 | Sinh/xóa occurrence đúng mùa | Generation `:47` lấy mọi chore theo house; repository delete lọc `o.Chore.SeasonId` thay vì `o.SeasonId` | GEN-07, SEASON-10 |
| G09/P0 | Chat chỉ member hợp lệ nghe được room | `ChatHub.cs:35–38` JoinRoom thêm group theo roomId chưa kiểm membership tại method | CHAT-02/03; REST send có check không thay thế check join group |
| G10/P0 | Chỉ active member đúng nhà accept bounty chưa hết hạn | `AcceptBountyAsync` kiểm OPEN/self nhưng chưa thấy membership/ExpiresAt check trong method | BOU-04, thử user X/inactive và race expiry |
| G11/P0 | Complete/claim/accept chỉ một lần khi đồng thời | Nhiều service kiểm trạng thái rồi ghi; cần xác minh isolation/constraint/concurrency token thực tế | DONE-03, BONUS-01, BOU-03/05, PEN-03; chưa kết luận đã tái hiện race |
| G12/P0 | Forced obligation phải truy vết occurrence/season | Object tạo tại `BountyExpirationService.cs:73` chưa gán OccurrenceId/SeasonId | BOU-10; ảnh hưởng list/detail/audit |
| G13/P0 | Người nhận forced hợp lệ, failure mới độc lập | Forced chọn theo KarmaBalance rồi random, chưa thấy active/availability/limit filter; counter penalty chưa reset theo trách nhiệm mới tại đây | BOU-08/12/13, PEN-07 |
| G14/P1 | Nhà tối đa 6, rejoin sau leave | `JoinHouseAsync` kiểm tồn tại member rồi conflict; chưa thấy cap 6 trong method | HOUSE-04/08; kiểm thêm repo/status trước kết luận |
| G15/P1 | Reward người dùng định nghĩa và redeem bằng Karma | Controller gamification thấy get/claim/chore-pass/achievements, chưa thấy create/redeem reward tùy chỉnh | REWARD-01/02, kiểm contract tương đương nếu có |
| G16/P2 | Share achievement card | Screen achievements hiện hiển thị card, chưa thấy action share/platform share trong khảo sát | ACH-02; có card UI chưa đủ chứng minh export/share |
| G17/P1 | Reuse giữ cấu hình cần thiết | Clone season chưa copy Difficulty/EstimatedMinutes | SEASON-09 |
| G18/P1 | Route hoạt động nhất quán | `app_router.dart` khai báo lặp `/bounties`, `/bounties/create`, detail và `/karma-history`; có module màn tương tự | Navigate mọi route release, deep link, refresh/back; không tự đếm trùng UI |
| G19/P1 | Mới overdue đã có trạng thái/notification đúng | Penalty service bỏ qua khi chưa đủ 12h; cần kiểm đường khác có chuyển OVERDUE ngay sau deadline không | PEN-01/06 |
| G20/P0 | Tính đúng thời gian bounty khi post sau critical | Create bounty `ExpiresAt=occurrence.DueDate` tại `BountyService.cs:51`; nếu due đã qua sẽ expired ngay | BOU-02, D04/D05 |

Các mục G01–G20 là backlog kiểm chứng/fix có trọng tâm, không phải yêu cầu làm lại toàn bộ BE/FE. Không sửa code nghiệp vụ trong lần lập tài liệu này.

## 4. Cấu hình release và bằng chứng còn thiếu

- Android main manifest hiện không khai báo INTERNET trực tiếp, debug manifest có. Cần inspect **merged release manifest** trước kết luận release thiếu quyền vì plugin có thể bổ sung manifest. Tương tự kiểm CAMERA và RECORD_AUDIO theo tính năng.
- iOS `Info.plist` khảo sát chưa thấy camera/microphone/speech usage description; kiểm tra nếu có nộp iOS. Android là trọng tâm nếu chỉ nộp APK.
- `AppConstants` mặc định mobile dùng `10.0.2.2`; phải build release bằng URL server cho điện thoại thật, cùng SignalR URL và `UI_PREVIEW=false`.
- `backend/tests/IntegrationTests/UnitTest1.cs` và `UnitTests/UnitTest1.cs` là test trống; có test generation riêng, nhưng chưa có bộ evidence cho toàn bộ critical flows.
- `mobile/test` hiện thấy hai file model tests; chưa có `mobile/integration_test` trong source khảo sát. Không có automated E2E không chứng minh app sai, nhưng thiếu bằng chứng regression.
- Chưa xác nhận deployment, build release thành công, payment provider, ba ngoại vi thật, test report, backup/restore hoặc video end-to-end trong phiên này.

## 5. Những yêu cầu tài liệu chưa rõ hoặc đang mâu thuẫn

1. Bounty mở ngay sau assigned hay chỉ khi critical overdue; expiry phải nhất quán với lựa chọn này.
2. Compensation snapshot lúc tạo bounty hay forced reassignment; Received do receiver hay cả debtor được xác nhận.
3. Penalty tối đa theo occurrence và “failure mới” của forced assignee cần định nghĩa episode/giới hạn chain cụ thể.
4. Ai được sửa/regenerate khi reviewing/active; xử lý confirmation cũ và thành viên thay đổi.
5. Timing occurrence: phải có dữ liệu để review trước active nhưng không sinh trùng/kích hoạt sớm.
6. Chính sách timezone, interval availability, monthly/custom frequency, upload proof và retention.
7. Household tối thiểu 3 áp dụng lúc nào; join cap 6; disband/invite management và quyền member ngang nhau.
8. Tie-break bonus tính tổng điểm hay số lần; rank cuối mùa phải snapshot và bất biến.
9. Notification chỉ trong app hay cả app đóng; không đặt kỳ vọng push nếu chưa chốt.
10. Chore Pass reassign phải có người hợp lệ, không tạo việc biến mất hoặc chuyển penalty của người dùng pass sai người.

Các mục này có decision log D01–D15 trong test plan. Không đánh FAIL vì một cách diễn giải chưa chốt; đồng thời không dùng khoảng trống để bỏ qua kiểm tra.

## 6. Thứ tự xử lý/kiểm chứng đề xuất

1. Khóa phạm vi payment provider, Micro/Loa và phân công 12 màn cho đúng 4 người.
2. Chạy P0: confirmation, quyền REST/SignalR, complete/claim/accept đồng thời, audit tiền/Karma.
3. Chạy frequency/deadline/availability/manual/auto đối chiếu đúng BR, kể cả các điểm hiện source chưa khớp.
4. Chạy end-to-end overdue/bounty/forced/payment/reward trên fixture độc lập.
5. Test release trên điện thoại thật, ghi evidence; sau fix chạy regression vùng ảnh hưởng.

Kết luận hiện tại: **chưa đủ bằng chứng để xác nhận đạt toàn bộ 5 yêu cầu môn**. Khoảng trống rõ nhất trong source khảo sát là payment service và Micro/Loa; số màn có tiềm năng đủ 12 nhưng chưa có bảng ownership/nghiệm thu. Chất lượng product cần được chứng minh bằng test plan, không suy ra từ số lượng file hoặc module đã có.
