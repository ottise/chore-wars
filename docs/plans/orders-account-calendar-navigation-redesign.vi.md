# Plan chỉnh Order, My Account, Chore và lịch Overview

Ngày: 28/10/2026. Đối chiếu source `987ba3f` và 9 ảnh người dùng cung cấp.
Trạng thái 28/10/2026: **đã triển khai source và kiểm thử local; chưa áp dụng migration/config SMTP lên Render**. Cách cấu hình và giới hạn nghiệm thu: [Order email setup](../order-email-setup.vi.md). Manifest dưới đây là thiết kế ban đầu; test thực tế được gộp trong `house_navigation_test.dart`, `supplies_flow_test.dart`, `household_calendar_test.dart`, `SimpleOrderCalendarTests.cs`, `OrderEmailTransportTests.cs` và `EvidenceThumbnailTests.cs`.

Cập nhật theo yêu cầu mới nhất: **Order là luồng tự đặt đơn giản: chọn số lượng → Send email cho nhà cung cấp → ghi nhận đã thanh toán → lưu log.** Không bắt nhà cung cấp đăng nhập, không bắt các thành viên khác duyệt đơn/chia phần; SMS là mở rộng tương lai. Quy tắc này thay phần review/approval bắt buộc trong bản plan trước.

## 1. Chốt bố cục và phạm vi

| Khu vực | Thiết kế sau chỉnh |
|---|---|
| Bottom navigation | `Overview · Chore · Chat · Order · Bounty`. Order thay vị trí Bonus; không bỏ Bounty. |
| Order | Chọn số lượng → Send để hệ thống gửi email nhà cung cấp → Mark as paid → lưu log. Có Call; không có bước review/chờ duyệt của chủ thể khác. |
| My Account | Hai tab `Profile` và `Chore Settings`; một hàng điều hướng `My Debts` trong Profile. |
| My Debts | Chỉ các khoản tôi nợ/người khác nợ tôi, chi tiết và lịch sử trả nợ liên quan trực tiếp đến tôi. |
| AI | Nút nhỏ có mặt robot, mở Assistant của đúng nhà; bỏ CTA Ask AI cỡ lớn trong khối mua đồ ở Overview. |
| Chore | `Routines · Mine · Team · Bonus`; Bonus là tab con, giữ nghiệp vụ nhận/hoàn thành bonus hiện có. |
| Overview | Lịch công việc tháng, chọn ngày xem người làm và công việc; hiện ảnh minh chứng thật ngay trong ô ngày. |
| Nội dung bỏ | Popular Templates viết cứng; tiêu đề tên season “test tháng” tại Account; hàng Season Schedule tại Account; hai shortcut ngân hàng/supplier hiện tại trong Profile. |

Giữ toàn bộ chữ giao diện bằng tiếng Anh. Luồng Order được đơn giản hóa theo mô tả mới; công nợ cá nhân, vòng đời season và quy tắc xác nhận công việc vẫn tách riêng, không tự thay đổi theo một lần Send.

Hai cách hiểu dùng để lập plan:

- “Thêm món” là chọn sản phẩm thật vào đơn; không mở quyền cho mọi thành viên sửa catalog hoặc giá nhà cung cấp.
- “Chuyển nợ có type nợ” là giao dịch chuyển tiền trả nợ được phân loại `Debt`. Không bổ sung chuyển chủ nợ hoặc tự bù trừ A → B → C; vẫn giữ nợ trực tiếp theo yêu cầu trước.

## 2. Những gì source hiện có

- `house_shell.dart` và `app_bottom_bar.dart` đang ánh xạ Bonus vào slot thứ tư; supplies hiện tô sáng Overview.
- Catalog, gọi điện, mở ứng dụng mail, order review/detail/history, payOS và report/confirm trả nợ đã có implementation. Nút mail hiện tại là `mailto:`, chưa phải backend gửi email một lần bấm; cần bổ sung gửi email thật cho luồng Send mới.
- `SupplyOrderResponse` có món/giá/số lượng/tổng tiền/người tạo/người ứng tiền/share/trạng thái; chưa có đủ mọi trường cho timeline thanh toán mong muốn.
- `household_debts_screen.dart` dùng API purchase debts; backend kiểm tra debtor/creditor cho chi tiết và xác nhận chuyển tiền. Chưa phải một màn tổng hợp mọi loại nợ cá nhân.
- Account thật nằm trong `features/auth/.../profile_screen.dart`. File cùng tên trong `features/profile` là màn placeholder khác, không phải màn trong ảnh.
- “test tháng” đang lấy `season['name']`, không phải chuỗi cố định. Bỏ phần hiển thị tại Account, không đổi tên/xóa season trong DB.
- Popular Templates lấy từ `RoutinePreset.values`, với tên/lịch/Karma viết cứng. Đây không phải danh sách routine thật của nhà.
- `ChoreOccurrenceResponse` hiện có EvidenceId nhưng chưa đủ contract lịch: thiếu CompletedAt/completed-by/nhóm ngày và metadata ảnh cần cho ô lịch.
- Entity `ChoreOccurrence` đã có CompletedAt và CompletedByUserId; phần lịch ưu tiên projection các trường này, không tạo migration chỉ vì DTO cũ chưa expose.
- Evidence đã attach được phép đọc bởi thành viên đang hoạt động trong cùng nhà; evidence chưa attach chỉ uploader xem được. Lịch phải giữ đúng ranh giới này.

## 3. Order: chọn số lượng, Send, thanh toán và log

### 3.1 Màn chính

Tên màn `Orders`, chọn đúng bottom tab `Order`. Hai tab nội dung:

