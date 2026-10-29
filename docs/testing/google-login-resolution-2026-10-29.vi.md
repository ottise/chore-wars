# Google login — kết quả xử lý ngày 29/10/2026

## Nguyên nhân đã xác minh

Frontend đã nhận được kết quả Google và gọi `POST /api/auth/google`, nhưng backend Render trả HTTP 404. `/health/version` khi đó báo commit `987ba3fd3845165f30bd4888e4efa7fd7ae60854`, chưa có endpoint Google. Đây là lỗi phiên bản backend đang chạy; không phải lỗi origin Google trong lần tái hiện này.

Sau khi người dùng chọn **chore-wars → Manual Deploy → Deploy latest commit**, backend báo commit `da34063997a366d0b35311e2d4c543eb82cd6ef4`:

- `/health/ready`: 200 `Healthy`.
- `POST /api/auth/google` với token thử không hợp lệ: 403, có ProblemDetails an toàn; không còn 404.
- CORS preflight từ `http://localhost:7357`: 204 và allow-origin đúng.
- Người dùng thử lại tài khoản Google thật và xác nhận **đã đăng nhập được** trong phiên làm việc này.

## Thay đổi bổ sung

- Không gửi bearer token cũ vào các endpoint đăng nhập, đăng ký, Google exchange và refresh. Endpoint liên kết Google vẫn cần xác thực.
- Request refresh của phiên cũ không được ghi đè token hoặc đăng xuất phiên Google mới. Kiểm tra cả epoch của provider và token hiện tại; callback hết phiên cũng kiểm tra epoch trước khi chạy.
- Nếu backend thiếu endpoint Google, giao diện hiện thông báo dành cho đăng nhập Google thay vì thông báo không tìm thấy dữ liệu.
- Smoke test deploy kiểm tra endpoint Google bằng token cố ý không hợp lệ. Backend khỏe nhưng thiếu endpoint hoặc trả thành công cho token sai sẽ không đạt gate.

## Kiểm thử

- Toàn bộ Flutter: **122 đạt**, 1 live-network test bỏ qua vì cần fixture riêng. Không tính test bỏ qua là đã chạy trong lượt này.
- Flutter analyzer: **không có vấn đề**.
- Google backend integration: **4 đạt**, gồm HTTP exchange → JWT → truy cập endpoint bảo vệ; từ chối identity sai; đăng nhập đồng thời; liên kết tài khoản hiện có và giữ dữ liệu; từ chối liên kết email khác.
- Google verifier unit: **3 đạt**.
- CI gate Python: **11 đạt**, 1 test tùy chọn bỏ qua. Có regression test không cho readiness che giấu Google endpoint 404.

HTTP integration dùng verifier giả chỉ trong test để cấp identity xác định; production vẫn dùng Google signature validation. Xác minh tài khoản Google thật trên cloud do người dùng thực hiện, không dùng token giả để khẳng định đăng nhập thật.

## Lưu ý vận hành

Code đã push không đồng nghĩa Render đã chạy bản đó. Kiểm tra SHA tại `/health/version` sau deploy. Không cần chỉnh OAuth origins hay xóa dữ liệu tài khoản để sửa trường hợp backend thiếu route. Khi chạy frontend trên origin mới, origin đó vẫn phải được đăng ký trong Google Cloud.
