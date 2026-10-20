# Tài liệu triển khai và nghiệm thu Chore Wars

Nhóm 4 thành viên; yêu cầu môn tối thiểu 12 giao diện, dịch vụ thanh toán, đăng nhập, product hoàn chỉnh và 3 ngoại vi điện thoại.

- [Kế hoạch hiện hành: 10 nhóm không-AI sau pull, hoãn tích hợp thanh toán](non-ai-10-groups-implementation-plan.vi.md): phạm vi đã chốt, payment tracking, baseline sau pull, kiến trúc, manifest file sửa/tạo, migration, kiểm thử và phân công 4 người ×3 màn. payOS/thủ quỹ/settlement đang hoãn để hỏi giảng viên.
- [Kế hoạch triển khai toàn bộ AI bằng Python](ai-python-full-implementation-plan.vi.md): kiến trúc source, model, train cho người mới, toàn bộ flow và giao tiếp giữa các file. Đây là bản AI hiện hành theo yêu cầu triển khai cả các phần future.
- [Kế hoạch kiểm thử BE/FE từ đầu đến cuối, không gồm AI](non-ai-full-system-test-plan.vi.md): test matrix, fixture, kịch bản E2E, thanh toán/ngoại vi, bảng 12 màn và tiêu chí nghiệm thu.
- [Báo cáo khoảng cách yêu cầu không-AI](non-ai-requirements-gap-report.vi.md): đối chiếu yêu cầu môn/SRS/Business Rules với source, phân biệt có code, chưa thấy implementation và chưa test runtime.
- [Kế hoạch bổ sung cũ — chỉ tham khảo lịch sử](missing-requirements-implementation-plan.vi.md): QR chuyển tiền bounty/compensation, provider và xác minh giao dịch, Micro/Loa, các work package sửa nghiệp vụ và lộ trình cho 4 thành viên.

Các kế hoạch cũ được giữ để tham khảo lịch sử. Tài liệu kế hoạch/báo cáo kiểm tra tĩnh không phải bằng chứng đã chạy test và không được dùng thay biên bản PASS.

- [Báo cáo triển khai code và kiểm thử 20/10/2026](../reports/non-ai-implementation-progress-2026-10-20.vi.md): các thay đổi BE/FE thực tế, contract mới, migration, test PASS/SKIP và phần còn phải nghiệm thu. Chưa đóng gói APK/deploy.

- [Kế hoạch thực thi PostgreSQL, E2E đa tài khoản, SignalR/session/media, Kafka crash và Android thật](runtime-verification-execution-plan.vi.md): năm đợt A–E, manifest test/harness cần code, thứ tự chạy, tiêu chí PASS và bằng chứng. Dùng Flutter debug; chưa làm APK release/deploy hoặc payOS.

- [Biên bản kiểm chứng source non-AI mới nhất](../reports/non-ai-runtime-verification-2026-10-20.vi.md): 55 unit, 27 integration, 12 Flutter test PASS; gồm 6 PostgreSQL bắt buộc, 10 Kafka thật, hard crash/restart, journey 3/6 actor và UI quản trị lỗi theo owner. [Runbook chạy lại](../testing/runtime-execution-runbook.vi.md). Android thật/release/payOS vẫn hoãn theo scope người dùng.