- `Shop`: thông tin nhà cung cấp gọn, nút `Call`, danh sách món thật và bộ tăng/giảm số lượng. Email người nhận hiển thị rõ trong contact.
- `Orders`: danh sách đơn thật, lọc trạng thái khi cần; giữ được các đơn cũ dù nhà cung cấp hiện không còn active.

Cuối phần Shop là tóm tắt lựa chọn và một CTA **`Send order`**. Người dùng chỉ chọn số lượng rồi bấm Send; không phải chọn payer, chia phần, mời thành viên approve hoặc qua một trang Review riêng. Người đặt hiện tại là actor của đơn và là người mặc định ghi nhận khoản chi của mình.

Địa chỉ/điện thoại nếu thật sự cần được điền sẵn từ thông tin đã có; chỉ hỏi bổ sung dữ liệu thiết yếu còn thiếu, không ép thêm form khi đã đủ thông tin. Ghi chú là tùy chọn.

```text
Orders                         [Shop | Orders]
[Supplier contact: phone, email]         [Call]
[Product, unit, price]                 [- 0 +]
[Product, unit, price]                 [- 0 +]
[Selected quantities + total]      [Send order]
After sending: [Mark as paid] → saved order log
Overview | Chore | Chat | Order | Bounty
```

Các dòng sản phẩm phải đến từ catalog API; không tự chèn gạo/nước hoặc giá mẫu khi chưa có catalog.

### 3.2 Send là gửi email thật

- Frontend gửi request có idempotency key tới backend. Backend lưu snapshot đơn và yêu cầu gửi mail trong cùng transaction, rồi worker gửi email qua SMTP/API email đã cấu hình.
- Người nhận là email liên hệ nhà cung cấp đang chọn. Nội dung gồm mã đơn, người đặt, số điện thoại liên hệ nếu có, danh sách món/số lượng/đơn vị, giá/tổng nếu có thật, địa chỉ/ghi chú đã nhập.
- Không dùng `mailto:` làm implementation của `Send order`; mở mail composer chưa đáp ứng yêu cầu “chọn số lượng rồi bấm Send là được”. `mailto:` chỉ có thể là nút liên hệ phụ.
- Hiển thị `Sending` khi đang xử lý, `Sent` khi email service chấp nhận gửi; không khẳng định nhà cung cấp đã đọc/đã nhận hàng. Provider hỗ trợ delivery event thì bổ sung log riêng.
- Thiếu email/thiếu cấu hình gửi mail: báo chưa cấu hình, giữ số lượng đang chọn, vẫn cho Call/copy contact; không tạo trạng thái Sent giả.
- Double-click/refresh/retry cùng request không tạo nhiều đơn hoặc cố ý gửi nhiều mail. Email lỗi có Retry trên chính đơn; lần gửi lại có log và kiểm tra idempotency/trạng thái thực.
- Không thêm tài khoản supplier, màn tiếp nhận/duyệt của supplier, giỏ hàng của chủ thể khác hoặc workflow vận chuyển vào đường đi chính.

### 3.3 Ghi nhận thanh toán và hoàn tất log

Sau khi Send thành công, chi tiết đơn hiện nút **`Mark as paid`** với ý nghĩa “Tôi đã thanh toán cho nhà cung cấp”. Người đặt bấm nút, kiểm tra số tiền thực trả (điền sẵn tổng nếu có), ghi chú/mã chuyển khoản tùy chọn rồi lưu. Đây là xác nhận ngắn trên đơn, không phải một luồng duyệt nhiều người.

- Lưu paid-by actor từ tài khoản đang đăng nhập, số tiền, thời điểm ghi nhận và nguồn xác nhận `USER_REPORTED`; nếu người dùng khai thời gian chuyển tiền riêng thì tách thời gian đó khỏi recorded-at.
- UI hiển thị `Payment recorded` / `Marked as paid by ...`, không diễn đạt thành ngân hàng hoặc nhà cung cấp đã xác nhận.
- Nếu dùng payOS hiện có, có thể giữ tùy chọn `Pay supplier` khi cấu hình hợp lệ; callback/webhook xác minh mới ghi `PROVIDER_VERIFIED`. Đây là tùy chọn, không phải điều kiện để dùng Send hoặc ghi nhận đã chuyển tiền bên ngoài.
- Khi payOS và ghi nhận thủ công cùng xuất hiện, chúng tham chiếu cùng đơn/khoản thanh toán; không cộng tiền hai lần. Không ghi đè hoặc sửa ý nghĩa một payment event đã lưu.
- Người không có quyền ghi nhận trên đơn không thể tự sửa paid-by hoặc đánh dấu thanh toán thay chỉ qua UI/API payload. Mặc định thao tác này thuộc người đặt; không thêm bước chọn người trả/chờ người khác duyệt trong happy path.
- Sau khi lưu thành công, đơn và log vẫn đọc được sau refresh/đăng nhập lại. `Sent` chưa thanh toán và gửi lỗi vẫn là đơn có trạng thái riêng, không tính vào khoản đã trả.
- Không tự tạo nợ/chia phần cho mọi thành viên khi Send hoặc Mark as paid. Nếu người dùng cần ghi nợ giữa cá nhân, thực hiện tại My Debts bằng luồng riêng; log Order giữ liên kết nguồn khi có, không bắt khai báo nợ trước khi đặt.

### 3.4 Nội dung log và liên hệ

Log đơn chỉ tập trung vào: mã đơn/nhà, nhà cung cấp và contact snapshot, người đặt, món/số lượng/đơn vị, giá/tổng tại thời điểm đặt nếu có thật, kênh gửi `Email`, trạng thái/thời điểm gửi, lỗi/retry nếu có, số tiền đã ghi nhận, ai ghi nhận đã trả, nguồn xác nhận, mã giao dịch/ghi chú nếu có và nguồn tạo Manual/AI.

