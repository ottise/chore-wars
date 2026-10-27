# Chi tiết file triển khai CI/CD và kiểm tra phát hành

Cập nhật 28/10/2026, đối chiếu source `6de0b92`.
Phụ lục của [kế hoạch CI/CD](github-actions-render-cicd-plan.vi.md).
**Trạng thái: đã thực thi phần CI/CD core trong source; production CD chưa kích hoạt.** Xem [runbook](../../scripts/ci/README.md) để cấu hình environment/secrets, kiểm thử và migration.

Điều chỉnh khi triển khai: CD nằm riêng trong `.github/workflows/deploy.yml` để serialize mà không bị CI cancel; mọi thay đổi đều chạy đầy đủ CI nên chưa cần job `changes`. FE dùng static hosting, giữ nginx Docker local; chưa tạo proxy Render không được sử dụng. Worker/trainer AI và durable media thuộc đợt full, hiện inventory ghi chưa triển khai/chưa xác minh. Không tạo heartbeat giả cho các process này.

## 1. Quy tắc thực hiện

- **Tạo**: file chưa có, cần tạo khi thực thi; **Sửa**: sửa tại chỗ; **Có điều kiện**: chỉ sửa khi có nhu cầu thực đã nêu.
- Mỗi file phải có trách nhiệm, input/output, caller/callee và tiêu chí nghiệm thu; không để placeholder giả thành công.
- CI dùng credential test; CD dùng credential deployment; migration production có quyền và approval riêng.
- Backend giữ Clean Architecture, không đưa EF/Kafka/Redis/HTTP vào Application hoặc Domain.
- Không tạo framework CI/health tổng quát. Không sửa nghiệp vụ chore/bounty/payOS không liên quan trong PR CI/CD.
- Không sửa migration đã áp dụng, reset DB, mở quyền production hoặc mua dịch vụ chỉ vì thêm workflow.
- File ví dụ chỉ chứa placeholder; secret thật không nằm trong git, image, cache, test report hoặc artifact.

## 2. Workflow GitHub

### `.github/workflows/ci-cd.yml` — Tạo

**Công việc cụ thể**

- Triggers: PR vào main, push main, manual dispatch. Dispatch phải chỉ định SHA thuộc main và kiểm tra chính SHA đó.
- Jobs: `changes`, `backend-unit`, `runtime-integration`, `ai-tests`, `flutter`, `container-build`,
  `ci-required`, `schema-gate`, `deploy-ai`, `deploy-backend`, `deploy-frontend`, `release-summary`.
- `changes` phân biệt backend/AI/mobile/contracts/schema/docs, xuất outputs dùng cho các job phía sau.
- `ci-required` luôn xuất hiện, đối chiếu các job thực sự bắt buộc; không coi job bị hủy hoặc skip ngoài dự kiến là đạt.
- PR/fork không nhận production secrets; không dùng `pull_request_target` để chạy code PR có quyền production.
- Deploy chỉ từ main, test đạt, schema gate đạt; thứ tự AI → backend → FE nếu các service đó có thay đổi.
- CI cũ có thể cancel khi PR có commit mới. CD serialize và không cancel bản đang phát hành dở.
- Mỗi job có timeout; bước `always()` thu report/log đã lọc và dọn đúng fixture CI.
- Quyền mặc định `contents: read`; pin action SHA kèm ghi chú phiên bản. Chỉ tăng quyền khi có nhu cầu rõ.

**Input/output**: event, SHA, path diff → change scope, TRX/JUnit, artifact build, deployment report, Summary.
**Liên kết**: gọi compose CI, source/tests và script trong `scripts/ci/`.
**Nghiệm thu**: PR lỗi không deploy; docs-only vẫn có required check; main pass chỉ deploy SHA đã test.

### `.github/workflows/db-migrate.yml` — Tạo sau khi chốt quy trình DB

