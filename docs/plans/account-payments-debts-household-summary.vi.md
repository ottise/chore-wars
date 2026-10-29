# Kế hoạch: Shop, Payment History, My Debts và Household Summary

Ngày lập: 28/10/2026. Cập nhật: 29/10/2026. Trạng thái: đã triển khai source và kiểm thử local; chưa áp dụng migration mới hoặc nghiệm thu trên Render. Phần Shop đã có source ở commit 41bbe18; không coi việc push source là đã nghiệm thu cloud.

## 1. Phạm vi và điều hướng được hiểu

Giữ Order ở bottom navigation. My Account tập trung dữ liệu cá nhân; trang tổng hợp trong nhà chỉ chứa dữ liệu của nhà đang chọn. Không trộn thông báo, nợ hoặc giao dịch hai nhà.

| Điểm vào | Đích sau thay đổi |
|---|---|
| Order → Shop → dấu + | Thêm mặt hàng, đơn vị bán, giá, tên liên hệ, điện thoại/email |
| My Account → Payment History | Lịch sử giao dịch tiền của chính tôi trong nhà đang chọn |
| My Account → My Debts | Hai nhóm: tôi chưa trả ai / ai chưa trả tôi |
| My Account → My Notifications | Bỏ mục này; chuông header tiếp tục hoạt động |
| My Account → Household Chores | Vào /houses/:houseId/chores?tab=mine |
| Bounty | Chỉ giữ khám phá/đăng/nhận/xem bounty; bỏ Payments và History riêng ở đây |
| Review Schedule | Mở rộng thành Household Summary với bốn mục; vẫn giữ xác nhận lịch trong mục Schedule |

Không xóa dữ liệu giao dịch, không xóa màn hình thông báo hay chức năng chuông. Link thanh toán cũ cần redirect sang vị trí mới thay vì trả lỗi. Chi tiết bounty có thể dẫn tới khoản nợ/giao dịch tương ứng nhưng không duy trì thêm một lịch sử trùng lặp.

## 2. Shop và hai luồng liên hệ

Phần đã có code: dấu +, form thêm món/liên hệ theo nhà, lưu backend, Call, Message, Send order bằng email. Danh bạ này không yêu cầu người bán có tài khoản supplier. Giữ triển khai và test đã có, hoàn tất triển khai backend/migration khi đưa lên cloud.

Ví dụ dữ liệu người dùng tự nhập: tên gạo ST25, đơn vị túi 5 kg, giá VND, tên cửa hàng, số điện thoại, email. Không seed ví dụ thành hàng thật.

1. Call: Shop → Call → tel: → ứng dụng gọi của thiết bị → người dùng tự xác nhận gọi. Máy tính thiếu ứng dụng thì cho sao chép số. Không tự ghi đơn đã gửi hay đã trả.
2. Message: Shop → Message → sms: → ứng dụng nhắn tin → người dùng tự nhập/xác nhận gửi. Không tuyên bố SMS đã gửi chỉ vì đã mở ứng dụng. SMS gửi tự động qua nhà cung cấp dịch vụ là tương lai.
3. Luồng đặt email vẫn giữ: chọn số lượng → Send order → backend lưu đơn/queue email → worker gửi SMTP → Orders hiển thị trạng thái thật → người đặt ghi nhận thanh toán. Email liên hệ là bắt buộc cho luồng email; không bắt buộc nếu chỉ lưu số để gọi/SMS.

Chi tiết file/API/migration: [kế hoạch Shop đã ghi](shop-items-contact-flows.vi.md).

## 3. Payment History trong My Account

Đây là lịch sử, không phải trang xác nhận nợ. My Debts chứa các hành động báo đã trả/nhận tiền; Payment History phản ánh kết quả và cho mở chi tiết nguồn.