- Timeline chỉ hiển thị mốc/event đã lưu. Thiếu timestamp/reference thì ẩn trường hoặc ghi `Not available`, không lấy UpdatedAt làm thời điểm thanh toán.
- Không suy đoán chủ tài khoản ngân hàng từ creator; ghi nhận thủ công là lời xác nhận của actor, không phải chứng cứ ngân hàng.
- Không cần bảng chia phần, danh sách người chờ approve hoặc supplier fulfillment dashboard trong UI Order mới. Công nợ cá nhân không lặp lại thành dashboard tài chính thứ hai.
- `Call` mở `tel:`. Desktop thiếu ứng dụng xử lý thì cho copy số; không báo đã gọi thành công chỉ vì mở launcher.
- Thiếu nhà cung cấp: giữ Shop empty state + tab Orders; ẩn/disable thao tác không thể thực hiện, không chặn lịch sử đơn.

### 3.5 AI và SMS tương lai

- Tự chọn món hoặc AI chuẩn bị lựa chọn đều đưa về cùng danh sách số lượng. Người dùng có thể sửa rồi bấm `Send order`; không dựng luồng approval khác cho đơn do AI đề xuất.
- AI không tự gửi mail/tự thanh toán khi chưa có yêu cầu thực hiện rõ; chỉ hỏi bổ sung thông tin thiết yếu thiếu, không yêu cầu thêm người duyệt.
- SMS là future feature: sau này cùng snapshot đơn có thể gửi qua SMS khi cấu hình số/kênh/provider. Chưa có SMS thật thì không hiện nút SMS hoạt động hoặc ghi “SMS sent”.
- Hiện tại chỉ implement kênh Email; không tạo framework nhiều chủ thể/kênh hoặc bắt cấu hình SMS trước khi dùng được Order.

## 4. My Account và My Debts

### 4.1 Account

```text
My Account
[Profile | Chore Settings]
[Avatar, name, email, house context when inside a house]
[Existing personal information]
[My Debts            I owe / Owed to me             >]
[Sign out]
```

`My Debts` là hàng điều hướng, không thêm tab thứ ba làm chật thanh Account. Subtitle dùng số thật của đúng tài khoản/nhà; chưa tải được thì loading/error, không thế bằng 0.

Account ngoài `/houses/:houseId` vẫn chỉ hiển thị thông tin cá nhân; không tự dùng một current-house còn lưu để đưa nợ/ảnh/lịch của nhà vào `/profile`.

### 4.2 Đổi tên phần thiết lập việc nhà

- `Personal Profile` → `Profile`.
- `Schedule & Routine` → **`Chore Settings`**.
- Bỏ tiêu đề động `season['name']` ở đầu tab: “test tháng” không còn xuất hiện tại vị trí này.
- Bỏ hoàn toàn hàng `Season Schedule` tại Account; lịch công việc được xem ở Overview/Chore.
- Giữ `Weekly Availability` với mô tả ngày/giờ rảnh và `Chore Preferences & Capacity` với mô tả công việc mong muốn/giới hạn khối lượng.
- Bỏ dependency vào active season chỉ để render toàn bộ tab; chỉ kiểm tra điều kiện season ở thao tác nào thực sự cần. Không bỏ validation của API availability.

### 4.3 Trang công nợ cá nhân

Đổi tiêu đề `Household Debts` → `My Debts`. Hai số nổi bật `I owe`, `Owed to me`; các số ứng tiền/chi cá nhân/đã trả/đã nhận nằm trong phần tóm tắt mở rộng hoặc Activity, không chiếm sáu hàng ở đầu khi đều rỗng.

- Nội dung: `I owe` / `Owed to me` và lịch sử liên quan đến actor hiện tại.
- Mỗi khoản có đối tác, số tiền gốc/còn lại, loại nguồn, trạng thái, hạn nếu có thật, đơn/bounty nguồn và lịch sử trả từng phần.
- Dòng trả nợ có badge **`Debt`**; phân biệt hướng `Sent`/`Received`, đối tác và trạng thái `Awaiting confirmation`/`Confirmed`/`Rejected` theo dữ liệu thật.
- Report chuyển tiền chưa làm giảm nợ. Chỉ xác nhận của bên nhận hoặc sự kiện được backend tin cậy mới làm thay đổi số còn lại.
- Thanh toán nhà cung cấp thuộc Order (ghi nhận thủ công hoặc payOS tùy chọn); trả nợ giữa thành viên là log và xác nhận nội bộ riêng, không tự đi qua tài khoản nhà cung cấp.
- Không tự net-off, không tự chuyển creditor/debtor, không biến giao dịch thanh toán mua hàng thành giao dịch trả nợ.
- Nếu bổ sung nợ bounty vào màn này, API phải truy vấn khoản có actor là debtor/creditor, không chỉ frontend lọc một danh sách nợ cả nhà. Phân trang Activity.
- Link Payments từ Bounty có thể mở My Debts với filter `Bounty`; giữ nguyên các thao tác nghiệp vụ hiện có và tránh hai bản lịch sử tiền độc lập.

`Debt` là loại hiển thị/giao dịch read model; giữ Reason gốc như `HOUSEHOLD_PURCHASE`/`BOUNTY_PAYMENT` để biết vì sao phát sinh nợ. Không đổi số enum hoặc làm mất phân loại lịch sử cũ chỉ để đổi nhãn.

### 4.4 Hai nút ngân hàng và supplier

