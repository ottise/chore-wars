# Chore Wars AI service

Python chạy trên server; Flutter gọi API C# có JWT và kiểm tra quyền. C# giữ quyền ghi lịch, trách nhiệm, Karma, tiền và đồng thuận. Xem [kế hoạch nghiệp vụ](../docs/plans/ai-python-full-implementation-plan.vi.md) và [trạng thái kiểm chứng](../docs/reports/ai-implementation-status-2026-10-22.vi.md).

## Kiến trúc

```text
Flutter → C# AIHousekeeperService → private FastAPI
             │                          │
             ├─ recommendation/review   ├─ allocation / swap / urgent
             ├─ existing consensus     ├─ provider: NLU / advisory vision
             └─ atomic core outbox ─Kafka─ worker → AI PostgreSQL
                                               ├─ behavior profiles
                                               ├─ evaluation / learning snapshots
                                               └─ trainer → candidate registry/artifact
```

| File/module | Trách nhiệm |
|---|---|
| `schemas.py`, `main.py` | Contract có version, xác thực service key và scope C# cấp |
| `storage.py`, `worker.py`, `stream.py` | Inbox idempotent, projection theo sequence, kiểm tra đủ batch, cách ly lỗi |
| Core `AIObservations` / Flutter `AiObservedView` | Open signal task/bounty sau render; scope + dedup phía server, bảo vệ đổi session; không tạo nhãn acceptance/preference |
| `behavior.py` | Đóng góp theo actual completer, episode, bounty outcomes, ledger, rank và bằng chứng |
| `profile_metrics.py`, `preference_history.py` | Metadata/lineage riêng cho 10 metric chính; lịch sử khai báo đã xác nhận, dedup replacement, clear không thành dislike; lịch sử riêng chỉ trả cho actor |
| `allocation.py`, `swap.py`, `bounty.py`, `urgent.py` | Baseline, best-improvement search, đổi việc hợp lệ, gợi ý tự nguyện, DAG/resource timeline |
| `provider.py` | Gemini structured output, giới hạn thời gian, kiểm tra schema/reference/quote, không tự ghi nghiệp vụ |
| `dataset.py`, `labels.py`, `features.py` | Source snapshot lúc nhận việc, nhãn tại cutoff, preprocessing fit riêng từng fold; cấm identity feature |
| `ml.py`, `trainer.py`, `registry.py` | 14 cấu hình đối chiếu, calibration/threshold, frozen walk-forward/refit, artifact hash và cổng promotion riêng |
| `evaluation.py`, `learning.py`, `aggregation.py`, `demo.py` | Lịch sử đánh giá bất biến, B0/S0/H1, sample counts, monthly seed aggregation/bootstrap |
| `cli.py`, `migrations/` | Công cụ vận hành nội bộ; Alembic PostgreSQL migrations |

## Cài đặt và chạy riêng

