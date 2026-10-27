# Chạy và kích hoạt CI/CD

Các workflow đã có trong source. CI chạy khi PR/push vào `main`; CD **chưa bật** cho tới khi cấu hình bên dưới hoàn tất. Không có secret production trong PR job.

## Kiểm thử local

Từ root repo, dùng SDK .NET trong `global.json`, Python 3.12 và Flutter revision trong `mobile/scripts/install-flutter.sh`.

```sh
docker compose -p cw-ci -f docker-compose.ci.yml up -d --wait --wait-timeout 180
dotnet test backend/tests/UnitTests -c Release
python -m pytest scripts/ci/tests
```

Postgres test: loopback `55435`, user `ci`, password `ci-disposable-only`. Kafka test: `localhost:59094`. Credential này chỉ dành cho fixture bị hủy sau test.

Các biến runtime và lệnh đầy đủ nằm trong `.github/workflows/ci-cd.yml`. Backend/Python suites dùng database có prefix test, không được trỏ tới Render. Backend outage test yêu cầu đúng broker fixture `cw-runtime-kafka-00000000000000000000000000000001`; không chạy đồng thời Python Kafka suite trên cùng broker khi chạy local. Hai job GitHub dùng VM riêng.

Python parity test cần export thực bằng `backend/tools/AIDemo` với `--months 1`; không dùng manifest mock. Contract server trong `ai-service/tests/contract_server.py` chỉ bind loopback, dùng SQLite tạm và thay đúng biên Gemini bằng response fixture. Planner, HTTP contract và persistence vẫn chạy thật. File fixture bị loại khỏi image AI production.

Sau kiểm thử:

```sh
docker compose -p cw-ci -f docker-compose.ci.yml down -v
```

Lệnh này chỉ dọn project fixture, không xóa Docker DB hiện có. Mỗi report TRX/JUnit bắt buộc phải có test và không có skip; thiếu credential test phải làm CI thất bại. `ci-required` kiểm tra tất cả job, kể cả trường hợp job bị cancel/skip. Hiện CI chạy toàn bộ suite cả với docs-only để giữ required check đơn giản; chưa tối ưu skip theo path.

## Cấu hình GitHub/Render một lần

1. GitHub → Settings → Environments: tạo `production` và `production-db`. Đặt required reviewer, giới hạn nhánh main; environment DB không cho tự approve. Nếu gói GitHub không hỗ trợ reviewer, **không bật `DB_MIGRATIONS_ENABLED`**; apply thủ công sau review.
2. Ruleset main: yêu cầu check `ci-required`, PR review và ngăn force push. Không cần bot có quyền merge.
3. Render backend/AI → Settings: tắt Auto-Deploy trực tiếp để tránh bỏ qua CI. Lấy Deploy Hook riêng từng service và Render API key có quyền đọc deployment. Hook là secret.
4. Render backend: tạo key ngẫu nhiên mới cho `DeploymentHealth__Key` (ít nhất 32 ký tự). Không dùng lại AI key. Render health path `/health/ready`.
5. Render AI: health path `/health/ready`; xóa Docker Command override cũ có `python -m app.cli migrate`. Dùng CMD Dockerfile đã đọc `PORT`; migration tách riêng. AI DB phải tồn tại và được migrate trước khi readiness đạt.
6. GitHub environment `production`: thêm secrets/variables trong bảng dưới. Tài khoản DB read-only cần quyền CONNECT/USAGE/SELECT migration history và information_schema. Đường kết nối dùng PostgreSQL URI chuẩn, không dùng chuỗi Npgsql hay prefix `AI_DATABASE_URL=`.
7. Chạy CI trên main và kiểm tra report. Chỉ đặt repository variable `CD_ENABLED=true` sau khi cấu hình/health/schema đủ. Khi chưa bật, workflow deploy bị skip có chủ ý; không có release thành công giả.

| Loại | Tên | Giá trị/công dụng |
|---|---|---|
| Secret production | `RENDER_API_KEY` | Render API key chỉ dùng cho CD |
| Secret production | `RENDER_AI_DEPLOY_HOOK` | Hook của AI API |
| Secret production | `RENDER_BACKEND_DEPLOY_HOOK` | Hook của backend |
| Secret production | `DEPLOYMENT_HEALTH_KEY` | Khớp Render `DeploymentHealth__Key` |
| Secret production | `CORE_READONLY_DATABASE_URL` | URI cloud DB core, account read-only |
| Secret production | `AI_READONLY_DATABASE_URL` | URI cloud DB AI, account read-only |
| Variable production | `RENDER_AI_SERVICE_ID` | `srv-...` lấy ở trang AI service |
| Variable repository | `CD_ENABLED` | `true` để bật CD sau CI |
| Variable production | `FRONTEND_ENABLED` | Chỉ `true` khi FE đã host |
| Variable production | `RENDER_FRONTEND_SERVICE_ID`, `FRONTEND_URL` | Service ID/HTTPS URL của FE |
| Secret production | `RENDER_FRONTEND_DEPLOY_HOOK` | Chỉ cần khi bật FE |
| Secret production-db | `CORE_MIGRATION_DATABASE_URL`, `AI_MIGRATION_DATABASE_URL` | Account migration riêng, không dùng account read-only |
| Variable repository | `DB_MIGRATIONS_ENABLED` | Chỉ bật khi đã cấu hình approval DB |

Không upload `.env` thật lên GitHub. Không cho Render API key hoặc Gemini/payOS key vào `dart-define`.