- Chỉ manual dispatch, nhận SHA main, DB đích, migration manifest/hash và xác nhận backup.
- Dùng environment `production-db` có reviewer, credential riêng và concurrency theo DB.
- Sinh/đối chiếu artifact trước approval; chỉ gọi `migrate_database.sh` sau khi được cho phép.
- Kiểm tra migration history/schema sau chạy; không tự Down/restore DB khi lỗi.
- Nếu gói GitHub chưa hỗ trợ approval cần thiết thì giữ apply thủ công, không thay bằng dispatch không bảo vệ.
- Input/output: yêu cầu migration đã review → artifact/backup reference và kết quả đã xác minh; không trigger trên PR.
- Nghiệm thu trước bằng DB tạm; thao tác production là một bước được cho phép riêng.

### `.github/dependabot.yml` — Tạo

- Theo dõi GitHub Actions, NuGet và pip theo manifest được công cụ hỗ trợ.
- PR dependency chạy CI bình thường; không tự merge, tự nâng major SDK hoặc phá lockfile để tạo kết quả xanh.
- Cảnh báo AutoMapper hiện tại có việc theo dõi riêng, owner và hạn xử lý; không bị xóa khỏi report.

## 3. SDK, công cụ và fixture

### `global.json` — Tạo

- Pin SDK .NET theo baseline 10.0.302, chọn roll-forward policy có kiểm soát.
- CI đọc file này; không dùng một major khác nếu bản pin không có.
- Nghiệm thu: restore/build/test thực sự chạy đúng SDK, gồm `WorkerTestHost` cùng cấu hình Release/Debug đã chọn.

### `.config/dotnet-tools.json` — Tạo nếu chưa có

- Pin `dotnet-ef` tương thích package EF của repo; scripts dùng `dotnet tool restore`.
- Không dựa vào global tool của runner. Kiểm tra được pending model và xuất migration artifact bằng tool pin.

### `docker-compose.ci.yml` — Tạo

- Chỉ PostgreSQL và Kafka KRaft test; không include compose production hoặc mount volume production.
- PostgreSQL bind loopback, credential test. Kafka có controller/broker/listener host và container đúng thực tế.
- Container name riêng để test pause/unpause; health/metadata wait có timeout.
- Các suite có broker/DB riêng hoặc chạy tuần tự; không để test pause broker của suite khác.
- Dọn đúng compose project sau job, không dùng prune toàn hệ thống.
- Output: endpoint/container ID fixture; truyền vào `CHOREWARS_TEST_*` và `AI_TEST_*`.
- Nghiệm thu: test chạy với fixture thật, DB có prefix test và không kết nối Render/Aiven production.

## 4. Inventory, kết quả và deploy scripts

| File | Nội dung sẽ làm | Input → output / file liên quan | Kiểm tra bắt buộc |
| --- | --- | --- | --- |
| `deploy/services.json` — Tạo | Khai báo service/kind, sourcePaths, service-ID/URL variable, dependency, profile core/full, health/version source và deploy order. Gồm cả service deploy bằng hook và dependency chỉ kiểm tra. | Workflow đọc để chọn job; `check_release.py` đọc để đánh giá. Không chứa secret hoặc connection string có password. | JSON hợp lệ, không vòng dependency; required service thiếu ID/URL phải báo lỗi. |
| `scripts/ci/check_results.py` — Tạo | Parse TRX/JUnit, tổng hợp pass/fail/skip; required skip ngoài allowlist làm fail. Không grep một dòng stdout để kết luận. | Reports backend/Python/Flutter → test-summary JSON và exit code. | Thiếu/rỗng/report lỗi format không được coi là 0 lỗi. |
| `scripts/ci/check_release.py` — Tạo | Ghép CI/schema/deploy/smoke/dependency report theo inventory. States: pass/fail/degraded/unverified/not-applicable. | Các report + profile → `release-report.json`, Markdown Summary. | Required unverified/fail chặn release; optional degraded có giải thích; core không tự trở thành full. |
| `scripts/ci/render_deploy.py` — Tạo | Trigger hook đúng ref/SHA; theo dõi queue, deploy ID, API status và SHA; backoff/timeout, che secrets. | Hook/API key env + service ID + SHA → deploy report. Gọi từ job CD, chuyển kết quả sang smoke. | 200 hook chưa là Live; 202 phải tìm deploy cùng SHA; không POST lặp ngay sau timeout mơ hồ. |
| `scripts/ci/smoke_test.py` — Tạo | Poll readiness ổn định, đối chiếu version/SHA; kiểm tra route/auth boundary, FE assets/router/proxy. Không follow redirect login thành pass. | URLs trong inventory + deploy report → smoke report và exit code. | Sai SHA, HTML gateway, 503, timeout, old-version 200 hoặc sai API/hub origin đều không được pass. |
| `scripts/ci/README.md` — Tạo | Lệnh chạy local, biến bắt buộc, output mẫu đã lọc, exit codes, dọn fixture, đọc deploy ID/log và rerun SHA. | Tài liệu cho dev/vận hành; dẫn tới runbook đầy đủ. | Người khác chạy lại được bằng fixture mà không cần secret production. |

