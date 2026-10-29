# Nghiệm thu local: tài chính cá nhân và Household Summary

Ngày: 29/10/2026. Phạm vi: kế hoạch `docs/plans/account-payments-debts-household-summary.vi.md`.

## Thay đổi đã triển khai

- My Account có Payment History, bỏ shortcut Notifications; Household Chores mở thẳng Mine. Bounty còn Available, Posted by Me và Accepted by Me; các link payment cũ redirect sang lịch sử cá nhân.
- My Debts gom các nghĩa vụ tiền cá nhân trong nhà: tôi nợ ai, ai nợ tôi; hỗ trợ báo đã trả, chờ xác nhận, xác nhận/từ chối và ghi nhận nhận tiền trực tiếp. Hỗ trợ trả từng phần; retry cùng request không ghi trùng. Không tự bù trừ/chuyển nợ hoặc tự sinh nợ từ đơn hàng đơn giản.
- Payment History gộp thanh toán đơn hàng và trả nợ, lọc tháng/chiều tiền, phân trang. Báo đang chờ không được cộng vào tổng tiền đã xác nhận. Lịch sử cũ không có dòng transfer vẫn được giữ và không bị cộng hai lần.
- Household Summary có Schedule, Spending & Payments, Chore Completion, Member Contributions; giữ thao tác duyệt/phân công/xuất bản lịch. Bỏ Assigned Karma Gap khỏi UI.
- Chi tiêu ngoài nhà và hoàn tiền nội bộ được thống kê riêng. Tỷ lệ hoàn thành chỉ lấy lịch đã xuất bản; bản ghi cũ thiếu người hoàn thành hoặc thời điểm hoàn thành được hiển thị thiếu dữ liệu, không tự suy ra.
- Phần Shop thêm món, liên hệ Call/Message và luồng email giữ từ commit 41bbe18. Không thêm tài khoản supplier bắt buộc hoặc dữ liệu hàng hóa mẫu.

## Kiến trúc và dữ liệu

- `PersonalFinanceReadRepository` query theo nhà và actor, lấy repayments/adjustments theo lô. `PersonalFinanceService` tạo projection lịch sử và nợ; `HouseholdSummaryService` tổng hợp dữ liệu nhà.
- UI đi qua các provider riêng; thay đổi nợ làm mới debts/history/summary. Chi tiết nợ được kiểm tra houseId ở backend, kể cả khi một người thuộc cả hai nhà.
- Migration mới: `20261028121143_AddRepaymentReceiptProvenance`. Thêm nguồn và người ghi nhận; backfill báo trả nợ cũ bằng debtor thực tế, không giả mạo người nhận. Đã kiểm tra schema mới và nâng cấp dữ liệu cũ bằng PostgreSQL test riêng.
- Các script CLI `mobile/fix_imports.dart`, `mobile/update_errors.dart` dùng stdout cho log để analyzer toàn thư mục không báo avoid_print.

## Kiểm chứng

Kết quả cuối (log máy trong `artifacts/ci/finance-*`, không commit artifact và cấu hình riêng):

| Kiểm tra | Kết quả |
|---|---|
| Backend unit, toàn bộ | 122 passed, 0 skipped |
| Backend integration, toàn bộ | 88 test duy nhất đều passed qua hai lượt: lượt PostgreSQL 74 passed/14 skipped; lượt fixture AI + Kafka 15 passed/0 skipped, phủ đủ cả 14 test bị skip ở lượt đầu và một test trùng |
| Flutter, toàn bộ | 118 passed |
| Flutter analyzer, toàn thư mục mobile | No issues found |
| Flutter web release | Built `mobile/build/finance-review`, có cấu hình Google public trong `config/google.json` |
| Python AI | 84 test duy nhất passed: 82 ở suite chính, Kafka worker và allocator parity chạy bổ sung; parity dùng bản xuất synthetic AIDemo có sẵn |
| CI/deployment gates Python | 11 passed, gồm schema gate trên DB test |
| EF model/migration | Không có thay đổi model chưa có migration |
| Source policy, quét giá trị khóa riêng, diff whitespace/encoding | Passed |

Lượt integration song song đầu có timeout đọc PostgreSQL ở test mô phỏng crash. Đã dừng lượt đó và chạy lại một luồng (`-- xUnit.MaxParallelThreads=1`); toàn bộ test sau cùng đều đạt. Không bỏ test, nới assertion hay thay timeout trong source để che lỗi. Fixture PostgreSQL/Kafka và HTTP AI đều local, tách khỏi dữ liệu ứng dụng; AI fixture thay ranh giới gọi Gemini trả phí, vẫn đi qua logic và lưu trữ thật.

Lệnh chính: `dotnet test backend/ChoreWars.slnx --no-restore`, sau đó integration một luồng và lượt AI/Kafka riêng; `flutter test --reporter expanded`; `flutter analyze`; `flutter build web --release --dart-define-from-file=config/google.json --output=build/finance-review`; `pytest` cho AI và `scripts/ci/tests`. Phải có các biến fixture local như trong CI khi chạy runtime tests; không trỏ các biến test vào cloud.

Các tình huống đã bổ sung test: phân quyền debtor/creditor/outsider; một người thuộc hai nhà; partial payment; retry và hai thao tác đồng thời; từ chối không giảm nợ; compensation chỉ nhận sau khi hoàn thành; backfill migration; không cộng tiền nội bộ vào chi ngoài; draft schedule bị loại; bản ghi thiếu tác giả/thời gian; shortcut Mine; màn hình nhỏ và trạng thái rỗng/lỗi.

## Giới hạn triển khai

Chưa ghi schema hoặc dữ liệu vào Render trong lượt này. Cần backup và áp dụng migration backend trước khi cho FE mới dùng các cột mới; push Git không xác nhận deploy thành công. SMTP, SMS, gọi điện, Google OAuth và payOS thật cần nghiệm thu riêng với cấu hình cloud/thiết bị thật; các test tự động không phát sinh thanh toán hay gửi email thật.

Backend còn cảnh báo dependency AutoMapper 12.0.1 NU1903 đã tồn tại, có ngoại lệ theo `deploy/security-exceptions.json`; lượt này không thay version dependency đó.
