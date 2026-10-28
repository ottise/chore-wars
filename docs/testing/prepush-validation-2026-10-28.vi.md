# Kiểm tra trước khi push — 28/10/2026

Phạm vi: Google sign-in/link, Order email và payment audit, lịch ảnh Overview, navigation Order/Bonus/My Debts, tài liệu test. Theo yêu cầu cuối, gỡ shortcut PowerShell và ép port 7357; `flutter run` trở lại Flutter SDK gốc, tự chọn device/port. Đây là biên bản automated/local, không phải nghiệm thu Google/SMTP/payOS thật trên Render.

## Kết quả local

| Kiểm tra | Kết quả | Evidence local (gitignored) |
|---|---|---|
| Backend unit Release | 118 passed, 0 skipped | artifacts/ci/prepush-unit-verified.trx |
| Backend integration PostgreSQL/Kafka/Python contract | 79 passed, 0 skipped | artifacts/ci/prepush-integration-verified.trx |
| Flutter analyzer lib/test | No issues | artifacts/ci/prepush-flutter-analyze.log |
| Flutter tests | 107 passed | artifacts/ci/prepush-flutter-test.log |
| Python AI trên Linux, PG/Kafka tạm | 84 passed, 0 skipped | artifacts/ci/prepush-ai.xml |
| CI gates/schema và parity baseline C# mới | 12 passed, 0 skipped | artifacts/ci/prepush-ci-parity-verified.xml |
| Web release (API/hub Render, Google Client ID) | Build thành công | artifacts/ci/prepush-web-build.log |
| Backend Docker Linux | Build thành công; không có appsettings.*.local.json | artifacts/ci/prepush-backend-docker.log |
| Migration manifest so với main trước thay đổi | Đạt; không đổi/xóa migration đã có | artifacts/ci/prepush-migration-manifest.json |
| Credential scan/diff whitespace | Đạt; không có giá trị secret local trong phần publish | scripts/ci/source_policy.py và kiểm tra local |
| PowerShell/VS Code sau gỡ port | Hai PowerShell mới resolve Flutter thành Application, JSON/parser hợp lệ, không web-port mặc định | Kiểm tra trực tiếp |

Các thay đổi cuối sau suite ứng dụng chỉ là cấu hình launch/helper và tài liệu; đã kiểm tra parser/JSON và command resolution. GitHub CI chạy lại trên SHA được push để xác nhận môi trường Linux và artifact release.

## Các lỗi phát hiện trong đợt kiểm tra

- Test worker shutdown có race do wait handle của caller token có thể thức trước khi cancellation truyền tới worker. Fixture nay gọi StopAsync để hủy worker trước khi giải phóng mock scope; giữ kiểm tra không log lỗi khi shutdown và vẫn log lỗi công việc thật. Không đổi business worker.
- Một lần Kafka publish timeout; retest đạt nhưng log lộ kết nối IPv6 localhost trong khi cổng Docker test chỉ bind IPv4. Đã đổi địa chỉ broker quảng bá và biến CI sang 127.0.0.1, sau đó chạy lại cả 79 integration test đạt. Không sửa assertion hoặc bỏ qua ca lỗi.
- Lượt kiểm tra CI gate ban đầu thiếu biến PostgreSQL nên một ca skipped; đã chạy lại với database tạm, toàn bộ 12 ca đạt.
- AutoMapper 12.0.1 vẫn có cảnh báo NU1903, được policy repo ghi nhận ngoại lệ tới 11/11/2026. Audit policy đạt với ngoại lệ này; không tuyên bố mọi thư viện không có advisory. Python có cảnh báo pytest cache do bind source read-only, không có test fail/skip.

## Database và deploy

Hai migration mới, theo thứ tự:

1. `20261028041556_AddSimpleOrderEmailAndPaymentLog`
2. `20261028051203_AddGoogleIdentity`

Đã thử trên DB tạm; chưa áp dụng vào Render trong đợt commit/push này. GitHub deploy workflow có schema gate và migration workflow được bảo vệ. Nếu Render còn bật Auto-Deploy On Commit trực tiếp thì cần bảo đảm schema được cập nhật theo runbook trước khi chuyển sang bản mới; việc push không chứng minh production đã migrate/healthy.

Backend Render cần GoogleAuth__Enabled và allowlist ClientIds; SMTP nhập qua Environment backend, không ở frontend. Không đưa file .env/appsettings local chứa mật khẩu lên Git. Hướng dẫn: [Google](../google-sign-in-setup.vi.md), [Order mail](../order-email-setup.vi.md), [CI/CD](../../scripts/ci/README.md).

Tài khoản Google thật, nhận email supplier thật, phần cứng camera/mic/loa trên thiết bị và chuyển tiền thật chưa được xác nhận bằng các mock/contract test trên. Bộ [95 test case và 5 kịch bản E2E](backend-frontend-e2e-test-cases.vi.md) vẫn có trạng thái thực thi riêng, không tự đổi toàn bộ thành PASS vì suite tự động đạt.