### Contract chi tiết `render_deploy.py`

1. Validate SHA thuộc main, service được phép trong inventory và target HTTPS/Render host đúng.
2. Parse URL hook, thêm `ref=SHA` bằng URL parser; không nối sai `?`/`&` hoặc log URL chứa key.
3. POST hook; lưu response cần thiết đã lọc. HTTP 200 lấy deploy ID; 202 xử lý queue không có ID.
4. Poll API bằng API key; đối chiếu service/commit/state. 429 backoff; 401/404/409/failure/timeout có lý do rõ.
5. Sau POST timeout: tìm deployment theo SHA trước khi cân nhắc retry, tránh trigger hai lần.
6. Chỉ xuất `live=true` khi đúng deploy/SHA được xác minh. Chưa có API permission thì kết quả unverified.

### Contract chi tiết `smoke_test.py`

- Readiness 200/body đúng 3 lần liên tiếp; timeout và khoảng cách theo config, có cold-start budget.
- Version của bản cũ không xác nhận bản mới, kể cả URL chung đang trả 200.
- Route cần auth không có token phải trả 401 đúng kỳ vọng; việc này không thay thế test đăng nhập thành công.
- Production mặc định đọc-only. Không nhận mật khẩu cá nhân hoặc tạo chat/order/payment/user để smoke.
- Chế độ có test account cần cho phép riêng; token chỉ ở memory, không lưu JSON artifact hoặc log.

## 5. Manifest và migration scripts

### `scripts/ci/migration_manifest.py` — Tạo

- Đọc EF migrations/Alembic revisions từ chính checkout/SHA đã test.
- Xuất ID/revision, thứ tự/quan hệ, checksum, framework, SHA; sinh SQL review bằng tool pin nếu được yêu cầu.
- Phát hiện migration cũ bị thay checksum. Không kết nối hoặc sửa production.
- Caller: CI, schema gate, workflow migration. Output: `migration-manifest.json` và artifact review.

### `scripts/ci/schema_gate.py` — Tạo

- Nhận manifest và tài khoản read-only cho core/AI DB; xác minh database đích được cấp.
- Đọc EF history/Alembic version/bảng bắt buộc, phân biệt DB không tồn tại, thiếu history/bảng/revision và schema drift.
- Alembic có graph thì kiểm tra quan hệ revision; không so chuỗi tên ID theo thứ tự chữ.
- Không DDL/DML, create database, `create_all`, EF migrate hoặc Alembic upgrade.
- Credential thiếu/kết nối lỗi là fail/unverified; không tự bỏ qua gate.
- Caller: CD trước hook. Output: schema report đủ thông tin vận hành nhưng không có credential/SQL lỗi thô.