- Bỏ hai shortcut `My bank details`, `Supplier workspace` khỏi Profile thông thường.
- Supplier workspace không phải một khu vực của thành viên gia đình; nếu còn dùng vận hành catalog thì giữ tuyến riêng với authorization thực ở backend, không chỉ ẩn nút.
- Bank details hiện có phục vụ repayment instructions: chỉ đưa link ngữ cảnh `Receiving account` trong My Debts khi người dùng cần khai báo tài khoản nhận. Không tạo một card mới để lấp chỗ vừa xóa.
- Không xóa dữ liệu ngân hàng, catalog, supplier, payment hoặc webhook trong đợt dọn UI. Chỉ xóa file màn hình sau khi chứng minh không còn caller và không còn luồng nghiệp vụ dùng nó.

## 5. AI và Bonus

### AI shortcut

- Nút robot outline, vùng chạm ít nhất 44×44, tooltip/semantics `Ask AI`, đặt nhỏ phía dưới nội dung và trên bottom navigation.
- Mở `/houses/:houseId/chat/assistant`; không auto gửi prompt hoặc tạo đơn/công việc khi chỉ bấm biểu tượng.
- Bỏ Ask AI cỡ lớn khỏi card Supplies trên Overview; không cần giữ cả card mua đồ lớn khi Order đã có slot riêng.
- Không hiện nút trên chính Assistant hoặc khi bàn phím đang mở. Trong chat giữ lối vào Assistant hiện có, không đặt nút nổi chồng lên composer/send.
- Chừa khoảng tránh nút checkout; trên Bounty chuyển CTA Post hiện có vào header nếu cần để không có hai FAB đè nhau.

### Bonus trong Chore

- Thêm tab con Bonus sau Team, không tạo hai Scaffold/AppBar/bottom navigation lồng nhau.
- Tách phần body của `BonusChoresScreen` thành widget tái sử dụng; dữ liệu và accept/complete bonus vẫn từ API hiện có.
- Giữ lối vào leaderboard/rewards/achievements qua House Management hoặc mục có ngữ nghĩa phù hợp; không để các trang này tô sáng Order chỉ vì trước đây cùng index với Bonus.
- Tab có nhiều nhãn/count phải cuộn ngang gọn ở màn nhỏ; không clip chữ như ảnh Bounty hiện tại.

## 6. Overview dạng lịch công việc

### 6.1 Bố cục

Header nhà giữ QR/notification/avatar. Nội dung: tiêu đề Overview + House Management; tháng hiện tại với Prev/Next/Today; lịch; danh sách công việc của ngày được chọn; thông tin nhà/season còn cần đặt phía dưới.

Ngày mặc định là hôm nay theo giờ Việt Nam. Bấm ô ngày cập nhật phần chi tiết ngay dưới lịch, không bắt chuyển màn mới. Bấm công việc mở Chore detail; bấm ảnh mở gallery có người làm/công việc/thời gian.

```text
Overview                      House Management
        <      Month / Year      >      Today
Mon  Tue  Wed  Thu  Fri  Sat  Sun
[date + counts + up to two real thumbnails]
Selected day
[member avatar/name · chore · due/completed · photo]
                              [small AI face]
Overview | Chore | Chat | Order | Bounty
```

### 6.2 Ngày và ảnh: quy tắc rõ ràng

- Công việc dự kiến nằm ở ngày DueDate theo `Asia/Ho_Chi_Minh`.
- Ảnh hoàn thành nằm ở **ngày thực sự hoàn thành** theo CompletedAt; upload bổ sung sau đó không làm ảnh nhảy sang ngày upload.
- Khi hoàn thành trễ, công việc có thể nằm trong nhóm `Due this day` ở ngày dự kiến và `Completed this day` ở ngày thực hiện. Nếu hai mốc cùng ngày, gộp thành một dòng công việc, không đếm trùng.
- Chỉ dùng evidence đã attach của công việc completed. Draft upload, ảnh chat hay ảnh AI chưa gắn vào công việc không tự xuất hiện trong lịch.
- Mỗi ô hiện tối đa hai thumbnail thật. Có N ảnh hợp lệ thì hiện `+{N-2}` khi N > 2: ba ảnh → +1, năm ảnh → +3. Tính trên ảnh/evidence duy nhất, không đếm số người hoặc số công việc thay cho số ảnh.
- Bấm +N mở danh sách/gallery đầy đủ của ngày. Ảnh không tải được có placeholder trung tính + retry, không thay bằng ảnh mẫu.
- Hiển thị Assigned to và Completed by riêng nếu khác nhau; không đoán người hoàn thành từ assignee. Thiếu CompletedAt/completed-by phải trả trạng thái thiếu dữ liệu, không bịa thời điểm/người.
- Calendar vẫn xem được lịch sử thật khi chưa có active season. Không bắt account/Order phụ thuộc vào calendar load thành công.

### 6.3 Dữ liệu, hiệu năng và quyền

Cần API đọc theo khoảng ngày thay vì FE tải toàn bộ occurrence rồi gọi chi tiết từng mục:

`GET /api/houses/{houseId}/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD`

- Range giới hạn tối đa 42 ngày, from/to là ngày Việt Nam, response ghi timezone và quy ước biên rõ ràng; query DB bằng UTC boundaries tương ứng.
- Summary mỗi ngày: scheduled/completed/overdue counts, tối đa hai evidence preview, totalEvidenceCount. Chi tiết ngày tải khi chọn bằng cùng contract hoặc endpoint ngày riêng nếu payload đo thực tế quá lớn.
- DTO mục công việc: occurrence/chore ID, tên, status/type, due/completed time, assigned/completed member summaries, evidence IDs; không trả StorageKey hoặc link ảnh public.
- Repository dùng projection/batch join trong khoảng ngày; không N+1 query theo ngày/người/ảnh. Không trả base64 toàn bộ ảnh trong JSON tháng.
- Ảnh lấy qua endpoint evidence có auth hiện có; bổ sung thumbnail riêng nếu đo cho thấy ảnh gốc quá nặng. Thumbnail cũng giữ quyền và cache private, không công khai để sửa lỗi hiển thị.
- Chỉ thành viên được phép của đúng nhà được xem; nhà khác/đã rời nhà không xem được ảnh nhờ biết ID. Upload draft vẫn private với uploader.
- Provider/cache key gồm session + house + range; clear khi logout/switch house. Complete/attach/update bằng API thật phải invalidate lịch và ngày liên quan.

