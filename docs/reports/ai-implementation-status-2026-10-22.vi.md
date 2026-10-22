# AI Housekeeper — triển khai và bằng chứng kiểm chứng

Cập nhật đến **23/10/2026**, tiếp tục phiên triển khai bắt đầu 22/10. Đọc cùng [plan hiện hành](../plans/ai-python-full-implementation-plan.vi.md) và [hướng dẫn chạy](../../ai-service/README.md). Báo cáo này phân biệt source đã có, kết quả thực thi và nghiệm thu còn thiếu; không đánh dấu toàn bộ A–K đã nghiệm thu.

## 1. Source đã triển khai

| Nhóm | Python | Core / Flutter | Giới hạn nghiệm thu |
|---|---|---|---|
| Telemetry và hồ sơ | Inbox idempotent, source sequence/batch completeness, facts/profiles theo cửa sổ, evidence | Snapshot tại transaction nhận trách nhiệm, outbox Kafka; task/bounty detail open có request ID riêng; màn hồ sơ và truy bằng chứng | Open signal không chứng minh đọc, preference hoặc từ chối; chưa có viewport impression |
| Phân công | Baseline parity C#, local search B0/S0/H1, hard guards, fairness/preference gate và fallback | Đề xuất nháp → xem → apply → quy trình duyệt mùa hiện có | Lịch cả tháng vẫn có thể hết deadline; trả baseline và lý do, không claim cải thiện khi fallback |
| Prediction và habit | T1 observed-episode risk, T2 shadow, feature/label tại cutoff, experience theo template | Insight riêng cho trách nhiệm đang nhận; không tự penalty hoặc tự giao thêm | Chưa có approved model; profile thống kê không được gọi là model tự train |
| NLU / chat | Gemini schema/reference/quote validation, candidate BUSY/FREE có trường thiếu | On-demand và private chat queue opt-in; màn sửa ngày/giờ trước xác nhận | Chưa gọi Gemini thật do chưa cấu hình key; chưa nghiệm thu ngôn ngữ thực tế |
| Voice | Dùng STT/TTS của thiết bị, gửi transcript đã chỉnh qua Core | Microphone/loa, trạng thái phiên/quyền/cancel | Chưa thử trên điện thoại Android thật |
| Swap / replan | Đổi việc hợp lệ, sắp lại giờ/người tương lai, không đổi việc bị khóa | Existing swap proposal; SCHEDULE_REPLAN cần owner và người bị ảnh hưởng, kiểm tra revision/context trước khi apply | Đã kiểm chứng PostgreSQL đồng thuận/atomicity; chưa nghiệm thu trên điện thoại |
| Availability | Context override theo ngày, phát hiện locked booking xung đột | DRAFT cập nhật khai báo; ACTIVE preview → đồng thuận → availability + lịch cùng transaction | Không coi candidate từ chat là lịch chính thức |
| Season evolution | Dùng hồ sơ trước cutoff, cùng guardrails/công bằng | Chỉ nguồn COMPLETED cùng nhà, đích DRAFT, vẫn duyệt mùa | Kinh nghiệm chỉ phá hòa; không hứa lịch thay đổi lớn chỉ vì profile thay đổi |
| Bounty | Gợi ý tự nguyện theo lịch rảnh, preference và kinh nghiệm; contribution/outcome riêng | Board/detail hiện có, không tự nhận/push theo người hay nhận | Không train acceptance predictor, không tăng quota, không tích hợp payOS |
| Blitz | Microtask DAG, resource/member timeline, thiếu dữ kiện/infeasible rõ | Preview → URGENT_EVENT consensus, cùng rule Core, effort chuẩn và Karma mặc định 0 | Decomposition thật còn cần provider key và kiểm thử thực tế |
| Vision / evidence | Advisory schema, MIME/content/size validation, không tự complete | Upload riêng tư/idempotent → advisory tùy chọn → người dùng complete attach evidence atomically | Camera thật/provider chưa nghiệm thu; cần theo dõi orphan file nếu storage ghi xong nhưng DB transaction thất bại |
| ML / evaluation | 14 cấu hình, temporal folds, calibration/threshold, walk-forward/refit, trusted registry, immutable runs/bootstrap | Owner dashboard: timeline, metric mẫu số, B0/S0/H1, examples, training reports, aggregates | Product gate/pilot chưa có; 20 seed chưa chạy đủ |

## 2. Kiến trúc và các thay đổi nghiệp vụ đáng chú ý