### `scripts/ci/migrate_database.sh` — Tạo sau khi chốt approval

- Chỉ dùng từ workflow migration bảo vệ, nhận artifact/hash/SHA/DB đích đã review và backup reference.
- Kiểm tra history trước, chạy EF/Alembic đúng framework, xác minh history sau.
- Không reset DB, `--clean`, restore Docker hoặc chạy Down tự động. Không retry toàn bộ lệnh ghi khi chưa biết kết quả.
- Bản chuyển 55 bảng lên Render vừa qua là bootstrap một lần, không phải bước chạy trên mỗi push.
- Output: log đã lọc và kết quả apply/verify; không tự thực hiện thao tác nghiệp vụ sau migration.

## 6. Backend Application: contract và DTO

Các file sau chỉ thêm khi có implementation thực trong cùng đợt, không để stub vào bản phát hành.

| File | Nội dung cụ thể | Dùng bởi / nghiệm thu |
| --- | --- | --- |
| `backend/src/Application/Interfaces/Services/IDatabaseSchemaStatus.cs` — Tạo | Contract `CheckAsync(CancellationToken)` đọc-only, không lộ EF/Npgsql/SQL/HTTP; không có phương thức Apply/Migrate. | Readiness và health report gọi; implementation ở Infrastructure. |
| `backend/src/Application/DTOs/Deployment/DatabaseSchemaStatusResponse.cs` — Tạo | Record trạng thái DB/schema và mã lý do ổn định; chi tiết revision dành riêng báo cáo bảo vệ. | Một class/file; không giữ password, SQL, stack trace hoặc user/house data. |
| `backend/src/Application/Interfaces/Services/IDependencyHealthService.cs` — Tạo | Contract lấy snapshot dependency, không expose library Kafka/Redis/HTTP trong Application. | Controller/health adapter gọi; không có API mua hàng/publish event dưới tên probe. |
| `backend/src/Application/DTOs/Deployment/DependencyStatusResponse.cs` — Tạo | Name/state/checkedAt/reasonCode và thời gian probe nếu đã đo; reason không lấy thẳng exception.Message. | Không gán lag/latency 0 khi chưa đo hoặc thiếu quyền. |
| `backend/src/Application/DTOs/Deployment/DeploymentHealthResponse.cs` — Tạo | SHA/version/profile và các component status; phân biệt ready/degraded/unverified. | Endpoint bảo vệ trả DTO; public route chỉ map phần tối thiểu. |

## 7. Backend Infrastructure và Presentation

### `backend/src/Infrastructure/Data/DatabaseSchemaStatus.cs` — Tạo

- Implement contract bằng EF/Npgsql; read-only, timeout và CancellationToken.
- Kiểm tra kết nối, đúng DB, EF history và bảng cần cho phiên bản đang chạy.
- Log lỗi nội bộ phù hợp, trả reasonCode chuẩn hóa, không throw chi tiết nhạy cảm ra HTTP.
- Cache ngắn/giới hạn tần suất để Render health probe không tạo tải nặng.
- Nghiệm thu: DB kết nối được nhưng thiếu Users/AIChatInsights không ready; probe không tạo bảng.

### `backend/src/Infrastructure/Diagnostics/DependencyHealthService.cs` — Tạo

- Tập hợp schema status; Kafka metadata/topic/permission với SASL/TLS hiện có; Redis ping timeout; AI configured/reachable riêng.
- Không tạo producer vô ích để ping, không tắt kiểm tra CA/hostname khi lỗi, không log credentials.
- Metadata broker chưa chứng minh consumer chạy: nếu thiếu heartbeat/lag hợp lệ thì consumer là unverified.
- Media chỉ kiểm tra storage/canary đã được cho phép; chưa cấu hình phải báo đúng giới hạn.
- Probe mạng có timeout/cache và giới hạn song song; không làm một dependency chậm treo toàn bộ health HTTP.
- Nghiệm thu bằng fake adapter/unit và runtime fixture; production không có số liệu mock.

