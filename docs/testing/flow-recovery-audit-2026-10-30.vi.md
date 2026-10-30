# Rà soát supplier, AI, thống kê và media — 30/10/2026

## Lỗi xác định được và bản sửa

- Log `avatar-image`/`media` 404 là endpoint có tồn tại nhưng không còn file trên ổ tạm. Tại lúc kiểm tra cloud, backend vẫn báo SHA `3da2290`, chưa chạy bản avatar `3fcae63`. Không quy lỗi mất file thành API chưa nối.
- Ảnh chat, voice và bằng chứng chuyển sang bảng `PrivateMediaFiles` (bytea). Quyền đọc vẫn được kiểm tra trong MediaService/EvidenceService trước khi truy cập storage. Storage tham gia transaction hiện tại, không tự flush các entity khác; đọc file cũ còn tồn tại vẫn được hỗ trợ. Xóa file đã mất là idempotent.
- Media 404 dừng retry tự động; cache theo phiên trong 5 phút, đổi tài khoản làm mất cache. Người dùng vẫn có thể retry chủ động. Ảnh calendar cũng không retry tự động trên lỗi.
- Polling chi tiết đơn trước đây khởi động lại mỗi 15 giây ngay cả khi request cũ chưa xong. Nay chỉ đặt lịch tải lại sau thành công; đơn SMS không polling. Supplier/order providers hiển thị lỗi và retry chủ động thay vì tự lặp lại lỗi phân quyền/404.
- My Houses và page bar giới hạn cụm action theo bề ngang, tiêu đề có ellipsis. Household Summary có retry ở tab Schedule và nút refresh cập nhật cả dữ liệu summary.
- Tăng thời gian chờ HTTP để chịu được khởi động lạnh: mobile nhận phản hồi tối đa 90 giây; AI tối đa 110 giây; backend→AI mặc định 90 giây. Không retry tự động mutation.
- Kết quả nhận giọng nói cuối cùng trong Assistant được gửi sang interpret, có khóa chống gửi trùng khi đang xử lý; không chỉ dừng ở điền ô nhập. Lỗi transport/timeout AI được đổi thành thông báo có thể đọc, giữ draft và nút Retry. Backend không đưa lỗi provider/raw exception vào nội dung UI.

## Shop và thanh toán

Shop có 4 mẫu điền nhanh: Gas, Rice, Fish sauce, Salt. Giá khởi đầu lần lượt 400.000/160.000/40.000/10.000 VND theo đơn vị hiển thị. Đây là **giá gợi ý có thể sửa**, không phải giá nhà cung cấp xác nhận; mẫu chưa lưu không xuất hiện như sản phẩm thật trong catalog/AI. Người dùng thêm số điện thoại trước khi lưu, có thể sửa tên, đơn vị, giá và liên hệ. Nút Add item tự nhập vẫn giữ.

Hai lựa chọn: Save & open SMS (lưu đơn rồi mở bản nháp SMS để người dùng gửi) và Save & record payment (lưu đơn trước, mở xác nhận số tiền đã trả, ghi log riêng). Hủy hoặc lỗi ghi nhận thanh toán không xóa đơn đã lưu. Call/Message mở ứng dụng thiết bị; ghi nhận tiền không phải kết quả xác minh ngân hàng.

## Đối chiếu và kiểm thử

- Inventory tĩnh: 222 khai báo route backend, 95 mẫu call/endpoint literal FE. Năm mẫu động phải đọc riêng: AI get/post/put, action quản trị nhà và ảnh evidence/thumbnail. Các đường gọi này có route tương ứng. Không coi mọi endpoint quản trị/legacy là tính năng cần thêm vào UI.
- Test Kestrel→Flutter thật đã qua: auth, hai thành viên/hai nhà, supplier/mặt hàng, orders, debts, payments, summary/calendar, upload/download và SignalR. Không dùng mock Dio trong bài mạng.
- Backend: 128 unit đạt; 84 integration đạt, 14 bài cần môi trường worker/Kafka riêng bỏ qua. Bài mạng Flutter chạy riêng đạt. Test mới kiểm tra byte media vẫn đọc được ở context mới không có thư mục file, rollback không để lại blob và xóa không lỗi khi thư mục cũ đã mất.
- Flutter: 135 test đạt; 1 bài live-network skip trong lượt regression, đã chạy riêng bằng fixture Kestrel. Có test 320/354/480 px với text scale 1,3; 404 không gọi lại; mẫu sửa giá; lưu đơn trước thanh toán; voice final→API; request đơn chậm không bị polling khởi động lại.
- AI Python: 80 đạt, 4 bài yêu cầu fixture riêng bỏ qua. Gọi AI cloud thật với dữ liệu QA không ghi nhà: lịch rảnh trả 200; prompt tiếng Việt tiệc bắt đầu 22:00, 10 khách, Chi và Trinh trả intent urgent, đúng 2 participant, ready_by và guest_count, không thiếu trường trong giới hạn 24 giờ.
- Analyzer sạch; model EF khớp migration. SQL `20261030034437_AddDurablePrivateMedia` chỉ thêm bảng và migration history, không sửa/xóa bảng hoặc dữ liệu cũ.
- Web release build thành công (234,3 giây). Build vẫn có cảnh báo Wasm dry-run từ plugin TTS và cảnh báo NuGet AutoMapper đã có trước đó; đây không phải kết quả build hoàn toàn không có warning. Bản JavaScript release đã được tạo.

## Cloud và giới hạn nghiệm thu

Sao lưu riêng trước cập nhật schema ở `artifacts/private/core-before-media-20261030.dump`; kiểm tra PGDMP, TOC và SHA256 trước khi áp dụng. Các file cấu hình, dump và media không đưa lên GitHub.

Người dùng đã cho phép tìm/khôi phục media còn được tham chiếu. Có 9 storage key được tham chiếu; tìm được 3 bản sao trong vùng upload đã biết. Chỉ khôi phục bản có size/hash khớp metadata; không tạo nội dung thay thế cho các file không tìm được. Kết quả riêng nằm ở `artifacts/private/media-recovery-result.json` sau khi chạy recovery.

Các test không xác nhận thao tác microphone/camera, app SMS/điện thoại hay Google OAuth thật trên mọi thiết bị. Cloud phải chạy commit mới và frontend phải tải lại trước khi nghiệm thu. Một lần readiness 200 chỉ xác minh service sẵn sàng theo health check, không thay cho mọi luồng với tài khoản thật.