- Python có PostgreSQL riêng. C# giữ Core DB và quyền thay đổi nghiệp vụ; Flutter chỉ gọi C#.
- `AIResponsibilityContextSnapshot` chụp workload, lịch rảnh, preference, constraints, history và deadline tại transaction nhận trách nhiệm. Kafka đến muộn không làm dùng state tương lai.
- Snapshot dùng cả availability exception mới đang chờ save trong chính transaction replan. Trách nhiệm đã tồn tại trước khi bật telemetry mà không có snapshot giữ trạng thái thiếu dữ liệu; không lấy state hiện tại để điền feature quá khứ.
- Telemetry có house sequence và batch tail. Thiếu prefix/tail thì không tạo nhãn chắc chắn hoặc train trên stream thiếu. Projection nhận out-of-order không ghi đè state mới bằng state cũ.
- Availability của mùa ACTIVE và đổi lịch dùng chung `ScheduleChangePayload`; proposal được duyệt mới ghi toàn bộ. Owner, người đổi availability và mọi người bị đổi việc đều thuộc tập cần xác nhận. Core kiểm tra lại tại lần xác nhận cuối.
- `allocation-v2` giữ mục tiêu/guardrails và thứ tự deterministic, tối ưu bằng cache lịch và tính delta cho neighbor. Unit test đối chiếu delta với công thức đầy đủ qua nhiều tuần, preference, experience và churn. Repair constraint do availability là capability replan; không gọi đó là bằng chứng học hành vi.
- Chat auto-insight dùng durable queue **Core PostgreSQL**, khác phương án chat Kafka ban đầu. Raw chat không đi topic telemetry; quyền, consent version, retry và xóa lineage được giữ ở Core. Python xử lý inference stateless cho adapter này.
- Failed event chưa xác định house chỉ ở operations. House đã xác thực mới có metadata owner-scoped; không trả raw payload. CLI replay chỉ ingest lại envelope gốc hợp lệ, không sửa source fact để vượt identity conflict.
- `AIObservations` lưu tín hiệu mở chi tiết task/bounty, server xác định actor/house/season, idempotent theo request ID. Flutter chỉ gửi sau frame có dữ liệu ở route hiện tại và không tái dùng view cũ sau đổi tài khoản. Nhà tắt AI thì không ghi observation mới. Source marker nói rõ OPEN_SIGNAL_ONLY; không thêm nhãn acceptance, không tự nhận bounty và không tăng nghĩa vụ. Dashboard chỉ báo số tín hiệu, không công khai log view cá nhân qua hồ sơ đóng góp. Occurrence ID là tham chiếu audit được kiểm tra lúc ghi, không có FK chặn xóa task nháp khi generate lại; regression PostgreSQL xác nhận lịch tạo lại được và observation vẫn còn.
- Model candidate không tự promote. Registry cần predictive gate + product evaluation độc lập, kiểm tra hash/feature/data source, fallback previous approved hoặc `NO_APPROVED_MODEL`.
- Bổ sung theo mục 2.3–2.5: hồ sơ `contribution-v3` có metadata và lineage riêng cho 10 metric chính (`contribution-metrics-v1`), đúng sample/denominator, unknown rate null và PROVISIONAL khi stream thiếu. Current/transition history của sở thích đã khai báo có dedup replacement, tombstone/clear và effective cutoff; không suy từ completion/open. History/evidence sở thích chỉ đọc bởi chính actor. Flutter có phần nguồn/mẫu/bằng chứng từng metric và phần khai báo riêng. Hash hồ sơ bao gồm cả lịch sử chuyển loại, không chỉ row mới nhất.
- Core ghi tombstone khi xóa preference/weekly availability/date exception. Kiểm thử service thật xác nhận chuỗi thích → không thích → xóa có đủ outbox events; chưa migrate schema Core thêm cho thay đổi payload này.
- Ba bộ đặc tả ở `docs/ai/` đã tách theo mục 10.6. Dictionary metric JSON được export từ source và có test đối chiếu; evaluation spec cuối vẫn DRAFT, chưa có lock manifest trước holdout. Không nâng các pilot cũ thành nghiệm thu đã khóa.
- Review trước merge phát hiện upload evidence cho DRAFT có thể tạo FK chặn generate lại. Upload mới nay kiểm tra mùa đã được duyệt và bắt đầu, cùng điều kiện thời gian/trạng thái của luồng complete. Regression PostgreSQL xác nhận DRAFT bị từ chối trước storage/DB insert và generate lại vẫn chạy; HTTP/JWT upload mùa ACTIVE và advisory vẫn pass. Docker build context cũng loại trừ `.env`/`.env.*`.

## 3. Kiểm chứng đã thực thi