### `backend/src/Presentation/Health/DatabaseReadinessCheck.cs` — Sửa

- Thay việc chỉ `CanConnectAsync` bằng `IDatabaseSchemaStatus`.
- Thiếu migration/bảng bắt buộc trả Unhealthy/503, không lộ SQL/connection string trong response public.
- Giữ `/health/live` độc lập. Không gọi migration hoặc Gemini trong probe.

### `backend/src/Presentation/Controllers/DeploymentHealthController.cs` — Tạo

- `GET /api/deployment/health`: báo cáo chi tiết được bảo vệ bằng quyền deployment riêng.
- `GET /health/version`: metadata công khai tối thiểu; SHA từ build/Render env đã validate, thiếu thì unknown.
- Controller chỉ gọi contract và map DTO/HTTP; không tự truy vấn EF/Kafka/Redis.
- Không dùng quyền owner của một nhà để cấp quyền xem toàn bộ hạ tầng.

### `backend/src/Presentation/Authorization/DeploymentHealthAuthorizationFilter.cs` — Tạo

- Kiểm tra deployment key chỉ đọc qua HTTPS/header riêng, so sánh constant-time, từ chối thiếu/sai key.
- Không log header, không nhận key qua URL/query string, không dùng lại AI service key.
- Không thay JWT auth của người dùng, không cấp quyền admin nghiệp vụ cho key health.

### `backend/src/Presentation/Health/DeploymentHealthOptions.cs` — Tạo

- Bind key/options timeout/cache; không có key mặc định hoạt động.
- Render giữ `DeploymentHealth__Key`; GitHub environment giữ `DEPLOYMENT_HEALTH_KEY` tương ứng cho CD.
- Chưa bật endpoint bảo vệ khi chưa có cấu hình hợp lệ; public health vẫn có contract tối thiểu.

### Các file đăng ký/config sẽ sửa

| File | Công việc | Nghiệm thu |
| --- | --- | --- |
| `backend/src/Presentation/Extensions/InfrastructureServiceExtensions.cs` — Sửa | DI cho schema/dependency implementation và options; reuse Kafka/Redis config hiện tại, chọn lifetime hợp lý. | Resolve được scope, không khởi chạy migration hoặc probe side effect lúc đăng ký DI. |
| `backend/src/Presentation/Extensions/PresentationServiceExtensions.cs` — Sửa | Đăng ký filter/options deployment, giữ auth/hubs hiện có. | Key sai không vào được báo cáo, user owner không tự có quyền hạ tầng. |
| `backend/src/Presentation/Program.cs` — Sửa | Health mapping/readiness/version, giữ PORT/0.0.0.0 và middleware/JWT hiện có. | Không thêm Database.Migrate vào startup; public error vẫn an toàn. |
| `backend/src/Presentation/appsettings.Deployment.example.json` — Tạo | Cấu trúc key trống và timeout mẫu; production dùng env. | Không có secret thực hoặc quyền bật mặc định. |

## 8. Python AI

