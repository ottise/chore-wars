# Runbook kiểm thử source non-AI

Cập nhật 20/10/2026 theo xác nhận người dùng: chỉ test source/API/PostgreSQL/Kafka/widget; chưa cắm Android, chưa nghiệm thu thiết bị hoặc đóng APK release. Quyền quản trị lỗi thuộc chủ nhà, không phải quản trị hệ thống chung.

## Chạy bộ test

Tại root repo, Docker Desktop engine phải sẵn sàng:

```powershell
docker info
./backend/scripts/test-non-ai.ps1
./backend/scripts/test-runtime.ps1
```

`test-non-ai.ps1` tạo PostgreSQL 16 riêng trên loopback/cổng ngẫu nhiên; từng test dùng database `cw_test_<guid>`. Script kiểm tra đủ sáu test bắt buộc thực sự Passed, không chỉ exit code. Lưu UnitTests.trx/IntegrationTests.trx, manifest và postgres.log trước khi dọn container.

`test-runtime.ps1` bổ sung broker Kafka riêng, topic prefix/group riêng cho từng case. Nó chạy cả suite PostgreSQL và yêu cầu các ca RealKafkaTests phải Passed. WorkerTestHost là executable chỉ phục vụ test, có dependency build từ IntegrationTests, không mở HTTP endpoint. Process harness lấy ACK tại fault boundary, kill đúng process nó tạo và khởi động worker mới để kiểm tra recovery.

Chỉ broker có tên `cw-runtime-kafka-<guid>` do runner tạo được pause/unpause ở outage test. Runner không stop/drop/upgrade container hoặc database dự án đang chạy. Nếu test bị dừng cứng ngoài finally, kiểm tra tên/container/run ID trước khi dọn tài nguyên dư; không dùng lệnh xóa Docker toàn máy.

Flutter:

```powershell
Set-Location mobile
flutter test --no-pub
dart analyze lib test
```

## Quản trị message lỗi

- Mở nhà → House settings → Xử lý hệ thống. Chỉ owner ACTIVE nhìn thấy action; API kiểm tra lại quyền, không dựa vào UI.
- Danh sách phân trang 20 dòng, lọc Cần xử lý/Đã yêu cầu thử lại/Đã khôi phục.
- Sau bốn lần xử lý không thành công, consumer lưu payload đầy đủ vào PostgreSQL trong transaction riêng rồi mới commit offset Kafka. Nếu không lưu được thì seek/retry; không commit vượt message chưa lưu.
- HouseId của lỗi phải được đối chiếu với occurrence/bounty/season thật trong database và HouseId khai báo. Không chỉ tin HouseId trong JSON. Message parse hỏng hoặc không xác minh được nhà bị giữ ở backend với HouseId null, không xuất hiện trong danh sách chủ nhà.
- Response cho owner không chứa raw payload, access token hoặc exception stack. ErrorCode là tên loại lỗi; log chẩn đoán giữ ở backend.
- Thử xử lý lại tạo outbox mới, giữ nguyên message key, payload gốc và một audit actor/time/outbox. Retry cùng thao tác khi trạng thái đã queued không tạo outbox/audit thứ hai. Không cho sửa raw payload hoặc đánh resolved bằng tay.
- Chỉ khi business transaction + dedup thành công thì trạng thái chuyển RESOLVED. Nếu còn lỗi sẽ quay về FAILED; số vòng thất bại tăng. Nhà archive chỉ được xem, không replay.
- Quarantine là dữ liệu vận hành backend, không phải nghĩa vụ công việc hoặc khoản nợ mới. Replay không có nghĩa người dùng cần làm việc hoặc xác nhận tiền lại.

## Phạm vi bằng chứng

Tách kết quả: unit/widget, PostgreSQL/HTTP, SignalR protocol qua test server, real Kafka broker, hard process kill, service journey 3/6 tài khoản. Journey ở tầng service dùng PostgreSQL thật và clock fixture, không phải video UI trên điện thoại.

Camera/micro/loa/native share chỉ có code/widget trong lượt này. Không ghi PASS phần ngoại vi thực tế nếu chưa chạy trên Android thật. Kết quả từng run và lỗi sửa phải ghi trong báo cáo, liên kết đến TRX dưới `artifacts/runtime/<run-id>/`. Artifacts được gitignore để tránh commit log/media/token ngoài ý muốn.

## Cập nhật bộ test source đang thực thi

Suite đã bổ sung source journey 3/6 tài khoản với TimeProvider riêng, pass có/không có replacement, frozen season ledger, quyền claim của thành viên LEFT/BANNED, số dư qua mùa và metric thành tích. Có consumer thật cho bounty.accepted; contract này không mang HouseId nên scope được suy ra từ bounty và kiểm chứng bằng episode của người nhận.

Manifest debug Android cho phép HTTP local chỉ ở build variant debug, phù hợp URL phát triển 10.0.2.2/LAN. Main/release manifest không được nới cleartext trong thay đổi này. Chưa chạy APK/device theo scope source-only hiện tại.

Dữ liệu thành tích mặc định: một việc hoàn thành, 100 Karma kiếm được trong nhà, ba ngày hoàn thành liên tiếp theo lịch Vietnam và một bounty accepted. Streak là chuỗi dài nhất từng đạt, giữ badge đã unlock. Không tính Karma hoặc completion của nhà khác để đạt badge trong nhà hiện tại.
