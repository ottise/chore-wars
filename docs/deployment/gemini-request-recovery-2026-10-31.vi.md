# Khắc phục request AI ngày 31/10/2026

## Chẩn đoán đã thực hiện

- Backend `/health/ready` và Python AI `/health/ready` đều trả 200. Backend đang ở `6247d59`, Python AI còn `da34063` lúc kiểm tra.
- Kiểm tra `/health/service-auth` của Python bằng khóa nội bộ có sẵn trả 200, `authenticated=true`, `schema_ready=true`, `provider_configured=true`. Kết quả này xác minh diagnostic client kết nối Python; không thay thế một lượt frontend có user session thật.
- Gửi đúng một prompt tổng hợp trực tiếp tới Python AI cloud nhận 503 `PROVIDER_SCHEMA_INVALID`. Backend hiện chuyển lỗi AI không khả dụng sang HTTP 409 với thông báo an toàn, nên frontend thấy 409 không có nghĩa request chưa tới AI.
- Tái hiện bằng provider code và prompt tổng hợp: Gemini trả `requires_confirmation=false`; `LanguageResult` yêu cầu literal `true`, gây validation error. Không phải lỗi model không tồn tại hay key bị từ chối trong lượt gọi này.
- Tái hiện độc lập lỗi cấu hình: `Settings` có prefix `AI_`, nên trước sửa các biến `GEMINI_*` thuần trên Render không được đọc. Nếu đã tồn tại biến `AI_GEMINI_*` cũ, service vẫn có thể dùng cấu hình cũ và báo `provider_configured=true`.

## Bản sửa

- Ứng dụng áp đặt `requires_confirmation=true` trước khi validate kết quả ngôn ngữ. Model không được quyền tắt chính sách xác nhận. Các kiểm tra intent, schema, member/chore ID, evidence quotes và catalog vẫn giữ nguyên.
- Nhận cả `GEMINI_API_KEY`, `GEMINI_TEXT_MODEL`, `GEMINI_VISION_MODEL` và các tên cũ có prefix `AI_`. Tên `GEMINI_*` ưu tiên khi cùng có cả hai để cấu hình Render mới ghi đè cấu hình cũ. Giá trị truyền trực tiếp trong constructor vẫn ưu tiên hơn environment.
- Không thêm retry Gemini tự động, không ghi key hay response chứa dữ liệu người dùng vào log, không tự áp dụng kế hoạch từ prompt.

## Render cần deploy service nào?

**Deploy bản mới cho service `chorewars-ai`**, không chỉ bấm deploy `chore-wars` (.NET).

| Service | Key | Giá trị / ý nghĩa |
|---|---|---|
| `chorewars-ai` | `GEMINI_API_KEY` | Key Gemini từ tài khoản Google của bạn; chỉ nhập vào Environment |
| `chorewars-ai` | `GEMINI_TEXT_MODEL` | `gemini-3.5-flash-lite`, hoặc model được tài khoản hỗ trợ |
| `chorewars-ai` | `GEMINI_VISION_MODEL` | `gemini-3.8-flash`, hoặc model vision được tài khoản hỗ trợ |
| `chorewars-ai` | `AI_SERVICE_KEY` | Khóa nội bộ giữa .NET và Python, giữ giá trị đã cấu hình đúng |
| `chore-wars` | `AI__Enabled` | `true` |
| `chore-wars` | `AI__BaseUrl` | `https://chorewars-ai.onrender.com` |
| `chore-wars` | `AI__ServiceKey` | Cùng khóa nội bộ với `AI_SERVICE_KEY` bên Python, không phải key Gemini |

Không thay khóa nội bộ bằng Google key chỉ vì chúng đều được gọi là API key. Không cần thay database/schema cho bản sửa này.

1. Lưu biến trên đúng `chorewars-ai`, bỏ các giá trị cũ mâu thuẫn nếu không còn dùng.
2. `Manual Deploy` → `Deploy latest commit`, chờ Live.
3. Kiểm tra `https://chorewars-ai.onrender.com/health/version` là commit chứa bản sửa; ready trả 200. Ready 200 chỉ xác nhận schema/khả năng phục vụ, không chứng minh Gemini inference thành công.
4. Tải lại frontend, đăng nhập nếu session đã hết hạn. Gửi “Xin chào” và yêu cầu tiếng Việt có người tham gia/thời gian rõ ràng. Kết quả cần có phản hồi hoặc bước review, không tự áp dụng lịch.
5. Nếu vẫn lỗi, lấy response body của request `/ai/interpret` và mã provider an toàn trong log AI service. Không gửi token, API key hay nội dung riêng của cả nhà.

Log người dùng gửi còn có `my-houses 401` và `refresh-token 403`: đó là vấn đề session user, tách biệt với key Gemini. Đăng nhập lại và kiểm tra một request đã có phiên hợp lệ; không đổi key Gemini để chữa lỗi refresh token.

## Kiểm tra

- Regression tests cho hai bộ tên environment, ưu tiên tên Render, constructor override và không lộ secret trong repr.
- Regression tests Gemini trả cờ confirmation false ở help/action vẫn cần xác nhận; intent không hợp lệ vẫn bị từ chối.
- Hai lượt gọi Gemini thật với dữ liệu tổng hợp qua tên biến Render đã thành công: intent `help` và `urgent`, đều có `requires_confirmation=true`, không thiếu trường cho prompt chia việc mẫu. Không gửi nội dung nhà thật và không apply thay đổi.
- Chưa xác nhận frontend sau deploy mới trên Render; việc này cần kiểm tra lại khi service Python lên đúng phiên bản.

Tài liệu Google: [Models API](https://ai.google.dev/api/models). Khi kiểm tra model thực tế, dùng model do `models.list` trả về cho tài khoản; không suy ra key hỏng chỉ từ thông báo generic 409 của backend.
