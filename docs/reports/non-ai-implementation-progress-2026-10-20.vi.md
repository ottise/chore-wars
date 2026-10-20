# Tiến độ triển khai không-AI — 20/10/2026

> **Kết quả mới hơn:** xem [biên bản runtime source non-AI](non-ai-runtime-verification-2026-10-20.vi.md): 55 unit, 27 integration và 12 Flutter test PASS; 6 PostgreSQL bắt buộc và 10 Kafka thật đã chạy, không còn SKIP ở lượt runtime cuối. Báo cáo bên dưới giữ tiến độ của lượt trước.

## Phạm vi và trạng thái

Bám theo `docs/plans/non-ai-10-groups-implementation-plan.vi.md`, baseline Git `8bad321`. Đây là báo cáo code và kiểm thử, chưa phải biên bản nghiệm thu toàn bộ sản phẩm. Các thay đổi còn nằm trong working tree để review.

Theo yêu cầu mới nhất: tiếp tục code; chưa đóng gói APK, chưa yêu cầu URL deploy. AI/Python/model training và payOS/thủ quỹ/QR chuyển tiền tiếp tục nằm ngoài đợt triển khai này. Payment tracking và người nhận xác nhận đã thu tiền không thay thế yêu cầu dịch vụ thanh toán của môn học.

## Các nhóm đã có code

| Nhóm | Backend | Mobile |
| --- | --- | --- |
| Nhất quán dữ liệu | Coordinator khóa transaction theo house; unique index nghiệp vụ; transactional outbox; consumer dedup và chỉ commit offset sau dữ liệu | Single-flight refresh token, retry một lần; dọn trạng thái phiên và refresh router khi hết phiên |
| Vòng đời season | Generate ở DRAFT, submit REVIEWING, mọi thành viên active xác nhận đúng revision; reject lưu lý do; không bypass start | Nút generate/submit/confirm/reject theo trạng thái; gửi revision; hiển thị workload |
| Lịch và routine | 9 loại recurrence, deadline theo giờ Việt Nam, snapshot, routine import/copy; phân công Karma-first, capacity, khung giờ và không chồng việc | Form deadline/recurrence/custom dates; nhập routine vào mùa; khai báo khung giờ rảnh |
| Thành viên/house | Active membership, tối đa 6; rotate invite, preview, transfer owner, archive; chặn rời nhà khi còn nghĩa vụ; thu hồi kết nối chat | Luồng quản lý nhà, QR vào nhà, thiết lập nhà; QR này không phải chuyển tiền |
| Trách nhiệm/bounty | Episode trách nhiệm; 3 lần phạt 5 Karma cách nhau 12h; bounty hết hạn 24h; tối đa một bồi thường 120%/occurrence | Bounty board/detail, payment tracking; người nhận xác nhận tiền |
| Việc chưa giải quyết | Danh sách unresolved, tự nguyện nhận trách nhiệm với hạn 24h; không tạo bồi thường tiếp; claim bonus có khóa | Màn unresolved và nút nhận việc; bonus chỉ claim khi còn hợp lệ |
| Gamification | Reward cost, create/update/disable/redeem, chống overspend; pass giữ nguyên nếu không có người thay; rank từ ledger season | Reward catalog/form create/edit/disable; chia sẻ PNG thành tích server bằng native share sheet |
| Chat/media/ngoại vi | Private attachment, quyền truy cập khi đọc/gửi; giới hạn ảnh/audio; kiểm tra M4A và duration; UUID chống gửi trùng; cleanup media bỏ dở | Camera/ảnh, ghi âm AAC/M4A, nghe/xóa/gửi lại; một audio player, dừng khi background; media tải có auth |
| Kết thúc mùa | Phạt đến cutoff trước snapshot; lưu rank và pass một lần; giữ balance qua mùa; completion muộn không đổi ledger mùa đóng | Hiển thị ranking/reward theo API |
| Vận hành/test | Migration mới, SQL preflight, health live/ready, private-media volume, script test DB dùng một lần | Kiểm tra cấu hình release có sẵn, bước release đang hoãn |

## Bổ sung trong lượt tiếp tục

- Chặn gửi attachment vào house đã archive, kể cả endpoint không mang `houseId` trên URL.
- Hoàn thiện hết phiên: xóa token, thông báo hết phiên một lần, đổi session epoch để hủy cache/kết nối cũ và refresh router về login.
- Sửa ghi âm/preview dùng chung player; bỏ phát âm thanh khi chuyển nền; tránh thao tác phát cũ tiếp tục sau thao tác mới.
- Khi thay đổi sở thích hoặc capacity ở draft: tăng revision, bỏ confirmations, xóa lịch automatic cần tính lại. REVIEWING yêu cầu reject trước khi sửa.
- Manual allocation có cảnh báo vượt thời gian rảnh; bonus không đi qua đường phân công mandatory.
- API assign cũ phải chọn occurrence đã generate; không tự tạo occurrence vào một ngày tùy ý. Hạn và snapshot giữ nguyên.
- Custom reward sửa được name/description/cost/enabled; không sửa Chore Pass qua endpoint này; không xóa redemption lịch sử.
- Tie-break rank bổ sung joined time và user ID.
- Bounty accept/expiry tính phạt của người cũ đến thời điểm bàn giao trước khi đóng episode, tránh phụ thuộc thứ tự chạy worker.
- Payload Kafka không parse được đi vào cùng đường retry/seek; tránh commit offset sau một sự kiện chưa xử lý.