Workspace có `.env.cicd.local` bị gitignore, chứa danh sách trường cần điền và key health mới chỉ lưu trên máy. Điền trực tiếp trong file rồi chuyển từng giá trị vào đúng GitHub environment/Render field trong bảng; không commit hoặc upload cả file lên repository.

Khi tạo FE Static Site từ root repo, build command: `bash mobile/scripts/install-flutter.sh && PATH="/tmp/chorewars-flutter/bin:$PATH" bash mobile/scripts/build-render-web.sh`; publish directory `mobile/build/web`. Cấu hình SPA rewrite và cache theo `mobile/README.md`. Đây là bước host FE riêng; hiện chưa có FE service ID/URL.

## Đường chạy

`CI` → `ci-required` → `Deploy verified main` → kiểm tra SHA còn là main → tải migration manifest của chính run đã test → schema gate read-only → AI hook + poll → AI smoke → backend hook + poll → backend smoke + protected dependency report → FE khi có → release report.

Tách CD sang `deploy.yml` để serialize deployment, không bị concurrency cancel của CI cắt một lần phát hành đang chạy. `workflow_run` chỉ nhận CI thành công của main, từ chối PR. Hook chỉ gửi một lần; timeout chưa biết kết quả thì tìm deployment mới theo SHA, không POST lặp. HTTP 200/202 hook chưa là Live. Poll Render API và public SHA cùng phải khớp.

Chạy script deploy lỗi sẽ trả exit 1 và report không có credential. Không bật `set -x`/HTTP debug khi dùng hook. Không upload raw environment, request header, login token, database dump hoặc container inspect. Test account production không nằm trong smoke mặc định.

## Migration có review

1. Chạy `Reviewed database migration` trên main, `apply=false`, chọn SHA/DB. Với AI, nhập revision đang áp dụng trong `from_revision`; chỉ dùng `base` khi DB rỗng. Tải `reviewed-migrations`, review SQL và manifest. SQL đầy đủ chứa schema cũ, chỉ chia sẻ trong nhóm vận hành.
2. Tạo và kiểm tra backup bằng quy trình DB riêng. Workflow không giả vờ tạo backup chỉ từ một tên.
3. Chạy lại cùng SHA/target/from_revision, nhập SHA256 của SQL đã review, backup reference, `apply=true`. Job review tạo lại SQL để đối chiếu; job apply dừng tại approval `production-db`. Script kiểm tra đúng tên DB và history/revision trước khi ghi.
4. Reviewer so SQL/hash/backup trước khi approve. Chỉ artifact đúng hash mới được thực thi. Kiểm tra history sau apply. Không retry tự động khi kết quả ghi chưa rõ, không Down/drop/reset/restore tự động.
5. Chạy lại CI/CD tại cùng SHA hoặc commit sửa tiếp theo. Lần chuyển Docker DB trước đây không được lặp lại trong pipeline.

## Đọc kết quả và rollback

`release-report.json` phân biệt pass/fail/degraded/unverified/not-applicable. Profile `core` chỉ chứng nhận backend/API AI/schema; chưa chứng nhận đầy đủ chức năng notification/media/training. Profile `full` yêu cầu cả Kafka, worker, trainer, FE và media. `redis` lỗi được báo degraded vì app có fallback. Worker heartbeat là hoạt động loop thực, chưa chứng minh consumer lag bằng 0 hoặc mọi message đã xử lý.

`last-known-good.json` chỉ sinh khi mọi bước deploy/smoke bắt buộc của core đạt. Đây là metadata trong artifact 30 ngày, chưa phải kho lưu backup. Nếu bật frontend mà deploy/smoke FE lỗi thì không lưu last-known-good, kể cả backend healthy.

Khi lỗi: mở run CI/CD → failed step → artifact đã lọc → Render deployment/log cùng deploy ID/SHA. Rollback app qua Render về artifact đã biết tốt sau khi xác minh config/key rotation và tương thích schema. Không tự rollback DB/payOS hoặc xóa media. Migration không tương thích cần bản sửa tiến tới hoặc restore có phê duyệt riêng.

AutoMapper 12.0.1 có advisory được theo dõi trong `deploy/security-exceptions.json`, hạn 11/11/2026; warning không bị ẩn. Advisory mới/exception hết hạn chặn CI. Việc nâng major mapping library thuộc đợt hồi quy riêng. Python audit báo lỗ hổng thì chặn CI, không tự fix dependency.

Nguồn contract: [Render deploy hooks](https://render.com/docs/deploy-hooks), [Render health checks](https://render.com/docs/health-checks), [pip-audit](https://github.com/pypa/pip-audit).

## Bằng chứng triển khai local — 28/10/2026

- Backend: 113 unit và 72 integration đạt, 0 skip. Integration chạy PostgreSQL/Kafka thật, có broker outage, crash/retry, notification và HTTP contract với Python.
- AI: 83 bài full suite đạt, 0 skip; sau bổ sung health/auth chạy thêm 6 bài tập trung đều đạt. Allocation parity dùng export thực từ core business services trong DB tạm.
- CI gates: 10 unit cho report, manifest, deploy queue/timeout/SHA, smoke, release và security policy; 1 bài schema gate với PostgreSQL thật, đều đạt.
- Flutter: analyzer sạch và 98 test đạt. Workflow qua actionlint; shell scripts qua `bash -n`.
- Python audit không có advisory đã biết; NuGet chỉ có AutoMapper được ghi exception có hạn. SQL review EF/Alembic sinh được; chưa apply lên cloud.
- Log/report local ở `artifacts/ci/` bị gitignore. Đây là bằng chứng rehearsal local, chưa thay thế một run GitHub Actions hoặc release production sau khi cấu hình secrets.