- Tiêu đề Payment History. Lọc All / Money in / Money out và khoảng thời gian. Mỗi dòng có loại giao dịch, số tiền VND, ngày giờ, người trả/người nhận hoặc cửa hàng, nguồn Order/Bounty/Debt/Compensation, trạng thái và link chi tiết.
- Chỉ lấy giao dịch liên quan trực tiếp đến người đăng nhập trong nhà đang chọn.
- Bao gồm khoản trả cửa hàng do tôi ghi nhận, khoản tôi chuyển cho thành viên, khoản thành viên trả tôi, tiền bounty/bồi hoàn đã xác nhận.
- Báo đã trả nhưng chưa được người nhận xác nhận phải hiển thị Pending confirmation; không cộng vào tổng đã thu/đã trả đã xác nhận.
- Phân biệt nguồn xác nhận: tự ghi nhận trả cửa hàng, người nhận xác nhận, hoặc provider xác nhận nếu có dữ liệu thật. Không gắn nhãn ngân hàng đã xác minh cho thao tác người dùng tự báo.
- Karma không phải tiền, không đưa vào lịch sử này.
- Dùng khóa nguồn ổn định (loại nguồn + ID giao dịch nguồn). Không tạo thêm giao dịch chỉ vì cùng khoản tiền xuất hiện ở Order, My Debts và Bounty.
- Dữ liệu cũ đã settled được đọc theo nguồn cũ, không sửa ngày trả hoặc tự sinh giao dịch ngược để chuyển màn hình.

Tái sử dụng payment provider/entity đang có và order payment log. Bổ sung backend read model để merge, lọc, phân trang; không tải toàn bộ mọi nhà rồi lọc trên FE.

## 4. My Debts: hai chiều và xác nhận đúng vai trò

### Tôi còn phải trả — I owe

- Mỗi khoản hiển thị người nhận, nguồn phát sinh, tiền gốc, đã xác nhận trả và còn lại; trạng thái rõ ràng.
- Nút Mark as paid mở form số tiền đã chuyển, tham chiếu/ghi chú tùy chọn. Sau khi lưu chuyển sang Awaiting confirmation và báo cho người nhận.
- Người trả không tự đóng nợ bằng một lần bấm. Chỉ tiền đã được người nhận xác nhận mới giảm số dư nợ chính thức. Có thể trả từng phần.

### Người khác còn phải trả tôi — Owed to me

- Hiển thị người nợ, tiền còn lại và các lần chuyển đang chờ xác nhận.
- Nút Confirm received để xác nhận số tiền thực nhận. Nếu đã có báo chuyển thì xác nhận đúng báo chuyển đó; Reject/Not received giữ nguyên nợ và lưu lý do.
- Nếu nhận tiền ngoài đời nhưng bên trả chưa báo trên app: người nhận được Record receipt với số tiền thực nhận. Backend ghi rõ đây là người nhận tự ghi nhận, không giả làm báo chuyển của người trả. Nếu có báo chuyển đang chờ khớp khoản tiền, ưu tiên xử lý báo đó và không ghi nhận hai lần.
- Chỉ creditor được xác nhận nhận, chỉ debtor được báo chuyển. Người ngoài hai bên không được thao tác.

### Quy tắc chung

- Nguồn nợ gồm mua chung có chia nợ, bounty, bồi hoàn và các nghĩa vụ tiền thực tế đã có. Hiện endpoint purchase-debt chỉ hỗ trợ HOUSEHOLD_PURCHASE; phải tạo projection tổng quát thay vì chỉ đổi nhãn FE.
- Không tự chuyển nợ A→B→C, không tự bù trừ hai chiều. Không tự sinh nợ từ Order mới khi chưa có quyết định chia tiền/ghi nợ.
- Lock theo nhà, kiểm tra số dư hiện tại, request ID idempotent; tổng nhận không vượt phần còn lại. Retry/nhấn đúp không ghi tiền hai lần.
- Khoản đã trả đủ chuyển Settled, có trong Payment History; My Debts mặc định ưu tiên khoản còn mở.
- Có nguồn phát sinh, người ghi nhận, thời gian báo/chốt và trạng thái để kiểm tra lại được.

## 5. Review Schedule → Household Summary, bốn mục

Theo yêu cầu cùng trang, đề xuất đổi tên trang thành Household Summary và chia bốn mục/tab. Giữ URL review cũ tương thích và chức năng xem/xác nhận lịch bên trong Schedule; không bỏ bước duyệt lịch của mùa.

| Mục | Nội dung | Ý nghĩa |
|---|---|---|
| Schedule | Lịch phân công, người làm, giờ/ngày, việc chưa được gán, trạng thái duyệt; nút xác nhận/xuất bản đúng quyền | Giữ nghiệp vụ Review Schedule hiện có |
| Spending & Payments | Chi mua ngoài nhà theo khoảng thời gian, đơn đã ghi thanh toán, người ứng tiền, đơn chưa trả; link chi tiết | Biết cả nhà đã chi gì và ai đứng ra trả |
| Chore Completion | Được giao, đã hoàn thành, đúng hạn, quá hạn, sắp đến hạn; tỷ lệ và số đếm gốc; bấm xem ngày/người/ảnh | Biết việc nhà đang được thực hiện thế nào |
| Member Contributions | Theo từng người: số việc được giao/đã làm, phút dự kiến được giao, việc còn lại và quá hạn | Thay Assigned Karma Gap bằng thông tin dễ hiểu |