## Kiểm thử đã thực hiện

- Backend unit: **47/47 PASS** ở lượt chạy cuối ngày 20/10/2026; backend build thành công. Các nhóm bao gồm recurrence, all-confirm/revision, allocation eligibility, receipt permissions/idempotency, media, reward eligibility và legacy assignment.
- Integration không yêu cầu DB: 3 PASS.
- Integration PostgreSQL: 6 test đã viết (4 concurrency, 1 HTTP auth/private media/range, 1 upgrade dữ liệu cũ). Lượt 20/10 không xác nhận PASS: Docker engine không có named pipe và PostgreSQL `127.0.0.1:57154` từ lượt trước không còn lắng nghe. Khi bỏ biến kết nối, cả 6 được đánh dấu SKIP rõ ràng.
- Flutter: 9/9 PASS. Có test concurrent refresh, refresh thất bại chỉ báo hết phiên một lần, giới hạn retry, typed audio/legacy text và proposal hoãn không có nút execute.
- `dart analyze lib test`: không có issue. `flutter analyze --no-pub` toàn thư mục còn 2 info `avoid_print` ở script bảo trì `fix_imports.dart` và `update_errors.dart`, không thuộc source app.
- Chưa chạy E2E trên điện thoại, Kafka broker thực, mic/camera/speaker/native share, tình huống offline/reconnect trên máy thật hoặc upgrade database dự án. Không tính những mục này là PASS.
- NuGet đang báo NU1903 cho AutoMapper 12.0.1 sẵn có trong dự án. Chưa nâng major trong đợt sửa nghiệp vụ này; cần xử lý trước nghiệm thu bảo mật.

Lệnh kiểm tra code:

```powershell
dotnet test backend/ChoreWars.slnx --no-restore --verbosity minimal -m:1 -nodeReuse:false -p:UseSharedCompilation=false
Set-Location mobile
flutter test --no-pub
dart analyze lib test
```

Khi Docker Desktop engine đã chạy, tại root dùng:

```powershell
./backend/scripts/test-non-ai.ps1
```

Script tạo container PostgreSQL tên ngẫu nhiên, bind loopback/cổng tự động, mỗi test tạo DB `cw_test_<guid>`, rồi tự dọn container và khôi phục biến môi trường. Không dùng database thật của dự án. Không sửa test thành PASS khi PostgreSQL không chạy.

## Migration và dữ liệu cũ

Hai migration mới được gom theo dependency thực tế thay cho nhiều tên migration dự kiến trong plan: `20261018175315_CompleteNonAiCore` và `20261018180128_AddNonAiIntegrityGuards`. Không sửa các migration lịch sử của baseline.

Trước khi áp dụng lên database có dữ liệu: sao lưu và chạy SQL read-only `backend/scripts/non-ai-migration-preflight.sql`. Các bản ghi ledger/bồi thường/rank/achievement/bounty trùng phải được quyết định xử lý trước khi thêm unique index; migration không tự xóa dữ liệu lịch sử. Snapshot Karma = 0 cũ không được suy diễn từ template hiện tại. Các cột snapshot effort cũ dùng fallback đọc tương thích; episode trách nhiệm được dựng khi xử lý legacy occurrence. Cần xác minh riêng dữ liệu deadline/UTC cũ và tập dữ liệu thực tế.

Mặc định cho chore cũ là deadline phút 1439, custom dates rỗng; chat cũ là TEXT; reward Enabled mặc định true. Có test upgrade cho deadline/custom dates nhưng chưa chạy lại được trong lượt này vì Docker.

## Còn phải xác nhận trước nghiệm thu

1. Chạy đủ 6 integration PostgreSQL qua script và sửa bất kỳ lỗi runtime thực tế nào phát hiện.
2. Chạy luồng 3–6 tài khoản trên thiết bị: tạo nhà → khai báo rảnh → routine → generate/manual → reject/approve → làm việc/bounty/quá hạn → payment confirmation → reward/pass → kết thúc mùa.
3. Kiểm thử thu hồi SignalR khi leave/kick, refresh failure khi đang upload, retry media sau response bị mất, logout/login tài khoản khác.
4. Chạy outbox/Kafka thực: crash trước/sau publish/commit, broker tạm ngừng, consumer restart và poison message. Hiện lỗi parse giữ offset để retry; chưa có giao diện vận hành cách ly poison event.
5. Chạy camera + micro + loa và native share trên Android thật. Có code không đồng nghĩa đã nghiệm thu ba ngoại vi.
6. Hoàn thiện bằng chứng mỗi người 3 giao diện: bảng 4 thành viên trong plan là đề xuất phân công, chưa có tên và xác nhận đóng góp thực tế.
7. Hỏi giảng viên hướng thanh toán trước khi tích hợp. Đăng nhập đã có code; tiêu chí dịch vụ thanh toán vẫn đang hoãn.
8. Deploy/HTTPS/APK release làm sau theo yêu cầu của người dùng; chưa cần cung cấp URL trong giai đoạn code.

## Kế hoạch chạy các mục còn lại

Năm nhóm runtime từ mục 1 đến 5 ở trên được triển khai theo [kế hoạch thực thi riêng](../plans/runtime-verification-execution-plan.vi.md), lập ngày 20/10/2026. Tài liệu này chưa thay đổi kết quả PASS/SKIP hiện có; chỉ bổ sung thứ tự thực hiện, test harness, thiết bị và evidence cần chuẩn bị.
