# Shop: thêm mặt hàng và liên hệ người bán

Ngày: 28/10/2026. Giữ giao diện tiếng Anh và bộ core đã chốt.

## Hành vi

- Shop có nút `+ Add item` kể cả khi danh sách trống. Thành viên đang hoạt động nhập tên món (ví dụ gạo ST25), đơn vị bán, giá VND, tên liên hệ, điện thoại và email. Cần ít nhất điện thoại hoặc email. Lưu thật trên backend, riêng theo nhà; người bán không cần tài khoản hay quyền supplier.
- Luồng gọi: mở Shop → chọn liên hệ → `Call` → mở ứng dụng gọi bằng `tel:`. Người dùng xác nhận cuộc gọi. Máy tính không có ứng dụng phù hợp hiện hướng dẫn sao chép số. Không đánh dấu đơn đã gửi/đã trả tiền chỉ vì đã mở dialer.
- Luồng tin nhắn: mở Shop → `Message` → mở SMS bằng `sms:`. Người dùng nhập/xác nhận gửi trong ứng dụng nhắn tin. Không tuyên bố SMS đã gửi, không tự thu phí hay tự gửi nền. Có nút sao chép số khi thiết bị không hỗ trợ.
- Luồng đặt email hiện có: chọn số lượng → `Send order` → backend lưu đơn và queue email → worker gửi SMTP → lịch sử thể hiện kết quả thật → người đặt ghi nhận đã thanh toán. Liên hệ chỉ có số điện thoại vẫn lưu được nhưng không thể gửi email khi thiếu email.
- Call/SMS là liên hệ bên ngoài; ghi log đơn hàng/thanh toán chỉ theo luồng Order, không tạo nợ tự động. SMS gửi tự động qua provider là tính năng tương lai, cần cấu hình và trạng thái giao nhận riêng.

## Kiến trúc và các file

1. `Supplier.cs`, `SupplierConfiguration.cs`: thêm HouseId nullable và OperatorUserId nullable; liên hệ do nhà thêm không gắn tài khoản người bán. Giữ supplier cũ có OperatorUserId. Migration EF mới cập nhật schema/index/FK, giữ dữ liệu cũ.
2. DTO/validator `CreateShopItemRequest`: kiểm tra tên, đơn vị, giá nguyên dương, email, số điện thoại; ClientRequestId chống tạo hai lần khi retry.
3. `ISupplyRepository`, `SupplyRepository`: query catalog công khai cũ tách khỏi query catalog theo nhà.
4. `ISupplyCatalogService`, `SupplyCatalogService`, `SupplierCatalogController`: GET catalog theo nhà và POST thêm món; kiểm tra membership, nhà writable và transaction qua mutation coordinator. Mặt hàng và liên hệ lưu cùng transaction.
5. `SimpleSupplyOrderService`, `SupplyOrderService`: chặn dùng liên hệ của nhà khác để tạo đơn. Products endpoint kiểm tra membership với liên hệ riêng. `AIHousekeeperService` chỉ dùng catalog công khai + catalog đúng nhà.
6. `supplies_providers.dart`: provider catalog theo houseId. `orders_screen.dart`: dấu cộng, empty state có hành động, cập nhật danh sách khi lưu. Dialog mới `shop_item_dialog.dart` nhập và lưu, giữ nội dung khi lỗi.
7. `supplier_contact_card.dart`: Call / Message / Copy number / email; tiếp tục dùng `supplyLaunch` để bắt trường hợp không có ứng dụng mở link.

Luồng dữ liệu: Shop → dialog → repository.mutate → controller → service → validator/access/coordinator → repository → PostgreSQL → response → invalidate provider theo nhà → Shop. Gọi/SMS: contact card → supplyLaunch → hệ điều hành → người dùng xác nhận. Đặt email: Shop → orders/send → SimpleSupplyOrderService → email dispatch → worker → SMTP → Orders.

## Kiểm thử và triển khai

- Regression login: màn nhỏ, báo lỗi dài, validation, text scale và kích thước nút Google thay đổi không tràn.
- Shop: lưu và retry không tạo trùng; thiếu liên hệ/giá sai bị từ chối; thành viên khác nhà không đọc sản phẩm hoặc đặt bằng ID đoán; nhà archive không thêm được.
- UI: danh sách trống vẫn thêm được; request lỗi giữ form; lưu thành công cập nhật đúng nhà; Call/SMS không tự gửi hoặc tạo log thanh toán.
- Build/analyze/test trước khi commit. Migration chỉ chạy trên DB test dùng riêng để kiểm thử; cloud cần chạy migration theo quy trình deploy đã có, không tự sửa schema production từ UI.

## Các sửa chữa đi kèm đã được yêu cầu

- `login_screen.dart`: bỏ IntrinsicHeight/Spacer làm chiều cao form cố định khi Google iframe resize; dùng nội dung cuộn được và giới hạn chiều rộng phần tên app để không tràn khi tăng cỡ chữ.
- `run-web.ps1`: giữ port 7357, mặc định để Flutter quản lý Chrome; chế độ NoBrowser dùng SSE. Bỏ job mở Chrome độc lập và query cwStart.
- `household_calendar.dart`, `house_calendar_providers.dart`: luôn vẽ lịch 7 cột/42 ô ngày, kể cả khi đang tải hoặc server thiếu endpoint; chỉ gắn công việc/ảnh khi có dữ liệu thật. Lỗi hiện hướng dẫn thử lại, không tự retry vô hạn. Bấm ngày xem phân công; hai ảnh xem trước và +N tiếp tục dùng dữ liệu evidence thật.
- `app_router.dart`, `house_shell.dart`: tab Chat đi thẳng `/chat/everyone`, URL `/chat` cũ redirect; bỏ `chat_home_screen.dart`. Giữ `/chat/assistant` cho nút AI và notification. `chat_room_screen.dart` quay về Overview, có retry khi chưa tải được phòng chat.
- Test thêm/sửa: `login_layout_test.dart`, `shop_item_test.dart`, `household_calendar_test.dart`, `house_navigation_test.dart`, `house_scope_test.dart`, `supplies_flow_test.dart`; backend `ShopItemValidationTests.cs`, `HouseShopTests.cs`.

Migration sinh ra: `20261028112536_AddHouseholdShopContacts` (kèm Designer và AppDbContextModelSnapshot). Triển khai backend và migration trước khi chạy FE mới trên cloud. Tại thời điểm kiểm tra 28/10, backend Render trả Healthy và CORS chấp nhận localhost:7357 nhưng POST `/api/auth/google` trả 404; đây chưa phải bằng chứng đăng nhập Google đã chạy được trên bản deploy.