## 7. Xóa mock và giữ dữ liệu thật

- Gỡ block Popular Templates, `_RoutinePresetTile` và các CTA dẫn vào preset khỏi Chore.
- Rà caller của `RoutinePreset` trong form/router/tests. Bỏ enum/file chỉ khi đã chuyển hết caller; link `preset=` cũ mở form tạo thật không tự điền tên/lịch/Karma mẫu.
- Giữ danh sách routine/chore thật do người dùng tạo. Không xóa DB vì tên trùng Weekly Deep Clean hoặc “test tháng”.
- Không có dữ liệu thì có empty state đúng ngữ cảnh: `No orders yet`, `No debts yet`, `No chores for this day`, `No bonus chores available`.
- Loading/error không biến thành empty/0, retry giữ ngày/tab/đơn đang xem. Không đưa mock mới vào production để lấp màn hình trống.

## 8. Core giao diện dùng lại

Giữ palette đã chốt: nền `#F8F6F2`, trắng `#FFFFFF`, chữ `#27232F`, phụ `#6D6775`, viền `#E7E2EA`, tím `#6845D6`, tím nhạt `#F0EBFA`.

Be Vietnam Pro regular/medium/semibold; title 24, mục 16 semibold, body 14–15, phụ 12–13. Lề màn 20; trong nhóm 8–12, giữa nhóm 24; nút/input bo 10–12, surface bo 14–16; không bóng mặc định. Icon cùng bộ nét, trạng thái chỉ dùng màu khi có trạng thái thật. Icon trên nút tím phải trắng, disabled phân biệt rõ.

Kiểm tra 354–390px và text scale 1.3–1.5; không tràn ngang cả trang. Lịch tháng ở chiều rộng đủ cho bảy ô chạm được; màn quá hẹp chuyển week/agenda, không ép bảy cột nhỏ đến mức khó bấm. Không dùng màu hoặc thumbnail làm dấu hiệu duy nhất cho trạng thái.

## 9. File FE sẽ thay đổi

Các đường dẫn dưới đây tính từ root repo; **Tạo** là file dự kiến mới, không phải file đã tồn tại.

| File | Thao tác/nội dung |
|---|---|
| `mobile/lib/core/widgets/app_bottom_bar.dart` | Sửa label/icon slot Bonus → Order. |
| `mobile/lib/core/widgets/house_shell.dart` | Sửa paths/selected index; mapping rewards/karma không nhầm Order; gắn AI shortcut, xử lý keyboard/safe area/FAB. |
| `mobile/lib/core/widgets/assistant_shortcut.dart` | Tạo nút robot nhỏ và điều hướng house-scoped. |
| `mobile/lib/core/router/app_router.dart` | Orders và Account debt routes; Bonus query tab; redirect đường dẫn cũ, giữ deep link/order ID/debt ID/AI draft. |
| `mobile/lib/features/supplies/presentation/screens/orders_screen.dart` | Tạo container Shop/Orders; không lồng Scaffold từ hai screen cũ. |
| `mobile/lib/features/supplies/presentation/screens/supplies_catalog_screen.dart` | Tách body dùng lại; giữ chọn món/contact/giỏ và empty state supplier. |
| `mobile/lib/features/supplies/presentation/screens/supply_order_review_screen.dart` | Bỏ khỏi happy path đơn mới; chỉ giữ cho đơn legacy cần tương thích, xóa khi hết caller thực. Không chuyển Send qua màn chọn payer/share/approve. |
| `mobile/lib/features/supplies/presentation/screens/supply_order_detail_screen.dart` | Tách history body; hiện gửi email, Retry, Call, Mark as paid, payment source và log. Không bắt supplier hay thành viên khác thao tác. |
| `mobile/lib/features/supplies/presentation/widgets/order_activity_timeline.dart` | Tạo sau khi contract có event thật; không tạo timeline mẫu. |
| `mobile/lib/features/supplies/presentation/widgets/supplier_contact_card.dart` | Tái sử dụng Call/Email, fallback desktop; bổ sung dùng contact snapshot phù hợp tại detail. |
| `mobile/lib/features/supplies/presentation/screens/household_debts_screen.dart` | Đổi UI thành My Debts, giảm thống kê đầu trang, giữ report/confirm; tách body/detail nếu cần để Account route rõ. |
| `mobile/lib/features/supplies/presentation/providers/supplies_providers.dart` | Cache key actor/house; refresh đơn/log sau Send, email retry và Mark as paid; không tự tạo/cập nhật nợ của các thành viên. |
| `mobile/lib/features/supplies/domain/repositories/supplies_repository.dart` | Thêm contract read activity/debts khi API mở rộng; giữ route hiện có còn được dùng. |
| `mobile/lib/features/supplies/data/repositories/supplies_repository_impl.dart` | Gọi đúng API/actor scope và parse DTO; tránh tự tính lại sổ nợ trên FE. |
| `mobile/lib/features/supplies/presentation/widgets/household_supplies_card.dart` | Gỡ khỏi Overview; xóa component nếu không còn caller, không bỏ nghiệp vụ mua đồ. |
| `mobile/lib/features/auth/presentation/screens/profile_screen.dart` | Profile/Chore Settings, row My Debts, bỏ hai shortcut và tên season/Season Schedule tại Account. |
| `mobile/lib/features/chore/presentation/screens/chore_list_screen.dart` | Tab Bonus, bỏ Popular Templates, giữ lựa chọn tab khi quay lại. |
| `mobile/lib/features/house/presentation/screens/bonus_chores_screen.dart` | Tách reusable body để nhúng vào Chore, giữ action/permissions. |
| `mobile/lib/features/house/presentation/screens/house_bonus_screen.dart` | Bỏ wrapper nếu chỉ còn đường cũ; route cũ redirect sang Chore?tab=bonus. |
| `mobile/lib/features/chore/domain/entities/routine_preset.dart` và `.../presentation/screens/chore_form_screen.dart` | Gỡ dependency preset đúng caller; không xóa form tạo routine thật. |
| `mobile/lib/features/house/presentation/screens/house_detail_screen.dart` | Lịch làm nội dung chính, bỏ card Supplies cũ; giữ house management/member actions. |
| `mobile/lib/features/house/domain/entities/house_calendar_models.dart` | Tạo typed models ngày/mục/evidence previews. |
| `mobile/lib/features/house/data/datasources/house_calendar_remote_data_source.dart` | Tạo adapter GET calendar, parse lỗi qua cơ chế hiện có. |
| `mobile/lib/features/house/presentation/providers/house_calendar_providers.dart` | Tạo range/day state và invalidation; không tạo Dio/session client riêng. |
| `mobile/lib/features/house/presentation/widgets/household_calendar.dart` | Tạo month/week layout, selected day, tối đa hai ảnh/+N. |
| `mobile/lib/features/house/presentation/widgets/calendar_day_details.dart` | Tạo danh sách công việc/người làm/ảnh của ngày; điều hướng chi tiết thật. |
| `mobile/lib/features/bounty/presentation/screens/bounty_board_screen.dart` | Rà tab overflow, CTA trùng AI shortcut và link Payments tới công nợ cá nhân; giữ board/accept bounty. |