| Kiểm tra | Kết quả quan sát |
|---|---|
| Build IntegrationTests và các project backend liên quan | Thành công, 0 error; còn warning NU1903 AutoMapper 12.0.1 của dependency hiện có |
| Backend unit tests | **70 passed** |
| Flutter tests hiện có | **18 passed**, thêm metric null/denominator và clear khác dislike; observation vẫn chống đếm trùng/đổi tài khoản |
| Python với PostgreSQL/Kafka thật và parity 14 mùa | **60 passed, 0 skipped**, gồm metric lineage/sample/contract, lịch sử khai báo/hash/quyền đọc, cùng toàn bộ label/optimizer/runtime regression |
| Flutter analyze `lib` | **No issues found** sau bổ sung observer và sửa cảnh báo braces |
| PostgreSQL AI + swap + Core/Python/evidence HTTP thật | **18 passed, 0 skipped** qua `ai-service/scripts/test-container.ps1 -SkipBuild`: 14 case AI, 2 case swap, 1 case xuyên luồng Python thật, 1 case evidence JWT/HTTP; gồm guard upload DRAFT mới |
| EF model / migration | `has-pending-model-changes`: không còn thay đổi model chưa có migration; có 5 migration Core AI mới, đã chạy trên DB kiểm thử riêng |
| Python Alembic PostgreSQL + retry | Pass trong bộ runtime; schema được đối chiếu metadata, event retry không nhân đôi |
| Kafka thật Python crash/restart/poison | Pass trong bộ runtime: crash sau commit DB, sau offset, restart không đếm đôi, malformed payload bị cách ly; tombstone có regression riêng |
| Kafka thật backend | **10 passed** trong lần full regression trên container disposable riêng |
| Full backend regression trước guard evidence mới | **70 unit passed; 46 integration passed, 1 skipped, 0 failed** qua `backend/scripts/test-runtime.ps1`, đã có profile v3. Case skip cần Python API riêng đã pass trong bộ container riêng; cả 6 PostgreSQL bắt buộc và 10 Kafka thực đều pass. Sau guard evidence, rerun bộ AI/HTTP/Core-Python **18/18** |
| Docker | Image Linux build thành công; migration/readiness/private auth/house scope pass; compose overlay `config --quiet` pass |
| Core ↔ Python qua HTTP thật | DRAFT → preview Python → Core apply → lưu 3 evaluation run → cả 3 thành viên duyệt → ACTIVE → complete → import outbox → hồ sơ ghi 1 completion/30 effort; pass |
| Evidence qua JWT/multipart/HTTP thật | JSON object `{evidenceId}` bind đúng; mock provider advisory không hoàn thành chore; **1 passed**. Provider thật vẫn chưa nghiệm thu |

Docker Engine từng dừng trong phiên, gây các TRX aborted/refused. Sau khi phục hồi, các kiểm thử trên đã được chạy lại trên tài nguyên riêng. Hai lỗi swap xuất hiện khi `now + 1 giờ` rơi ngay sau nửa đêm và không còn đủ 30 phút trong ngày deadline; fixture nay dùng ngày/giờ tương lai rõ ràng. Không nới constraint phân công để làm test pass.

Test container dùng source Python hiện tại mount read-only và dependency từ image Linux đã build. Core/Python contract chuyển **outbox đã commit qua endpoint import nội bộ cho kiểm thử**; Kafka được kiểm chứng riêng, không gọi test HTTP import là test delivery Kafka. Script tự tạo/xóa network, Core test databases, AI PostgreSQL và container API, không dùng database nhà thật.

Bằng chứng local trước merge (không commit dữ liệu/credential vào Git): `artifacts/runtime/53b1c0c257e54a80961591b59380c578/kafka/UnitTests.trx`, `artifacts/runtime/53b1c0c257e54a80961591b59380c578/kafka/IntegrationTests.trx`, `artifacts/ai-contract/d54022e5dddd42a488098753d897838a/ai-contract.trx`, `artifacts/ai-tests/779f226103c740bbaafacd07f24ca917/python.xml`; test Python nhận manifest `artifacts/ai-demo-year-fixed-44/manifest.json`. Flutter analyze lib/test không có issue, 18 tests pass; EF không có pending model change và compose overlay config pass. Không dùng TRX aborted/refused làm bằng chứng PASS.

## 4. Demo dài hạn và kết quả thực nghiệm