| File | Thay đổi cụ thể | Liên kết và nghiệm thu |
| --- | --- | --- |
| `ai-service/app/main.py` — Sửa | Live chỉ process; ready gọi schema checker và trả 503 khi thiếu schema; không lộ SQL/stack trace. Giữ house/actor/service auth ở API nghiệp vụ. | Không gọi Gemini mỗi probe; provider_configured không có nghĩa provider hoạt động. |
| `ai-service/app/readiness.py` — Tạo | Checker nhỏ dùng engine hiện có, đọc Alembic revision/required tables, timeout/reasonCode; hỗ trợ revision graph. | Không create_all/upgrade, không tạo engine mới liên tục. Main gọi checker, tests kiểm tra read-only. |
| `ai-service/app/config.py` — Sửa có điều kiện | Thêm health timeout/version cần thiết, validate options; giữ SecretStr và Kafka TLS. | Không in settings đầy đủ hay hardcode DB/key production. |
| `ai-service/Dockerfile` — Rà/sửa có điều kiện | Python/dependency pin, context sạch, CMD chỉ API đúng PORT sau khi tách migration. | Docker build đạt; phải sửa cả Docker Command override đang lưu trên Render khi chuyển quy trình. |
| `ai-service/app/worker.py` — Sửa ở đợt full | Entry point riêng, shutdown/retry/offset giữ nguyên tính đúng; thêm heartbeat thực khi nơi lưu tín hiệu được chốt. | Idle khác dead; API không phát heartbeat giả thay worker. |
| `ai-service/app/trainer.py` — Sửa ở đợt full | Chốt daemon/scheduled, deadline/lần chạy và artifact storage bền vững. | Không train vì request health, không coi filesystem Free instance là model storage bền vững. |

Nếu chưa deploy worker/trainer ở đợt đầu, inventory ghi đúng chưa triển khai; không biến thành một phần của Uvicorn.

## 9. Frontend, build và proxy

### `mobile/scripts/build-render-web.sh` — Tạo

- Script dùng chung CI và host FE: kiểm tra/cài Flutter pin, pub get, build release và sinh `build/web/deploy-version.json` chứa SHA công khai. File sinh ra thuộc artifact, không commit bản build vào source.
- API/SignalR URLs là cấu hình public được validate HTTPS; không localhost ở bản cloud.
- Static Site dùng `USE_SAME_ORIGIN=false` và backend URL thật.
- Không đưa Gemini/payOS/backend secret vào dart-define vì bundle frontend có thể đọc được.
- Nghiệm thu: cùng SHA/config tạo artifact dùng đúng API/hub, asset và route reload hoạt động.

### `mobile/Dockerfile` — Sửa

- Bỏ `flutter upgrade` trôi, pin cùng version với CI; fail rõ khi SDK không cài được.
- Không ép same-origin cho mọi môi trường; build flags cloud/local có chủ đích.
- Không fallback sang backend local khi URL thiếu; cấu hình sai làm build/validation fail.

### `mobile/nginx.conf` hoặc `mobile/nginx.render.conf.template` — Theo phương án host

- Static Site: giữ nginx cho local, không tạo cấu hình proxy không được dùng.
- Container FE: template Render riêng, upstream cloud/env được validate, HTTPS/SNI/Host/WebSocket Upgrade đúng.
- Không thay nhầm hostname Docker local cho mọi người dev; cloud không tự có service `backend:8080`.
- Kiểm tra SPA fallback, cache assets/version, upload limit và request qua proxy thật.

### `mobile/lib/core/constants/app_constants.dart` — Rà/sửa có điều kiện

- Giữ mặc định Render đã sửa; release validation/same-origin phải khớp build script.
- Không hardcode container name/local host vào bundle cloud hoặc fallback local khi cloud lỗi.
- Nghiệm thu bằng test cấu hình URL, không bỏ validation để build xanh.

### `mobile/README.md` — Sửa

- Phân biệt FE local/FE cloud, build overrides, restart khi đổi compile-time config.
- Ghi rõ deploy backend không cập nhật frontend; dẫn tới runbook và cách kiểm tra SHA FE.

## 10. Test files sẽ tạo hoặc sửa

