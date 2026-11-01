# AI service: cold start và kiểm tra Render

## Nguyên nhân request 502 trong log ngày 1/11/2026

Log cho thấy Python AI hoàn tất shutdown lúc 20:08, trong khi request từ backend nhận 502 khoảng 21:16; lần deploy tiếp theo chỉ bắt đầu lúc 21:21. Vì vậy request không tới FastAPI. Các dòng `GET / 404` trước đây chỉ là Render/monitor gọi root chưa có route, không phải lỗi Gemini hay service key.

Render Free tự spin down service sau 15 phút không có inbound traffic; request đầu có thể mất khoảng một phút để khởi động lại. Cấu hình key/model không thể giữ instance thức. Nguồn: [Render Free](https://render.com/docs/free).

## Thay đổi trong source

- Backend nhận diện gateway 502/504 và proxy 503 không có mã lỗi JSON của ứng dụng, poll `/health/ready` tối đa 65 giây, rồi chỉ thử lại một lần.
- Chỉ retry GET và POST `/v1/*` là các phép tính không ghi dữ liệu. Không replay `/internal/events` hay `/internal/evaluations`.
- Nếu AI trả lỗi provider JSON (ví dụ `PROVIDER_*`), backend không coi đó là cold start và không retry.
- AI trả 200 ở `/` để Render/uptime check không ghi 404 gây nhiễu.

## Cấu hình Render sau khi deploy

Trong `chorewars-ai` → Settings → Health Checks, đặt **Health Check Path** thành `/health/ready`. Endpoint này chỉ báo healthy khi schema AI sẵn sàng, trong khi `/health/live` chỉ báo process đang chạy. Health check xác nhận trạng thái deploy; nó không bảo đảm Free instance luôn thức. Tham khảo [Render health checks](https://render.com/docs/health-checks).

Sau khi deploy cả hai service:

1. `chorewars-ai`: `/health/ready` trả 200 khi service thức và database/schema sẵn sàng; `/` trả `{"service":"chorewars-ai","status":"live"}`.
2. `chore-wars`: gửi một request AI sau thời gian idle. Nếu AI đang ngủ, lần gọi có thể chờ tới khoảng một phút rồi tự retry đúng một lần.
3. Nếu vẫn lỗi sau khi `/health/ready` trả 200, xem log Python tại cùng thời điểm. Lỗi `PROVIDER_*` là cấu hình/quota/model Gemini; `401` là khóa nội bộ `AI_SERVICE_KEY`/`AI__ServiceKey`; lỗi schema là database/migration. Không dán các key này vào chat.

