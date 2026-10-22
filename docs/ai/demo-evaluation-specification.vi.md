# Demo & Evaluation Specification — v1

Bổ sung [mục 4/8/9/10 của plan](../plans/ai-python-full-implementation-plan.vi.md), cập nhật 23/10/2026. **Trạng thái đặc tả: DRAFT cho nghiệm thu cuối.** Các pilot đã xem kết quả là exploratory. Chưa có lock manifest chứng minh VALIDATION_LOCKED → TEST_LOCKED trước holdout; không hồi tố đánh dấu các run cũ là đã khóa.

## Dataset và scenario

Demo chạy business services C#, fake clock nội bộ và database disposable prefix `cw_ai_demo_`; không sửa SQL để tạo nhãn/điểm/rank. Mỗi seed là một nhà độc lập: 6 người, 14 mùa <=31 ngày, 6–10 occurrence/ngày. Marker DEMO_SYNTHETIC đi theo export, dataset, evaluation và model. Oracle không làm feature.

Plan yêu cầu thay ca tháng7, đổi xu hướng tự nguyện tháng9, giảm capacity tháng11, chuyển/bounty/actual completer khác nhau, late/penalty/payment/pass và nhiễu/missing observations. Một hành động không qua business validation phải được ghi là không đủ điều kiện; không bịa request hoặc completion. Kiểm tra coverage của từng scenario trong export trước khi đánh dấu cohort đạt plan; có file export không tự chứng minh đủ scenario.

## Các phép so sánh

| Arm | Dữ liệu và thuật toán |
|---|---|
| B0 | Baseline greedy parity Core, cùng frozen context |
| S0 | Cùng best-improvement search, không dùng history |
| H1 | Cùng search, thêm kinh nghiệm từ quá khứ để phá hòa, capped20 |

Search gain=S0−B0; history gain=H1−S0; total=H1−B0. H1 không khác S0 thì chưa có bằng chứng lịch tốt hơn nhờ history. Không thay bằng tuyên bố số event/profile đã tăng.

Budget-complete xét tối đa10.000 neighbor, không time limit. Serving có timeout optimizer4 giây và fallback baseline; còn cần đo end-to-end theo mục tiêu5 giây. Không trộn modes và không dùng benchmark budget chứng minh SLA. Constraint/capacity/lịch rảnh/locked bookings là hard rules, không nới để tạo cải thiện.

## Gate và cách đọc

Material schedule gate: coverage tăng >=1 task; hoặc Karma gap giảm >=10% và >=1 Karma; hoặc declared preference alignment tăng >=10 điểm phần trăm và >=1 task. Đồng thời giữ hard constraints, coverage, fairness và không tăng disliked/đổi fixed assignments. Rotation-only hoặc risk-only không tự đạt promotion gate v1.

Metrics luôn có numerator/denominator, sample/cohort/window/exclusions, version, cutoff/source sequence và references tới lịch. Zero denominator trả null. Rate delta báo điểm phần trăm riêng với relative delta. Chỉ số inferred preference không là ground truth tự chấm AI.

Outcome giảm late/request chỉ được kết luận khi có outcomes đúng policy thực sự đã thực hiện, đủ cửa sổ và specification phù hợp. Lịch counterfactual từ simulator hiện không có observed outcomes tương ứng: NOT_OBSERVED, không sao chép kết quả baseline.

## Tái lập và aggregation

Tool `backend/tools/AIDemo/run-cohort.ps1` chạy seed42..61 riêng. Tháng1–3 readiness/folds,4calibration,5Aselection,5Bthreshold; tháng6–14 frozen. Mỗi evaluation immutable, có context/dataset/profile/policy/metric versions, scenario/seed/mode/budget. Đổi profile v3 không ghi đè run v2.

Chỉ bootstrap CI95 khi đủ20 seed tương thích, có đủ tháng6–14; 10.000 bootstrap samples theo independent seed, không coi các task cùng nhà là độc lập. Partial cohort trả PARTIAL, không tạo CI giả. Báo toàn bộ seed, gồm không cải thiện và lỗi.

## Bằng chứng và phần còn thiếu

Pilot seed44 đã có14 mùa/22.777 event; offline budget42 run cho B0/S0/H1. Tám mùa search cải thiện gap15→9, coverage100%; H1/S0 cùng metrics. Chỉ1/20 seed và chưa chứng minh lợi ích history/production model/SLA. Các run là bằng chứng phiên bản tại thời điểm chạy.

Trước nghiệm thu cuối cần kiểm tra scenario coverage, đóng code/config/spec hashes và lock audit trước một holdout phù hợp, chạy đủ cohort ở hai modes, nghiệm thu dashboard trên dữ liệu runtime thực và provider/device riêng. Màn dashboard và metric đẹp không thay evidence về chất lượng Gemini, camera/micro/loa hoặc product pilot.

Giữ trạng thái A–K theo [báo cáo triển khai](../reports/ai-implementation-status-2026-10-22.vi.md). Không dùng ba file đặc tả này để đánh dấu các phần chưa code/chưa chạy thành hoàn tất.