Rà notification/chat action-card destinations khi đổi canonical routes; giữ alias cũ giúp notification đã lưu vẫn mở đúng detail. Không xóa các route bằng một đợt search/replace theo index.

## 10. Backend/API và database

### 10.1 Calendar: phần mới cần thực hiện

| File | Trách nhiệm |
|---|---|
| `backend/src/Application/DTOs/House/HouseCalendarResponse.cs` | Tạo response range/timezone/days. |
| `backend/src/Application/DTOs/House/HouseCalendarDayResponse.cs` | Tạo counts, preview IDs, totalEvidenceCount, ngày local. |
| `backend/src/Application/DTOs/House/HouseCalendarItemResponse.cs` | Tạo dữ liệu người làm, due/completed và evidence hợp lệ cho detail ngày. |
| `backend/src/Application/Interfaces/Services/IHouseCalendarService.cs` | Tạo contract đọc calendar có actor và CancellationToken. |
| `backend/src/Application/Interfaces/Repositories/IHouseCalendarRepository.cs` | Tạo read projection contract; không expose EF/IQueryable ra Application. |
| `backend/src/Application/Services/HouseCalendarService.cs` | Tạo: authorize membership bằng service đang có, validate range, map ngày VN/count/dedupe. |
| `backend/src/Infrastructure/Repositories/HouseCalendarRepository.cs` | Tạo: query occurrence + attached evidence + member summaries theo range, async projection/batch. |
| `backend/src/Presentation/Controllers/HouseCalendarController.cs` | Tạo controller mỏng, actor từ claims, không nhận actor tùy ý từ query. |
| `backend/src/Presentation/Extensions/ApplicationServiceExtensions.cs` | Đăng ký calendar service. |
| `backend/src/Presentation/Extensions/InfrastructureServiceExtensions.cs` | Đăng ký calendar repository. |

Reuse `Application/Services/AI/EvidenceService.cs` và `Presentation/Controllers/ChoreEvidenceController.cs` cho đọc ảnh có quyền. Thumbnail mới chỉ thêm khi cần, không làm lộ ảnh draft hoặc storage path.

### 10.2 Order/debt: mở rộng theo thiếu hụt thực tế

- Luồng Order mới không gọi chuỗi submit → chờ share approval → supplier fulfillment của luồng cũ. Bổ sung action đơn giản Send/Retry email/Mark as paid, vẫn xác thực actor và membership đúng nhà ở backend.
- Entity `SupplyOrder` hiện dùng chung trạng thái/payments/shares với luồng cũ. Khi thực thi, bổ sung discriminator workflow rõ ràng cho đơn mới; migration mặc định các đơn đã có là legacy. Không sửa enum PAID khiến nó đồng nghĩa ngân hàng xác minh trong mọi trường hợp; lưu payment confirmation source riêng.
- Rà `Application/DTOs/Supplies/SupplyOrderResponse.cs`, `Application/Services/Supplies/SupplyOrderService.cs`, `Infrastructure/Repositories/SupplyRepository.cs`, `Application/Interfaces/Repositories/ISupplyRepository.cs`, `Presentation/Controllers/SupplyOrdersController.cs`: request gửi chỉ cần lựa chọn số lượng và thông tin liên hệ thiết yếu; không yêu cầu payer/participants/share approval cho workflow đơn giản.
- API dự kiến: `POST /api/houses/{houseId}/orders/send`, `POST /api/houses/{houseId}/orders/{orderId}/retry-email`, `POST /api/houses/{houseId}/orders/{orderId}/record-payment`. GET list/detail tái sử dụng projection hiện có khi phù hợp. Không nhận paid-by tùy ý từ client để giả actor.
- Order và yêu cầu gửi email được lưu transaction cùng nhau. Worker gửi bên ngoài transaction DB; trạng thái request/email/payment độc lập để một email lỗi không biến thành Paid hoặc mất đơn.
- Dùng event/payment hiện có khi đủ dữ liệu; bổ sung `SupplyOrderActivityResponse` làm read projection cho timeline. Không tạo sổ tiền song song với source of truth.
- Cần audit cho ghi nhận thủ công: actor, amount, recorded-at, declared-paid-at nếu có, confirmation source, reference/note và idempotency key. Đặt event cùng transaction record-payment; double-click/webhook không ghi nhận/cộng chi hai lần. Không backfill “đã xác minh” từ dữ liệu suy đoán.
- Rà `Application/Services/Supplies/InternalRepaymentService.cs`, `IInternalRepaymentService.cs`, `PurchaseDebtResponse.cs`, `InternalRepaymentResponse.cs`, `Presentation/Controllers/InternalRepaymentsController.cs`: expose type/source/hướng tiền từ dữ liệu sẵn có và chỉ actor liên quan.
- Nếu My Debts tổng hợp thêm bounty, tạo read service/DTO cá nhân dùng PaymentObligation hiện hữu và repository query actor-scoped; giữ riêng các action purchase repayment/bounty payment đúng business rule, không gom hai cơ chế xác nhận thành một endpoint chung tùy ý.
- Không đổi/renumber `Domain/Enums/PaymentObligationReason.cs` chỉ để hiện badge Debt; không sửa lịch sử tiền cũ.
- Luồng mới dự kiến cần migration additive cho workflow, email dispatch và payment recording metadata vì schema hiện tại chưa đủ. Calendar/tab/text không tự cần migration. Không apply cloud trong đợt lập plan; không drop legacy order/shares/debts hoặc gửi lại email cho đơn cũ khi migrate.

