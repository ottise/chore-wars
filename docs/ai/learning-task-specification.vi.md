# Learning Task Specification — v1

Đặc tả triển khai của [mục 3 và 10 trong plan](../plans/ai-python-full-implementation-plan.vi.md), cập nhật 23/10/2026. Quyết định chọn model nằm trong training report; tài liệu này không tuyên bố có model production.

| Target | Đơn vị / mục tiêu | Nơi dùng và giới hạn |
|---|---|---|
| T0 | Actual completer, effort/Karma, responsibility/bounty/ledger/rank | Hồ sơ và giải thích; aggregation có bằng chứng, không cần train |
| T1 | Episode thực tế tại StartedAt; dương = trễ deadline | Thử nghiệm risk insight cho episode đã nhận; không score ứng viên chưa được giao |
| T2 | Episode thực tế; dương = self-request điều chỉnh trong responsibility window | Experiment/shadow; không có production claim giảm request |
| T3 | Hồ sơ thay đổi theo cửa sổ; khai báo/kinh nghiệm có provenance | Descriptive profile; chưa có behavioral predictor hoặc adaptation-lag label hợp lệ |

## Feature và label

`dataset.py` dựng feature từ source snapshot đã chụp trong Core transaction. Mỗi fold chỉ nhận labels đã đủ outcome tại fold cutoff; preprocessing cũng fit riêng từng fold. Identity không làm feature; chore/template chỉ biểu diễn loại việc.

`labels.py` hiện thực bảng quyết định của plan: tự hoàn thành đúng deadline là T1=0, sau deadline là 1; overdue còn trách nhiệm chỉ thành 1 khi cutoff > deadline và nguồn đầy đủ. Transfer trước/đúng deadline chưa tự complete là censored; không sao chép label của người hoàn thành sau sang người nhận trước. Cancel/skip/deadline đổi/legacy thiếu snapshot/stream thiếu không thành negative. T2 chỉ xét request của chính assignee, trong `[StartedAt, min(EndedAt, Deadline)]`; request bị từ chối vẫn là một request. Window chưa đóng giữ pending, không ép 0.

Không train duration, ai sẽ nhận bounty, tính cách, động cơ hay quality từ vision. Completion/open signal không tạo preference label. Các công thức contribution và lịch sử khai báo nằm trong [Data & Metric Specification](data-metric-specification.vi.md).

## Thuật toán và cấu hình

Source `ml.candidates()` là tập thực nghiệm 14 cấu hình:

| Họ | Cấu hình |
|---|---|
| B0 | Empirical prior |
| B1 | Smoothing alpha 5 hoặc 20 |
| Logistic | C 0.1, 1, 10; lbfgs, max_iter 1000 |
| Random Forest | 200 trees, depth 4/8 × min leaf 5/10, sqrt, seed 42, một worker |
| Histogram Gradient Boosting | learning rate .05/.1 × leaf nodes 7/15, 100 iterations, min leaf 20, l2=1, seed42, early stopping off |

Numeric imputation median/missing indicator chỉ fit trên train. Logistic scale; RF không scale. One-hot bounded/unknown ignore. HGB ordinal có tối đa 31 category biết, unknown=-1, missing=-2; không mô tả nó như native categorical.

## Chọn và sử dụng

Forward folds tháng 1→2 và 1–2→3; tháng4 calibration, 5A chọn cấu hình, 5B chọn threshold, 6–14 frozen walk-forward. Primary predictive metric Brier; kiểm tra PR-AUC/noninferiority, calibration và data readiness. Cấu hình đơn giản hơn được ưu tiên nếu khác biệt Brier trong biên 1% đã đặc tả. Không ép Random Forest thắng.

Offline có thể exploratory khi hai lớp xuất hiện. Product data gate dự kiến: train >=500, mỗi lớp >=50; calibration >=100, mỗi lớp >=20; holdout mỗi lớp >=20. Brier giảm >=5% so baseline, PR-AUC không giảm, ECE 5 bins <=.1 với >=20 mẫu/bin. Grid threshold .05..95 bước .05; chọn recall cao nhất thỏa precision>=.7, recall>=.5, FPR<=.1; hòa chọn threshold cao hơn. Không đạt trả null.

Refit recipe giữ cấu hình/threshold trong test, chỉ dùng quá khứ, >=50 label mới và calibration riêng ở mùa quá khứ gần nhất. Durable trainer tạo candidate, không auto-promote. Registry còn yêu cầu product evidence đúng house/artifact/data source/capability và operational gate. Dữ liệu synthetic không tự trở thành bằng chứng REAL.

Training reports lưu config/folds/cutoffs/readiness/prediction metrics/decision, model artifact hash và feature schema. Giữ cả kết quả thất bại. Pilot seed44 hiện chưa có candidate đủ điều kiện production; kết quả thuộc phiên bản source đã chạy, không được sửa report cũ khi thay profile v3.
