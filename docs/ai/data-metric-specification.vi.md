# Data & Metric Specification — v1

Cập nhật 23/10/2026. Đây là đặc tả contract của source hiện tại, bổ sung [mục 2/3.3/6.5/10.6 của plan](../plans/ai-python-full-implementation-plan.vi.md). Không phải chứng nhận nghiệm thu dữ liệu gia đình thật.

## Nguồn, thứ tự và quyền

Core PostgreSQL là nguồn nghiệp vụ. `AITelemetryCapture` ghi event và tăng sequence theo nhà trong cùng transaction; Kafka chỉ chuyển sau commit. Event schema v1 có `event_id`, `house_id`, `house_sequence`, `entity_id`, `recorded_at`, `occurred_at`, `capture_batch_id`, `batch_last_sequence`, `data_source`, payload. Unique event và house/sequence ngăn đếm trùng; batch tail/prefix phát hiện thiếu dữ liệu. Event đến muộn không đổi feature lúc nhận trách nhiệm.

Snapshot trách nhiệm mới chụp atomically tại StartedAt. Trách nhiệm legacy thiếu snapshot giữ MISSING_SOURCE_SNAPSHOT, không lấy trạng thái hôm nay điền ngược. Source sequence giải thứ tự event cùng thời điểm. Không dùng ID người/nhà/episode/occurrence làm feature.

`preference`, `availability`, `availability_exception` có `deleted=true` khi Core xóa row. Tombstone vẫn là event upsert có sequence; không có nghĩa người dùng không thích hoặc không rảnh. Preference lưu thêm tên việc và root template reference. Thay sở thích qua service hiện có có thể xóa rồi thêm row mới; đó không mặc định là hai phản hồi mới.

Public contribution chỉ có facts nghiệp vụ. Lịch sử khai báo sở thích và evidence của nó chỉ trả cho chính actor. Private chat/AI inference chưa xác nhận không xuất hiện trong contribution hoặc tabular dataset. Tắt consent xóa dẫn xuất chat, không xóa nghiệp vụ đã được người dùng xác nhận.

## Contract hồ sơ

`behavior.py`: `contribution-v3`; `profile_metrics.py`: `contribution-metrics-v1`. Scalar cũ được giữ để tương thích; `items[].metrics` cung cấp metadata riêng từng metric.

| Trường | Ý nghĩa |
|---|---|
| `value`, `numerator`, `denominator` | Giá trị và phép đo; denominator 0 trả rate null |
| `sample_count` | Số đơn vị quan sát đúng bài toán; không dùng tổng phút làm số mẫu |
| `evidence_count`, `evidence_ids` | Số reference và event cần mở để giải thích; có thể nhiều event cho một sample |
| `period`, `season_id`, `as_of` | Cửa sổ all-time/30d/90d/season, cutoff nguồn |
| `source`, `definition_version`, `profile_version` | CORE_TELEMETRY, công thức và hash hồ sơ cụ thể |
| `quality`, `status`, `data_status` | Thiếu quan sát/thiếu mẫu/tạm tính khi telemetry chưa đủ |
| `coverage_scope` | OBSERVED_TELEMETRY_ONLY, không hứa ghi nhận toàn bộ đời sống trước khi có telemetry |

| Metric | Đơn vị / công thức | Sample và bằng chứng |
|---|---|---|
| `completed_count` | Số occurrence actual completer đã hoàn thành | Một occurrence một lần; event occurrence |
| `standard_minutes` | Tổng SnapshotMinutes 15/30/45 | Sample = số completion, không phải số phút |
| `snapshot_karma` | Tổng SnapshotKarma của completion | Tách ledger penalty/bonus/spend, không thay số dư |
| `responsibility_count` | Số episode bắt đầu trong cửa sổ | Episode source, không đồng nhất số việc hoàn thành |
| `on_time_episode_rate` | On-time / (on-time + late đủ điều kiện) | Pending/censored báo riêng; episode và occurrence xác định outcome |
| `bounty_claim_count` | Lượt episode bắt đầu với reason BOUNTY | Không phải lượt thanh toán hoặc completion |
| `bounty_occurrence_count` | Occurrence khác nhau đã nhận qua bounty | Nhiều episode cùng việc chỉ một occurrence |
| `bounty_self_completion_rate` | Self / (self + other completed) | Pending/overdue-open/cancelled/unknown không biến thành nhãn âm |
| `bounty_posted_count` | Số bounty đã đăng | Event bounty, tách amounts khỏi phẩm chất/motive |
| `mean_normalized_rank` | Trung bình `1-(rank-1)/(memberCount-1)` | Chỉ mùa memberCount >=2 |

Mỗi metric chỉ kèm lineage liên quan. Ví dụ 2 completion, mỗi việc 30 phút và một penalty: standard_minutes=60, sample_count=2, evidence của metric chỉ là hai completion; penalty vẫn ở ledger breakdown. Rate chưa có episode đủ outcome là null/0 mẫu, không hiển thị 0% như đo được thất bại.

## Lịch sử khai báo sở thích

`preference_history.py`, version `declared-preference-history-v1`, tách khỏi contribution. Theo `(member, chore/template)` và source sequence, chỉ ghi một tín hiệu mới khi loại khai báo thay đổi; lần đầu là một tín hiệu. Lưu lại cùng loại, kể cả xóa/thêm lại bởi service replacement, không tăng sample. Xóa là CLEARED; không cộng negative. Delete row cũ không xóa state của row mới.

`smoothed_positive_score=(positive+1)/(positive+negative+2)` chỉ khi cửa sổ có sample, không có sample trả null. Đây là tóm tắt các lần khai báo, không phải preference suy từ hành vi, confidence hoặc xác suất nhận bounty. `uncertainty_status=NOT_COMPUTED`. Current declaration lấy latest known tại cutoff và báo scope riêng, nên một preference cũ vẫn là current nhưng không tạo sample giả cho 30 ngày gần nhất.

Preference hiện thuộc nhà/chore, không có season foreign key. Khi chọn mùa, chỉ hiển thị current declaration với `HOUSE_DECLARATIONS_NOT_SEASON_SCOPED`; không tự gán lịch sử đó vào mùa. Source effective_at sau cutoff không ảnh hưởng current tại cutoff.

## Bằng chứng kiểm thử

`test_profile_contract.py`: sample/lineage, dedup replacement, clear/obsolete delete, effective cutoff, cửa sổ, quyền đọc riêng, metric PROVISIONAL khi thiếu watermark. `test_store_profiles.py`: occurrence/bounty không cộng trùng. `AIHousekeeperTests.ReplacingAndClearingPreferencesKeepsDeletionEvidenceInAtomicOutbox`: service thật và PostgreSQL. Flutter có widget tests cho null rate/denominator và cleared khác dislike.
