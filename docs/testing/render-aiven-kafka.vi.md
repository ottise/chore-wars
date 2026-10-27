# Kết nối Kafka Aiven từ Render

Backend và AI worker đã hỗ trợ SASL qua TLS, giữ kiểm tra CA và hostname.
Code này cần được đưa lên branch Render đang deploy trước khi các biến mới có tác dụng.

Backend tự lắng nghe trên `0.0.0.0` theo biến `PORT` của Render.
PostgreSQL cloud mới cần được chạy migration hoặc chuyển dữ liệu bằng quy trình riêng;
backend không tự thay đổi schema khi khởi động.
Với StackExchange.Redis, dùng `Redis__ConnectionString=hostname:6379`, không dán tiền tố `redis://`.

## Backend .NET

Render > backend > Environment:

```ini
Kafka__BootstrapServers=chorewars-kafka-chore-war.k.aivencloud.com:19153
Kafka__SecurityProtocol=SaslSsl
Kafka__SaslMechanism=Plain
Kafka__SaslUsername=avnadmin
Kafka__SaslPassword=<nhập trực tiếp mật khẩu Kafka từ Aiven>
Kafka__SslCaLocation=/etc/secrets/kafka-ca.pem
```

Aiven > Connection information > Apache Kafka > SASL > CA certificate:
copy đầy đủ PEM, gồm BEGIN CERTIFICATE và END CERTIFICATE.
Render > backend > Environment > Secret Files: tạo `kafka-ca.pem` chứa PEM đó.
Không đặt mật khẩu hoặc certificate vào mã nguồn. Không tắt SSL verification.

## Topic

Tạo trong Aiven > Topics, dùng các tên chính xác dưới đây (TopicPrefix mặc định trống):

```text
chore.completed
chat.message_created
bounty.created
bounty.accepted
chore.overdue
bounty.expired
season.ended
chore.deadline_reminder
supply.notification
ai.telemetry.v1
```

Đảm bảo tài khoản kết nối có quyền đọc/ghi topic và consumer group.
Chọn partition/replication trong giới hạn thực của gói Aiven; không giả định broker tự tạo topic.

## AI worker Python

Đây là tiến trình riêng `python -m app.worker`, không được khởi chạy bởi Uvicorn.
Dùng cùng AI_DATABASE_URL và AI_SERVICE_KEY với AI API, thêm:

```ini
AI_KAFKA_SERVERS=chorewars-kafka-chore-war.k.aivencloud.com:19153
AI_KAFKA_SECURITY_PROTOCOL=SASL_SSL
AI_KAFKA_SASL_MECHANISM=PLAIN
AI_KAFKA_SASL_USERNAME=avnadmin
AI_KAFKA_SASL_PASSWORD=<mật khẩu Kafka>
AI_KAFKA_SSL_CA_LOCATION=/etc/secrets/kafka-ca.pem
```

Thêm Secret File `kafka-ca.pem` cho worker nữa. Chỉ nhập biến Kafka vào AI API
không tự tạo worker hoặc tác vụ học nền.

## Kiểm tra

Sau deploy, log không còn gọi `localhost:9094`. Lỗi SSL cần kiểm tra CA/hostname;
lỗi SASL cần kiểm tra username/password/mechanism; lỗi unknown topic cần kiểm tra topic.
Thử một sự kiện từ hai tài khoản cùng nhà để xác nhận outbox được xử lý và thông báo đến đúng người.
Lỗi database/migration độc lập với kết nối Kafka, cần xử lý riêng.

Tài liệu: https://aiven.io/docs/products/kafka/howto/kafka-sasl-auth
