# Kiểm chứng Shop, lịch, đăng nhập và Chat — 28/10/2026

Phạm vi: nút thêm món/liên hệ riêng theo nhà; gọi/SMS qua ứng dụng thiết bị; giữ Order email/ghi log thanh toán; lịch luôn hiện lưới ngày; sửa overflow login; bỏ màn chọn Chat/AI; launcher cố định 7357 dùng Chrome do Flutter quản lý.

## Kết quả đã chạy

| Kiểm tra | Kết quả | Bằng chứng local (ignored) |
|---|---|---|
| Backend unit | 119 PASS, 0 skip | artifacts/ci/shop-unit.trx |
| PostgreSQL integration cho Shop và Order/Calendar | 6 PASS, 0 skip | artifacts/ci/shop-integration.trx |
| Chạy lại 2 test Shop, bổ sung nhiều liên hệ/cùng user và nhà archive | 2 PASS, là subset của nhóm trên | artifacts/ci/shop-private-catalog.trx |
| Toàn bộ Flutter sau sửa | 113 PASS | artifacts/ci/shop-accepted-flutter-tests.log |
| flutter analyze lib test | No issues found | artifacts/ci/shop-accepted-analyze.log |
| Web release build (mã cuối) | PASS, build/fixes-review | artifacts/ci/shop-accepted-web-build.log |
| EF pending model changes | Không có model change chưa tạo migration | artifacts/ci/shop-model-check.log |
| Source credential policy, git diff whitespace | PASS | scripts/ci/source_policy.py, git diff --check |

Build release được chạy vào thư mục riêng `mobile/build/fixes-review`, không thay thế output debug đang chạy. Các ảnh `artifacts/supplies/visual` là ảnh widget test với fixture minh họa; dữ liệu này không được đưa vào catalog production.

Test bao gồm lỗi mạng giữ nguyên form và request ID; giá/liên hệ sai; cross-house catalog/read/send bị chặn; email chưa cấu hình không tạo đơn giả; nhiều liên hệ không cần operator account; nhà archive không ghi được; grid loading/error không báo giả là hết việc; preview 0/1/2/3/5 ảnh; validation/login lỗi mạng ở màn nhỏ và text scale 1.3; tab Chat/deep link/một bottom bar; điều hướng sau lỗi tải phòng chat không bị snackbar cũ che nút.

## Điều chưa nghiệm thu trên production

- Render `/health/ready`: 200 Healthy; OPTIONS `/api/auth/google` chấp nhận origin localhost:7357. POST với token giả trả 404; `/health/version` trả SHA `987ba3fd3845165f30bd4888e4efa7fd7ae60854`. Đây là bản backend cũ, chưa có endpoint Google mới. Không suy diễn CORS 204 thành endpoint đã tồn tại.
- Chưa thử đăng nhập tài khoản Google thật, chưa gửi email/SMS hoặc gọi điện thật trong lượt kiểm thử này. Call/SMS chỉ mở ứng dụng ngoài, không xác nhận giao nhận tự động.
- Migration `20261028112536_AddHouseholdShopContacts` đã chạy trên DB PostgreSQL test dùng riêng. Chưa chạy migration này trên Render hoặc DB ứng dụng của người dùng. Container test đã được dọn; các container ứng dụng không bị sửa.
- Cần deploy backend mới và áp dụng migration qua quy trình deploy trước khi FE mới dùng catalog trên cloud. Không commit file env/khóa.
- Cảnh báo NuGet AutoMapper 12.0.1 có từ trước, đang thuộc ngoại lệ đã ghi trong deploy/security-exceptions.json; lượt này không nâng cấp thư viện đó.

[Kế hoạch và manifest file](../plans/shop-items-contact-flows.vi.md).