Các file mới dự kiến cho Send email và ghi nhận thanh toán:

| File | Trách nhiệm |
|---|---|
| `backend/src/Domain/Entities/SupplyOrderEmailDispatch.cs` | Queue gửi bền vững: order, recipient/body snapshot, request key, state, attempt/lease, provider/message reference, timestamps/lỗi chuẩn hóa. Không tạo supplier user. |
| `backend/src/Domain/Enums/SupplyOrderWorkflow.cs` | Phân biệt đơn legacy và Simple Contact; giá trị cũ giữ nguyên ý nghĩa. |
| `backend/src/Application/DTOs/Supplies/SendSupplyOrderRequest.cs` | Số lượng/món thật, client request ID và contact cần thiết; không thêm required participants/payer. |
| `backend/src/Application/DTOs/Supplies/RecordSupplyOrderPaymentRequest.cs` | Số tiền thực trả, reference/note tùy chọn, idempotency; actor lấy từ claims/service context. |
| `backend/src/Application/DTOs/Supplies/SupplyOrderActivityResponse.cs` | Log gửi và log payment với nguồn xác nhận trung thực. |
| `backend/src/Application/Interfaces/Services/ISupplyOrderEmailSender.cs` | Contract gửi email server-side; kết quả có reference/trạng thái thực, không expose SMTP library lên Application. |
| `backend/src/Infrastructure/Email/SupplyOrderEmailOptions.cs` | SMTP/API endpoint, sender và secrets qua config backend; không chứa SMS bắt buộc, không đưa key xuống FE. |
| `backend/src/Infrastructure/Email/SmtpSupplyOrderEmailSender.cs` | Implementation SMTP thật khi chốt cấu hình; không dùng mailto hoặc fake return success. |
| `backend/src/Infrastructure/Workers/SupplyOrderEmailWorker.cs` | Đọc dispatch có lease, gửi email, lưu kết quả/retry bounded; không gửi lại đơn cũ hàng loạt lúc startup. |
| `backend/src/Infrastructure/Data/Configurations/SupplyOrderEmailDispatchConfiguration.cs` | Unique/idempotency/index cho queue; giới hạn dữ liệu lỗi và bảo vệ thông tin liên hệ. |
| `backend/src/Infrastructure/Migrations/<generated>_AddSimpleOrderEmailAndPaymentLog.cs` | Tạo bằng EF sau khi chốt model; migration additive, không tự sửa migration cũ. |

Sửa thêm `Domain/Entities/SupplyOrder.cs`, `Infrastructure/Data/AppDbContext.cs`, config entity/repository/interface liên quan và DI/worker registration. Không thêm Factory/Strategy/framework đa kênh chỉ để chuẩn bị SMS. Lỗi email có retry có giới hạn; kết quả gửi chưa rõ không được tự retry vô hạn và khẳng định exactly-once khi provider không hỗ trợ idempotency.

### 10.3 Luồng đi giữa các file

```text
Order tab → OrdersScreen → quantities → Send → SupplyOrdersController
         → SupplyOrderService → transaction: Order snapshot + EmailDispatch → DB
         → SupplyOrderEmailWorker → EmailSender → supplier email → save send result
         → order detail → Mark as paid → authenticated record-payment → saved audit/log

My Account → My Debts row → personal debt provider → authenticated debt API
           → actor-scoped read service → PaymentObligation + repayment history

Overview → calendar providers → remote datasource → HouseCalendarController
         → HouseCalendarService → HouseCalendarRepository → occurrence/evidence/member projections
         → private evidence endpoint → authenticated image bytes → thumbnail/gallery

Small AI button → existing Assistant → prepare order quantities → same Send flow
               → refresh order/calendar/debt providers only after relevant successful action
```

Luồng write giữ transaction/authorization. Order mới không cần actor khác approve; calendar/log projection không tự thanh toán, tạo nợ hay hoàn thành chore. Queue email được tạo bằng yêu cầu Send rõ ràng, không vì người dùng chỉ mở màn hình.

## 11. Route mới và tương thích