- Core demo **6 người, 14 mùa**, seed **44**, export **22.777 event**. Dynamic actions chạy qua application services C#: generate/review/activate, bounty/complete/payment, penalties, pass và season end. Kịch bản swap không đủ điều kiện được ghi riêng, không bịa request thành công hay nhãn T2.
- Python đã import và chạy B0/S0/H1 cho đủ 14 mùa trên database **SQLite kiểm thử offline** sau khi Docker mất kết nối. Đây là bằng chứng pipeline offline; không thay thế PostgreSQL nghiệm thu production.
- T1: **2.556 mẫu đủ nhãn**, 2.019 âm / 537 dương; 329 episode transfer bị censored. Thử nghiệm chọn **B0 empirical prior**, quality gate **false**, threshold **null**.
- T2: **2.885 mẫu đủ nhãn**, 2.774 âm / 111 dương; chọn **Logistic Regression**, quality gate **false**, threshold **null**, tiếp tục **SHADOW_ONLY**.
- Cả hai là kết quả thực nghiệm hợp lệ nhưng **chưa có learned model production**. Không dùng kết quả trên dữ liệu giả lập để khẳng định dự đoán đúng với gia đình thật.
- Lần đánh giá serving deadline dài hạn cho thấy optimizer vẫn fallback trên nhiều tháng; tổng hợp seed 44 hiện chưa chứng minh lợi ích lịch sử. Một benchmark riêng đã xét đủ 10.000 neighbor trong khoảng 3,9 giây và qua fairness gate; benchmark riêng không thay thế kết quả toàn cohort/SLA end-to-end.
- Đối chiếu **BUDGET_COMPLETE, allocation-v2** đã lưu đủ 42 run cho 14 mùa: 8/14 mùa S0/H1 cải thiện Karma gap từ **15 xuống 9** (giảm 40%), 6/14 mùa giữ baseline. Coverage cả ba arm đều **100%**. Trong cửa sổ frozen tháng 6–14, có **5/9 mùa** cải thiện gap. **H1 và S0 giống nhau ở toàn bộ metric đã lưu** trong seed này, nên cải thiện trên được quy cho search; chưa có bằng chứng lịch sử tạo lợi ích tăng thêm. Đây là đánh giá offline đủ move budget, không chứng minh SLA 5 giây và không phải kết luận trên gia đình thật.
- Tổng hợp hiện **PARTIAL, 1/20 seed**, không CI95, không claim giảm trễ/yêu cầu điều chỉnh. Không có outcome thực thi của lịch counterfactual, nên metric outcome đó là NOT_OBSERVED.

File local: `artifacts/ai-demo-year-fixed-44/evaluation-serving_deadline.json`, `artifacts/ai-demo-year-fixed-44/evaluation-budget_complete.json`, `artifacts/ai-demo-eval-offline-44.db`. Reports/model artifacts không chứa chứng cứ production và không đưa vào Git. Bản `allocation-v1` cũ được giữ trong Evaluation Store, không ghi đè khi đổi sang `allocation-v2`. Kết quả 14 mùa trên là checkpoint profile v2; source profile v3 bổ sung metric/khai báo đã được regression riêng, chưa chạy lại cả cohort và không ghi đè kết quả cũ.

## 5. Các bước còn phải thực hiện để nghiệm thu

1. EF/Alembic đã chạy trên DB riêng và full backend regression đã pass các case đủ cấu hình; cần quy trình backup/migration trước khi apply hệ thống thật. Chưa apply migration vào database người dùng.
2. Khởi động overlay AI cùng môi trường deploy thực tế và kiểm tra worker/trainer dài hạn. Build Linux, readiness, migration và Core/Python contract riêng đã pass; chưa deploy lại stack đang dùng của người dùng.
3. Cấu hình Gemini rồi nghiệm thu tiếng Việt, dữ kiện thiếu, reference sai, timeout và vision advisory. Key chỉ nằm server.
4. Android thật: camera upload/retry, STT microphone, TTS speaker, revoke quyền, app background, đổi tài khoản. Hiện chưa build/kiểm thử APK theo yêu cầu chỉ tập trung code.
5. Kiểm tra scenario coverage và tạo lock manifest có code/config/spec hashes trước một holdout phù hợp; hiện evaluation spec cuối còn DRAFT. Sau đó chạy `backend/tools/AIDemo/run-cohort.ps1` cho đủ 20 seed độc lập; phân biệt serving/budget-complete và có resource/time budget. Nếu kết quả không đạt, giữ baseline và báo chưa cải thiện; không sửa ngưỡng sau test.
6. Product pilot cho đúng phiên bản artifact với người dùng/consent, delivered cohort và operational gates; chưa có dữ liệu này thì registry không promote.
7. Nếu mở rộng claim sang viewport impression, dwell/read hoặc inferred preference/uncertainty, cần định nghĩa và instrument riêng. Hiện có open signal và lịch sử preference khai báo tường minh; không coi thiếu signal là negative, không gọi score làm trơn là confidence và không train acceptance model.

Phiên kiểm tra trước commit/merge ngày 23/10/2026 không có test failure trong các bộ trên. Còn cảnh báo bảo mật AutoMapper 12.0.1 có sẵn và deprecation httpx/TestClient; không gọi kết quả này là bảo đảm zero-bug hoặc nghiệm thu provider/device. Không có thay đổi payOS hoặc thông tin ngân hàng; dữ liệu demo, model artifacts và credential local không đưa vào Git. Commit/nhánh hiện hành tra từ Git.