Dùng Python 3.12. Từ thư mục `ai-service`:

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.lock
.venv/Scripts/python -m pip install --no-deps -e .
.venv/Scripts/python -m pip install '.[test]' -c requirements.lock
& .venv/Scripts/Activate.ps1
$env:AI_DATABASE_URL='postgresql+psycopg://USER:PASSWORD@localhost:PORT/chorewars_ai'
$env:AI_SERVICE_KEY='<random-secret-at-least-32-characters>'
$env:AI_KAFKA_SERVERS='localhost:9094'
python -m app.cli migrate
python -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000
```

Chạy `python -m app.worker` và `python -m app.trainer` ở process riêng bằng Python trong venv. Không dùng database Core cho service Python. Không đưa service key vào Flutter. Với mật khẩu có ký tự đặc biệt, URL-encode phần credential trong DSN.

Core cần `AI__Enabled=true`, `AI__BaseUrl`, `AI__ServiceKey`; migration EF cần apply riêng qua quy trình hiện có. Chủ nhà bật AI trong app, từng người tự opt-in chat. Thiếu Gemini key chỉ ảnh hưởng adapter provider; phân công và số liệu nội bộ không cần LLM.

Docker opt-in từ repository root, sau khi cấu hình `AI_SERVICE_KEY`, `AI_POSTGRES_PASSWORD` và các biến Core hiện có:

```powershell
docker compose -f docker-compose.yml -f docker-compose.ai.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.ai.yml up --build -d
```

Overlay không publish cổng AI/AI PostgreSQL ra host. `ai-migrate` chạy trước API/worker/trainer. Chạy EF migrations Core trước khi bật traffic; backend không tự migrate trong `Program.cs`. `GEMINI_API_KEY` tùy chọn, model ID cấu hình bằng `GEMINI_TEXT_MODEL`/`GEMINI_VISION_MODEL`. Provider dùng REST chính thức, không cần SDK Gemini.

## Kiểm thử và xuất contract

```powershell
python -m pytest tests -q
python -m app.cli export-contracts
```

`export-contracts` xuất OpenAPI và `contracts/profile-metrics.v1.json` từ chính định nghĩa metric đang chạy. Test kiểm tra dictionary không lệch source. Ba đặc tả kỹ thuật: [dữ liệu/metric](../docs/ai/data-metric-specification.vi.md), [learning targets](../docs/ai/learning-task-specification.vi.md), [demo/evaluation](../docs/ai/demo-evaluation-specification.vi.md); chưa có lock manifest cho nghiệm thu cuối.

Từ repository root, `./ai-service/scripts/test-container.ps1` build image và tự tạo tài nguyên disposable để chạy **18 test AI/swap/Core–Python/evidence HTTP thật**. Nếu đã có image `chorewars-ai:verification`, dùng `-SkipBuild`; source hiện tại được mount read-only. Script tự dọn container/network, không cần Gemini, không thay đổi stack ứng dụng đang chạy. Bridge outbox trong test dùng import HTTP nội bộ; kiểm thử Kafka được thực hiện riêng.

`./ai-service/scripts/test.ps1 -PostgresAdmin '<local-test-DSN>' -Kafka 'localhost:9094' -CoreDemoManifest '<manifest-path>'` chạy toàn bộ Python runtime/parity. `-Offline` là lựa chọn chủ động bỏ PostgreSQL/Kafka; file XML/manifest ghi rõ test skip và không thay bằng chứng runtime.

Test PostgreSQL chỉ chạy khi `AI_TEST_POSTGRES_ADMIN` trỏ tới server local dành cho kiểm thử; fixture tạo/drop database GUID riêng. Test Kafka còn cần `AI_TEST_KAFKA`; test tạo/xóa topic và consumer group có prefix riêng. Không dùng broker production cho crash test. Test parity cần `AI_CORE_DEMO_MANIFEST` trỏ tới manifest thật từ công cụ demo C#.

SQLite chỉ được phép ở `AI_ENVIRONMENT=test`, test tạo schema qua metadata; không hỗ trợ Alembic SQLite. Kết quả SQLite không thay bằng chứng chạy PostgreSQL.

## Demo 14 mùa và thực nghiệm

Từ repository root, sau khi build tool và cấu hình server local disposable:

```powershell
$env:CHOREWARS_DEMO_POSTGRES_ADMIN='Host=127.0.0.1;Port=PORT;Database=postgres;Username=USER;Password=PASSWORD'
dotnet run --project backend/tools/AIDemo -- --seed 44 --months 14 --output artifacts/demo/seed-44
python -m app.cli demo-evaluate --manifest artifacts/demo/seed-44/manifest.json
```

Tool seed tài khoản/routine rồi chạy application services thật; không seed nhãn trực tiếp. Database demo luôn có prefix `cw_ai_demo_`, marker `DEMO_SYNTHETIC`, không ghi vào nhà thật. Đường dẫn manifest được kiểm tra nằm trong thư mục export. Export chứa dữ liệu cá nhân giả lập và không đưa vào Git.

`demo-evaluate` mặc định đo serving deadline; `--mode budget` chạy đủ move budget, có thể lâu hơn và **không chứng minh SLA serving**. Có thể truyền nhiều `--manifest`; chỉ tổng hợp đủ seed 42–61, tháng 6–14 tương thích mới có CI95 bootstrap 10.000 lần. Một seed trả PARTIAL, không giả confidence interval. Actual completion outcomes thuộc policy baseline đã thực thi; lịch counterfactual không có outcome quan sát để kết luận giảm trễ.

Train riêng: `python -m app.cli train --house HOUSE_UUID --target T1`. T1 insight rủi ro trách nhiệm quan sát; T2 shadow. B0 ưu tiên nếu model phức tạp không hơn đủ theo protocol. Không mặc định Random Forest. Threshold không đạt trả null. Candidate không tự phục vụ người dùng; promotion cần predictive gate và product run độc lập. Không cung cấp đường mobile tự train/promote hoặc tự tạo product evidence.

```powershell
python -m app.cli model-status --house HOUSE_UUID
python -m app.cli promote --house HOUSE_UUID --model MODEL_UUID --product-run RUN_UUID
```

Registry kiểm tra hash/path, schema feature và data source. Artifact lỗi bị suspend, thử previous approved; không có bản hợp lệ trả `NO_APPROVED_MODEL`, không bịa xác suất. Tăng số event không đồng nghĩa model tiến bộ.

## Sự cố và quyền riêng tư

- Worker commit PostgreSQL trước Kafka offset; replay event không nhân đôi fact. Parse/identity lỗi được cách ly bền vững trước khi commit offset, không chặn toàn partition mãi.
- Payload chưa xác thực house nằm ở operations, owner không xem raw message. Owner chỉ thấy metadata lỗi thuộc house đã xác minh. Replay nội bộ `python -m app.cli replay-failure --id FAILURE_UUID --house HOUSE_UUID`; không chỉnh payload nguồn để vượt identity conflict.
- Chat auto-insight dùng durable queue trong Core PostgreSQL (không gửi raw chat lên topic telemetry). Claim/lease, opt-in version và kiểm tra sau inference bảo vệ revoke; kết quả riêng từng người. Tắt consent xóa dẫn xuất, không xóa sự kiện nghiệp vụ đã xác nhận.
- API health không chứng minh đã chạy provider hoặc thiết bị. Camera, STT microphone, TTS speaker còn cần nghiệm thu điện thoại thật.
- Recommendation hết hạn hoặc context đổi phải tạo lại. Availability ACTIVE và assignment được áp dụng nguyên tử qua proposal; một người từ chối giữ lịch cũ.