| Route chuẩn dự kiến | Tác dụng |
|---|---|
| `/houses/:houseId/orders` | Shop/Orders; giữ state bằng query tab khi cần. |
| `/houses/:houseId/orders/review` | Không có trong happy path mới; alias cũ đưa về lựa chọn số lượng/Send, hoặc giữ riêng cho legacy còn cần tương thích. |
| `/houses/:houseId/orders/:orderId` | Chi tiết/log đơn. |
| `/houses/:houseId/account/debts` | My Debts; filter nguồn/direction nếu có. |
| `/houses/:houseId/account/debts/:debtId` | Chi tiết, report/confirm trả nợ theo quyền. |
| `/houses/:houseId/chores?tab=bonus` | Bonus nhúng vào Chore. |

Giữ `/supplies`, `/supplies/history`, `/supplies/orders/:id`, `/supplies/debts/:id`, `/bonus` và bonus-chores route cũ dưới dạng redirect/alias trong giai đoạn chuyển. Không mất houseId/ID/query/AI draft khi chuyển. Member rời nhà phải bị từ chối ở backend dù route cũ còn tồn tại.

## 12. Thứ tự thực hiện và nghiệm thu

1. Đổi navigation/routes, nhúng Bonus và mapping selected tab; kiểm tra back/deep link trước khi xóa wrapper.
2. Dọn Account/preset UI và thêm My Debts row; giữ quyền profile ngoài nhà.
3. Tổ chức Order Shop/Orders/detail theo số lượng → Send; thêm gửi email backend thật, nút Call và Mark as paid/audit. payOS nếu giữ là tùy chọn, không thành bước bắt buộc.
4. Hoàn thiện personal debts/type Debt và liên kết nguồn; không đổi tiền khi chỉ đổi giao diện.
5. Thêm calendar read API + auth/date tests, rồi dựng calendar/gallery với ảnh thật.
6. Gắn AI shortcut, xử lý khoảng tránh CTA/keyboard; rà responsive và loại các file dead sau khi hết caller.
7. Chạy analyzer/tests liên quan và CI; chỉ push/triển khai code khi bước thực thi được yêu cầu tiếp. Đợt lập plan này chỉ tạo tài liệu.

Các bài test sẽ tạo/cập nhật:

- FE mới: `mobile/test/features/orders_navigation_test.dart`, `my_debts_layout_test.dart`, `household_calendar_test.dart` — tab mapping/deep link, actor/house isolation, 0/1/2/3/5 ảnh, +N, tap ngày/gallery, loading/error/empty.
- FE cập nhật: `supplies_flow_test.dart`, `profile_and_chat_inbox_test.dart`, `schedule_settings_test.dart`, `house_navigation_test.dart`, `routine_creation_test.dart`, `rewards_and_settings_layout_test.dart`, `notification_navigation_test.dart` — bỏ kỳ vọng preset cứng, giữ form tạo thật, Bonus hoạt động và không duplicate shell.
- BE mới: `backend/tests/UnitTests/Services/HouseCalendarTests.cs`, `backend/tests/IntegrationTests/Controllers/HouseCalendarControllerTests.cs` — range/timezone, thiếu quyền/nhà khác/rời nhà, evidence draft không lộ, completed-late grouping, query có giới hạn.
- FE Order: chọn số lượng rồi Send một lần; không xuất hiện bước chọn payer/chia phần/chờ B approve; email lỗi giữ giỏ/đơn và retry đúng; sau Sent có Mark as paid, refresh vẫn có log.
- BE Order: test request/dispatch commit cùng nhau, worker success/fail/timeout, email chưa cấu hình không báo Sent, duplicate Send không tạo đơn/mail lặp, record-payment lưu USER_REPORTED đúng actor và idempotency. Không tạo debt/share approval hay supplier account cho đơn mới.
- BE order/debt: mở rộng suite supplies/repayment hiện có cho type/source, partial repayment, duplicate webhook/request, không ai ngoài debtor/creditor xác nhận nợ được; đơn legacy và payOS cũ không hỏng sau discriminator/migration.

Kịch bản Order chính: A chọn số lượng rồi Send; backend gửi mail tới contact supplier, không cần B approve/supplier login. A có thể Call; sau khi trả tiền A bấm Mark as paid, lưu amount/actor/time/source và đọc lại log sau refresh. Double-click không tạo hai đơn hoặc hai khoản chi; email fail không hiện Sent, chưa mark/payment verify không hiện payment recorded. Nếu thử payOS, dữ liệu xác minh là nguồn riêng và không cộng đôi với log thủ công.

Kịch bản hai người riêng cho My Debts/lịch: với khoản nợ hợp lệ đã có, B chỉ thấy mình nợ A, A thấy B nợ mình; B report chưa giảm nợ, A confirm mới giảm. A hoàn thành chore có ảnh; B xem đúng ngày/nhà; thêm ảnh thứ ba thấy +1; upload draft hoặc ảnh ở nhà khác không xuất hiện. Không tự sinh khoản nợ này chỉ vì A vừa Send một đơn. Refresh/switch house/đăng nhập lại vẫn đúng dữ liệu và tab, không lấy ảnh/số dư cache của nhà cũ.

Tiêu chí hoàn tất: người đặt chỉ chọn số lượng → Send email → ghi nhận đã thanh toán → xem log, có Call và không phụ thuộc chủ thể khác; SMS nằm ở future feature. Một nơi cho log đơn, một nơi cho công nợ cá nhân; Order thay đúng Bonus ở bottom bar; Bonus nhận/hoàn thành được trong Chore; Account không còn tiêu đề season/Season Schedule/hai shortcut cũ; không còn Popular Templates viết cứng; lịch hiển thị ảnh thật đúng ngày/quyền; không làm mất lịch sử hoặc nhập nhằng ghi nhận thủ công với tiền đã xác minh.