| File | Ca kiểm thử phải có |
| --- | --- |
| `scripts/ci/tests/test_check_results.py` — Tạo | Thiếu/rỗng/report lỗi format, failed, required skip, skip có lý do; không pass giả khi chưa test. |
| `scripts/ci/tests/test_render_deploy.py` — Tạo | 200/202, timeout sau POST, queue, SHA sai, 401/404/429/fail/cancel/live; URL/header secret không vào output. |
| `scripts/ci/tests/test_schema_gate.py` — Tạo | DB trống/sai DB, thiếu history/bảng/revision, schema đúng; không gửi lệnh ghi. |
| `scripts/ci/tests/test_migration_manifest.py` — Tạo | EF/Alembic IDs/checksum/SHA, sửa migration cũ, revision graph và artifact không khớp. |
| `scripts/ci/tests/test_smoke_test.py` — Tạo | Old-version health, redirect, HTML gateway, cold start/timeout/503, sai FE API/hub origin. |
| `scripts/ci/tests/test_check_release.py` — Tạo | Required unverified/fail chặn release, optional degraded báo đúng, core không biến thành full. |
| `backend/tests/IntegrationTests/Infrastructure/DatabaseReadinessTests.cs` — Tạo | Kết nối DB được nhưng thiếu Users/AIChatInsights trả 503; schema đúng ready, không tự tạo bảng. |
| `backend/tests/IntegrationTests/Infrastructure/DeploymentHealthTests.cs` — Tạo | Key thiếu/sai bị từ chối, key đúng có report hạn chế; public output không lộ secret. |
| `backend/tests/IntegrationTests/Infrastructure/AIServiceContractTests.cs` — Sửa | Contract với Python fixture, không cần Gemini production hoặc key người dùng. |
| `backend/tests/IntegrationTests/Infrastructure/WorkerProcessHarness.cs` — Rà/sửa | Đúng DLL/configuration trên Linux runner; log test-only, không credential cloud. |
| `ai-service/tests/test_readiness.py` — Tạo | Live nhưng DB lỗi/schema thiếu, Alembic đúng/sai, timeout; health không gọi Gemini thật. |
| `ai-service/tests/test_worker_health.py` — Tạo đợt full | Worker thực cập nhật tín hiệu, idle/stale/dead khác nhau, API không giả heartbeat. |
| `mobile/test/core/shared_web_configuration_test.dart` — Sửa | HTTPS API/hub, same-origin đúng mode, chặn cấu hình local sai, version/config artifact. |

Test mô phỏng failure chỉ nằm trong test harness; báo cáo production không dùng kết quả mock.
Test outage chỉ pause container CI riêng, không thao tác broker Aiven hoặc container local của người dùng.

## 11. Tài liệu và file bảo vệ dữ liệu riêng

| File | Công việc cụ thể |
| --- | --- |
| `docs/testing/github-actions-render-cicd.vi.md` — Tạo | Runbook secrets/variables/environments, Render hooks/health paths, chạy local, activate, rerun SHA, đọc log, migration/backup/rollback, nghiệm thu tắt Docker. Không chứa secret thật. |
| `docs/plans/github-actions-render-cicd-plan.vi.md` — Sửa theo tiến độ | Trạng thái từng đợt, SHA, inventory, bằng chứng; phần chưa test giữ unverified, không dùng kế hoạch thay báo cáo PASS. |
| `docs/plans/README.md` — Sửa | Link kế hoạch/phụ lục/runbook, phân biệt đang lập kế hoạch, CI chạy được và CD đã nghiệm thu. |
| `.gitignore` — Rà/sửa nếu thiếu | Chặn env thật, key, certificate riêng, dump/token/media/log; cho phép file ví dụ trống cần thiết. |
| `backend/.dockerignore` — Rà/sửa nếu thiếu | Không copy appsettings local/private media/keys/dumps; không exclude nhầm migrations/source. |
| `ai-service/.dockerignore` — Rà/sửa nếu thiếu | Không copy env, artifacts riêng, DB, caches; giữ lockfile/migrations cần build. |
| `mobile/.dockerignore` — Rà/sửa nếu thiếu | Không copy secrets/build outputs thừa; FE không chứa server keys. |

Cache/artifact selection của workflow cũng phải loại dữ liệu riêng; `.gitignore` không tự bảo vệ GitHub cache.

## 12. Thay đổi ngoài repository