Định nghĩa số liệu:

- Assigned Karma Gap cũ = max(tổng Karma được phân công của mỗi thành viên) − min(...). Đây chỉ là độ chênh tải theo điểm phân công, không phải tiền, điểm đã kiếm được hay một khoản nợ. Bỏ nhãn/card này khỏi UI; không xóa kiểm tra cân bằng hoặc cảnh báo lịch thực sự chưa hợp lệ trong backend.
- Phân biệt việc dự kiến và việc đã làm: phút dự kiến không được gọi là giờ làm thực tế; Karma được giao không được gọi là Karma đã kiếm.
- Completion rate = việc hoàn thành / các occurrence hợp lệ trong tập thời gian đã chọn. Hiển thị cả n/N. Không có việc thì ghi No chores yet, không tự hiển thị 100%.
- On-time rate dùng giờ hoàn thành so với deadline, hiển thị mẫu số là các việc đã hoàn thành có deadline; việc chưa xong và đã qua hạn đếm riêng.
- Chi tiêu cả nhà chỉ cộng tiền ra cửa hàng/chi bên ngoài có nguồn thực. B→A trả lại tiền A đã ứng là chuyển nội bộ, không cộng thêm lần nữa vào tổng chi cả nhà.
- Nếu tiền trả cửa hàng do người dùng tự ghi nhận, ghi rõ mức xác nhận; không coi là webhook ngân hàng.
- Chọn tháng/khoảng thời gian; Schedule và phân công có thể lọc thêm mùa. Không lẫn kế hoạch tương lai của mùa với kết quả thực hiện tháng hiện tại. Ngày nghiệp vụ theo Asia/Ho_Chi_Minh.
- Chỉ dữ liệu nhà đang chọn. Không đưa số tài khoản cá nhân/ghi chú riêng của thành viên khác vào báo cáo chung. Thiếu dữ liệu thì ghi chưa có, không mock biểu đồ.

## 6. Manifest và kiến trúc dự kiến

### Flutter — sửa

- `mobile/lib/features/auth/presentation/screens/profile_screen.dart`: thêm Payment History, bỏ My Notifications, Household Chores chuyển đúng tab mine.
- `mobile/lib/features/bounty/presentation/screens/bounty_board_screen.dart`: bỏ Payments/History và các handler chuyển sang màn cá nhân; giữ các tab bounty và link chi tiết khoản liên quan.
- `mobile/lib/features/payment/presentation/screens/payment_obligations_screen.dart`: tách trách nhiệm/redirect URL cũ, không duy trì thêm lịch sử và nút settle trùng.
- `mobile/lib/features/supplies/presentation/screens/household_debts_screen.dart`: lấy generic debt summary, nhóm hai chiều, nút hành động trực tiếp và link nguồn tùy loại.
- `mobile/lib/features/house/presentation/screens/review_schedule_screen.dart`: bỏ card Karma Gap, bố cục bốn mục và giữ chức năng review thật.
- `mobile/lib/core/router/app_router.dart`: route account/payments mới, tương thích deep link payments/history cũ.
- Providers/models/repositories payment và supplies hiện có: thêm invalidation history/debt summary sau thao tác, khóa cache theo session + nhà.

### Flutter — tạo

- `features/payment/presentation/screens/payment_history_screen.dart`.
- `features/payment/presentation/providers/payment_history_provider.dart`.
- `features/payment/domain/entities/payment_history_entry.dart`.
- `features/supplies/presentation/widgets/debt_action_sheet.dart`: báo trả/xác nhận/ghi nhận nhận, giữ nội dung khi lỗi.
- `features/house/presentation/widgets/household_summary_sections.dart`.
- `features/house/presentation/providers/household_summary_provider.dart`.
- `features/house/domain/entities/household_summary.dart`.

### Backend — sửa

