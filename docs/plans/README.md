# Tài liệu triển khai và nghiệm thu Chore Wars

- [CI/CD GitHub Actions → Render — cập nhật 28/10/2026](github-actions-render-cicd-plan.vi.md): PR checks, PostgreSQL/Kafka tạm, auto deploy đúng SHA, health/dependency/smoke gates, migration riêng, rollback và checklist chạy độc lập Docker local. Có inventory tình trạng cloud hiện tại, secret và manifest file; đang ở bước kế hoạch, chưa tạo workflow.

- [Chi tiết từng file CI/CD và health — 28/10/2026](github-actions-render-cicd-file-manifest.vi.md): tạo/sửa/có điều kiện, công việc cụ thể, input/output, caller/callee, test, thứ tự triển khai và các cấu hình GitHub/Render/Aiven phải làm ngoài source. Đây là phụ lục kế hoạch, chưa thực thi.

- [Mua đồ thiết yếu, supplier, nợ trực tiếp và AI nhắc mua — 27/10/2026](household-supplies-supplier-and-ai-plan.vi.md): hai luồng manual/AI, payOS trả supplier, nội bộ hoàn trực tiếp người ứng; không gom quỹ/bù trừ. Mục 13–18 có future feature ngân hàng cá nhân, kiến trúc, manifest file sửa/tạo và luồng gọi giữa file. Chưa triển khai.

- [Đồng bộ main trước khi triển khai AI — 20/10/2026](../reports/main-sync-2026-10-20.vi.md): quyết định hợp nhất urgent event, swap thủ công, season review, chat và kiểm thử hồi quy. Đọc cùng source hiện tại trước khi triển khai AI.

Nhóm 4 thành viên; yêu cầu môn tối thiểu 12 giao diện, dịch vụ thanh toán, đăng nhập, product hoàn chỉnh và 3 ngoại vi điện thoại.

- [UI/UX mở app và xác thực — Intro → Welcome → Login/Register](ui-ux-launch-auth-redesign-plan.vi.md): hướng thiết kế riêng cho Chore Wars từ ảnh tham khảo Locket, storyboard animation, luồng phiên/router, manifest file và nghiệm thu; đang ở bước kế hoạch, chưa sửa UI.

- Đặc tả AI triển khai theo mục 10.6: [Data & Metric](../ai/data-metric-specification.vi.md), [Learning Tasks](../ai/learning-task-specification.vi.md), [Demo & Evaluation](../ai/demo-evaluation-specification.vi.md). Trạng thái lock/nghiệm thu được ghi trong từng tài liệu.

- [Trạng thái triển khai AI và bằng chứng kiểm chứng — 22/10/2026](../reports/ai-implementation-status-2026-10-22.vi.md): source Python/C#/Flutter, kết quả demo/training và các phần chưa nghiệm thu. [Hướng dẫn chạy AI](../../ai-service/README.md). Các ghi chú “chưa code” trong mô tả kế hoạch lịch sử bên dưới không phải trạng thái triển khai hiện tại.

- [Kế hoạch hiện hành: 10 nhóm không-AI sau pull, hoãn tích hợp thanh toán](non-ai-10-groups-implementation-plan.vi.md): phạm vi đã chốt, payment tracking, baseline sau pull, kiến trúc, manifest file sửa/tạo, migration, kiểm thử và phân công 4 người ×3 màn. payOS/thủ quỹ/settlement đang hoãn để hỏi giảng viên.
- [Kế hoạch triển khai toàn bộ AI bằng Python](ai-python-full-implementation-plan.vi.md): **hiện hành, cập nhật 22/10/2026, đối chiếu source `0e55613`**. Ưu tiên P0 luồng hồ sơ–phân công–evaluation–dashboard, P1 thực nghiệm một Target trung thực, P2 adapter vẫn giữ phạm vi. Checkpoint readiness sau 3 tháng, validation 4–5, test 6–14; có label decision table, pilot/multi-seed, consent dẫn xuất, nguồn dữ liệu độc lập và Phần 10 Evaluation Metrics & Acceptance Criteria. Chưa chốt thuật toán cuối, không bắt buộc hai Random Forest; bounty không tăng quota, chưa timer/model thời lượng hoặc dự đoán người nhận bounty. Đây là kế hoạch, chưa phải code AI.
- [Evaluation Store và AI Evaluation Dashboard — trong plan AI hiện hành](ai-python-full-implementation-plan.vi.md): mục 3.10 lưu run/metrics/learning status, mục 3.3.2 snapshot atomic tại core bất kể Kafka đến chậm; mục 4.6–4.7 tách B0 greedy/S0 search/H1 history và phần lợi ích từng nguồn; mục 5.6 timeline/compare/examples. Quỹ thời gian còn khoảng 2 tuần theo mục 1.1, ngày nộp chính thức chờ xác nhận. Có owner-scoped API/manifest/test; đây là thiết kế, chưa triển khai.
- [Kế hoạch kiểm thử BE/FE từ đầu đến cuối, không gồm AI](non-ai-full-system-test-plan.vi.md): test matrix, fixture, kịch bản E2E, thanh toán/ngoại vi, bảng 12 màn và tiêu chí nghiệm thu.
- [Báo cáo khoảng cách yêu cầu không-AI](non-ai-requirements-gap-report.vi.md): đối chiếu yêu cầu môn/SRS/Business Rules với source, phân biệt có code, chưa thấy implementation và chưa test runtime.
- [Kế hoạch bổ sung cũ — chỉ tham khảo lịch sử](missing-requirements-implementation-plan.vi.md): QR chuyển tiền bounty/compensation, provider và xác minh giao dịch, Micro/Loa, các work package sửa nghiệp vụ và lộ trình cho 4 thành viên.

Các kế hoạch cũ được giữ để tham khảo lịch sử. Tài liệu kế hoạch/báo cáo kiểm tra tĩnh không phải bằng chứng đã chạy test và không được dùng thay biên bản PASS.

- [Báo cáo triển khai code và kiểm thử 20/10/2026](../reports/non-ai-implementation-progress-2026-10-20.vi.md): các thay đổi BE/FE thực tế, contract mới, migration, test PASS/SKIP và phần còn phải nghiệm thu. Chưa đóng gói APK/deploy.

- [Kế hoạch thực thi PostgreSQL, E2E đa tài khoản, SignalR/session/media, Kafka crash và Android thật](runtime-verification-execution-plan.vi.md): năm đợt A–E, manifest test/harness cần code, thứ tự chạy, tiêu chí PASS và bằng chứng. Dùng Flutter debug; chưa làm APK release/deploy hoặc payOS.

- [Biên bản kiểm chứng source non-AI mới nhất](../reports/non-ai-runtime-verification-2026-10-20.vi.md): 55 unit, 27 integration, 12 Flutter test PASS; gồm 6 PostgreSQL bắt buộc, 10 Kafka thật, hard crash/restart, journey 3/6 actor và UI quản trị lỗi theo owner. [Runbook chạy lại](../testing/runtime-execution-runbook.vi.md). Android thật/release/payOS vẫn hoãn theo scope người dùng.
# Tiến độ CI/CD

Workflow và scripts của kế hoạch GitHub Actions → Render đã có trong source. Cấu hình và các bước kích hoạt production nằm tại [CI/CD runbook](../../scripts/ci/README.md); CD chưa bật nếu chưa đặt `CD_ENABLED=true` cùng environment secrets/protection.