| Nơi | Việc cần cấu hình | Gắn với file |
| --- | --- | --- |
| GitHub Actions/ruleset | Workflow permissions tối thiểu, fork policy, required `ci-required`, main/PR policy do owner chốt | `ci-cd.yml` |
| Environment `production` | Hook/API/health secrets, service IDs/URLs, chỉ main | Deploy/smoke scripts và health endpoint |
| Environment `production-db` | Reviewer, credential migration tách biệt, backup policy | `db-migrate.yml` |
| Render backend | Health path, deployment health key, env/SASL/CA/PORT đúng, commit thực đang Live | Program/health/options |
| Render AI | Database AI tồn tại/schema, command phù hợp khi tách migration, health path | Python readiness/Dockerfile |
| Render frontend | Chốt host, build command/public URLs/SPA routing, hook/service ID | Mobile build/proxy |
| Aiven | Topics/permissions/group, canary riêng nếu cho phép | Dependency/runtime checks |
| Storage | Nơi lưu bền vững, chuyển file ảnh/voice, quyền đọc đúng nhà | Media/profile full |
| Worker/trainer cloud | Service/job, heartbeat/lịch, artifact storage | Worker/trainer/inventory |

Không có YAML nào tự thay thế việc tạo DB AI, cấp quyền hoặc chuyển media.
Không tạo dịch vụ trả phí hay đổi gói chỉ vì có entry dự kiến trong inventory.

## 13. Luồng gọi giữa các file

```text
ci-cd.yml → docker-compose.ci.yml → tests/build source
         → check_results.py → ci-required
         → migration_manifest.py + schema_gate.py (main, read-only)
         → render_deploy.py → Render hook(ref=SHA) → Dockerfile/service
         → Render API đối chiếu deploy ID/SHA/Live
         → smoke_test.py → backend/AI health + FE routes
         → check_release.py → JSON/Markdown Summary + last-known-good

Backend readiness → IDatabaseSchemaStatus → DatabaseSchemaStatus → DB read-only
DeploymentHealthController → authorization filter → IDependencyHealthService
                          → DependencyHealthService → schema/Kafka/Redis/AI/media snapshot
AI main.py /health/ready → readiness.py → Alembic/table checks read-only

db-migrate.yml → review/approval + manifest/hash/backup
              → migrate_database.sh → EF/Alembic apply
              → schema_gate.py → rerun CI/CD đúng SHA
```

## 14. Thứ tự thực hiện và bàn giao

| Đợt | Nhóm file | Điều kiện hoàn thành |
| --- | --- | --- |
| 1 — CI | Workflow, compose CI, SDK/tool pins, result checker/tests | PR fail/pass tái hiện được; required tests không skip ngoài dự kiến. |
| 2 — Health | Contracts/DTO, implementation, controller/filter/options, Python readiness/tests | Thiếu bảng không ready, quyền health đúng, probe không có side effect. |
| 3 — CD | Inventory, manifest/schema gate, deploy/smoke/release scripts/tests | Đúng SHA/Live, queue/retry/failure và report được kiểm chứng bằng fixture. |
| 4 — Bootstrap cloud | DB AI, media, worker/trainer, host FE và config bên ngoài | Từng dependency có bằng chứng, chưa đủ thì không báo full. |
| 5 — Activate | GitHub secrets/environments/ruleset, Render hooks/health, runbook | Main pass tự deploy, PR không deploy, migration vẫn có bảo vệ. |
| 6 — Nghiệm thu | Reports, rollback drill, kiểm tra độc lập local | Có SHA/deploy ID/test/health evidence; tắt Docker local vẫn đạt profile đã công bố. |

Mỗi PR bàn giao ghi rõ file nào đổi, behavior trước/sau, test đã chạy, config/migration ảnh hưởng,
caller/callee và phần chưa nghiệm thu. Không gọi toàn bộ hạ tầng đã sẵn sàng chỉ vì YAML build đạt.