- `Application/Services/Supplies/InternalRepaymentService.cs`: tổng quát hóa xử lý trả nợ, giữ guard/idempotency/partial payment; tương thích purchase-debt cũ.
- `Presentation/Controllers/InternalRepaymentsController.cs`: expose endpoint tổng quát và creditor-recorded receipt, kiểm tra actor/house.
- `Application/Interfaces/Services/IInternalRepaymentService.cs` và DTO liên quan: thêm record receipt và projection generic; không bắt sourceOrderId khi nguồn là bounty/bồi hoàn.
- `Domain/Entities/InternalRepayment.cs`, configuration EF: ghi nguồn DEBTOR_REPORTED/CREDITOR_RECORDED và người ghi nhận, không gán sai tác giả lịch sử. Migration additive, backfill bản ghi cũ theo debtor thực tế khi có nguồn rõ ràng.
- Triển khai thực tế dùng `IPersonalFinanceReadRepository` và `PersonalFinanceReadRepository` mới: query theo nhà + actor, trạng thái, ngày; lấy transfers/adjustments theo lô, tránh N+1 khi merge lịch sử. Giữ các repository nghiệp vụ hiện có.
- `Presentation/Extensions/ApplicationServiceExtensions.cs`: đăng ký read services/validators mới.

### Backend — tạo

- `Application/DTOs/Payments/PaymentHistoryEntryResponse.cs`: lịch sử và tổng hợp nợ cá nhân. Tái sử dụng `PurchaseDebtResponse` với `SourceOrderId` nullable, `Reason`, `HouseId` để tương thích client cũ; tái sử dụng request/validator `ReportRepaymentRequest` cho ghi nhận nhận tiền, không tạo DTO trùng lặp.
- `Application/Interfaces/Services/IPersonalFinanceService.cs`, `Application/Services/PersonalFinanceService.cs`.
- `Presentation/Controllers/PersonalFinanceController.cs`: GET `/api/houses/{houseId}/me/payment-history`, GET `/api/houses/{houseId}/me/debts`. Actor lấy từ token, không nhận userId tùy ý.
- `Application/DTOs/House/HouseholdSummaryResponse.cs`, `Application/Interfaces/Services/IHouseholdSummaryService.cs`, `Application/Services/HouseholdSummaryService.cs`.
- `Presentation/Controllers/HouseholdSummaryController.cs`: GET `/api/houses/{houseId}/summary` với khoảng ngày/mùa, kiểm tra membership và giới hạn khoảng query.
- Migration EF `AddRepaymentReceiptProvenance` + Designer + snapshot, chỉ sinh và test ở giai đoạn triển khai. Không viết tay lại lịch sử đã thanh toán để đổi giao diện.

## 7. Luồng qua các file

1. My Account → router → PaymentHistoryScreen → provider → PersonalFinanceController → PersonalFinanceService → repository read models → history chuẩn hóa, phân trang.
2. My Debts → DebtActionSheet → repayment controller/service → validator + house/actor guard → mutation coordinator → obligation/report/audit → notification người đối diện → invalidate debts/history/house summary.
3. Household Summary → bốn tab → summary provider/controller/service → query orders/payment logs/repayments/occurrences → response chỉ dữ liệu thật của nhà.
4. Household Chores shortcut → `/chores?tab=mine` → cơ chế initialTab hiện có; không tạo thêm màn hình Mine thứ hai.

## 8. Trình tự triển khai và tiêu chí nghiệm thu

1. Chốt plan này; giữ phần Shop đã có, xác nhận trạng thái deploy/migration riêng.
2. Chỉnh My Account, bỏ shortcut Notifications, sửa Mine và các link cũ.
3. Làm backend finance projection + provenance + test, sau đó UI Payment History/My Debts. Chỉ bỏ tab payment ở Bounty khi vị trí mới đã đủ chức năng.
4. Làm summary backend và bốn mục trên Review Schedule; giữ duyệt lịch, tái phân công và chặn xác nhận lịch chưa hợp lệ.
5. Unit/integration trên DB test: phân quyền hai bên, nợ từng phần, double-click/retry, đồng thời báo và nhận, từ chối không giảm nợ, không trộn nhà, nguồn lịch sử không trùng.
6. Flutter: profile có Payment History và không còn Notifications; shortcut vào mine; Bounty không còn Payments/History; deep link cũ đúng đích; bốn mục summary tải/lỗi/trống được, màn nhỏ không tràn.
7. Ví dụ kiểm số: A trả cửa hàng 300.000, B hoàn A 100.000 → chi cả nhà vẫn 300.000; history A có tiền ra 300.000 và tiền vào 100.000; nợ B chỉ giảm 100.000 khi xác nhận nhận. Không tự suy ra B nợ bao nhiêu nếu chưa có nghĩa vụ chia tiền.
8. Chạy build/analyzer/tests, commit/push; deploy backend + migration trước FE cần schema mới. Nghiệm thu cloud không được suy từ test local hoặc chỉ thấy health xanh.
