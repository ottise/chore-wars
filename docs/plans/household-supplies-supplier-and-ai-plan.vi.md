# Kế hoạch mua đồ thiết yếu, nhà cung cấp và AI nhắc mua

Ngày cập nhật: 27/10/2026. Đã bắt đầu triển khai mã nguồn theo yêu cầu người dùng. Mục 19 và báo cáo triển khai ghi trạng thái thực tế; các manifest ở mục 15–18 là thiết kế ban đầu, không phải bằng chứng nghiệm thu hoặc thanh toán tiền thật.

## 1. Quyết định mới nhất của người dùng

- Bạn là nhà cung cấp đồ thiết yếu: gạo, nước, giấy, nước rửa chén và các sản phẩm thực sự có trong catalog.
- Một thành viên đứng ra thanh toán đơn cho supplier qua payOS.
- Hệ thống lưu ai đã trả, tổng tiền, từng người dùng chung và phần tiền họ phải chịu.
- Những người còn lại nợ trực tiếp người đã ứng tiền. Họ chuyển khoản ngoài hệ thống; app ghi log và xác nhận nhận tiền.
- Không gom quỹ trước, không cần thủ quỹ, không có ví nạp/rút.
- Không bù trừ hoặc chuyển người nhận nợ: A nợ B thì trả B; B nợ C thì trả C. Kể cả A và B nợ ngược nhau vẫn giữ hai khoản riêng trong bản đầu.
- payOS chỉ phục vụ thanh toán hàng hóa cho supplier, không phục vụ chuyển tiền hay tự xác minh hoàn trả giữa A/B/C.
- AI nhận prompt/voice, tạo đề xuất mua và lưu lịch nhắc cả nhóm. Không tự chuyển tiền hoặc tự xác nhận nợ đã trả.
- Dashboard có nút Order Supplies để tự đặt trực tiếp, không bắt buộc qua AI. Khối đặt hàng hiển thị tên và số điện thoại của bạn từ hồ sơ supplier.
- Supplier có thể chỉnh tên, số điện thoại, email và khu vực/phí giao trong workspace riêng; SMS là future feature theo mục 19.

Các quyết định này thay phương án gom tiền và quyết toán ròng trong bản nháp trước. Kế hoạch thủ quỹ/payOS cũ của bounty vẫn đang hoãn, không tự bật lại theo tính năng mua hàng.

## 2. Ví dụ chốt nghiệp vụ

Đơn gạo/nước/giao hàng tổng 360.000đ. A/B/C đã đồng ý chia đều: mỗi người chịu 120.000đ.

1. A được xác định là người trả đơn; backend tạo yêu cầu thanh toán payOS của supplier.
2. Sau khi backend xác minh supplier đã nhận đủ 360.000đ, đơn thành PAID.
3. Ghi A đã ứng 360.000đ, phần tiêu dùng của A là 120.000đ. Tạo B nợ A 120.000đ và C nợ A 120.000đ; không tạo A nợ chính A.
4. B chuyển khoản cho A bên ngoài, bấm đã chuyển và có thể đính kèm biên lai. Khoản nợ ở trạng thái chờ A xác nhận, chưa coi là đã trả.
5. A xác nhận nhận 120.000đ từ B. Khoản B → A hết nợ; C → A vẫn còn 120.000đ.
6. Nếu ở đơn khác A nợ C 50.000đ, hai khoản C → A và A → C vẫn hiện riêng, không tự lấy chênh lệch.

Thống kê A phải phân biệt: đã ứng 360.000đ; chi phí của mình 120.000đ; đã được hoàn 120.000đ; còn được hoàn 120.000đ. Không cộng tiền ứng với tiền hoàn thành hai lần chi tiêu.

## 3. Phạm vi và hiện trạng source

MVP: một supplier, nhiều nhà, VND, một người trả cho mỗi đơn, chia đều hoặc nhập phần tiền cụ thể. Nhà có thể tự mua ngoài nhưng không giả là thanh toán qua supplier/payOS.

Đã đối chiếu source:

- PaymentObligation có HouseId, DebtorUserId, CreditorUserId, Amount, Reason, Status. Hiện phục vụ bounty/forced reassignment; chưa có liên kết đơn hàng hoặc hoàn trả một phần.
- ActionProposal/ProposalConfirmation có nhà, phòng chat, người tạo và phản hồi theo người. Có thể mở rộng loại đề xuất mua và phiên bản duyệt.
- Notification có HouseId, TargetType/TargetId và realtime; dùng cho đơn/nhắc mua/nợ đúng nhà.
- AIHousekeeperService và ai-service/app/provider.py, schemas.py, main.py đã có interpret/chat/urgent. Cần thêm intent mua hàng, không dùng urgent giả làm checkout.
- Chưa thấy catalog, đơn hàng, nhật ký hoàn tiền nội bộ hoặc lịch mua đồ thiết yếu trong Domain. Đây là thiết kế mới, không coi UI mẫu là implementation.

Supplier là quyền kinh doanh riêng; không đổi HouseRole OWNER/MEMBER. Supplier chỉ xem đơn của mình và dữ liệu giao hàng cần thiết, không xem chat/Karma/lịch sinh hoạt nội bộ. Chủ app không mặc định là thành viên hoặc người giữ quỹ của mọi nhà.

## 4. Luồng mua hàng và tạo nợ

### Hai luồng đặt hàng song song

| Luồng | Điểm bắt đầu | Các bước |
|---|---|---|
| Nhờ AI đặt | Prompt hoặc voice trong private AI chat hoặc gọi AI trong chat nhóm | AI hiểu yêu cầu → tìm hàng/giá thật → chuẩn bị nháp → người dùng kiểm tra hàng, số lượng, phí giao, người trả và phần chia → gửi duyệt → người trả checkout |
| Tự bấm đặt | Nút Order Supplies trên Dashboard của nhà | Mở catalog → tự chọn hàng/số lượng → xem lại đơn, thông tin supplier/số điện thoại, người trả và phần chia → gửi duyệt → người trả checkout |

Cả hai là chức năng chính thức, tồn tại đồng thời. Không thay nút tự đặt bằng AI và không bắt dùng AI mới mua được. Nhờ AI đặt nghĩa là AI chuẩn bị đơn và hỗ trợ các bước, không tự chi tiền thay người dùng. Tự đặt không cần gọi dịch vụ AI.

Hai luồng cùng dùng một catalog, báo giá, SupplyOrder, quy tắc duyệt, checkout payOS, lịch sử đơn và sổ nợ. Lưu CreatedVia MANUAL/AI để truy vết nguồn tạo; trường này không làm thay đổi quyền hay công thức tiền. Đơn do AI tạo có thể tiếp tục xem/sửa trong màn đơn thông thường; đơn tự đặt cũng có thể được AI hỗ trợ khi người dùng yêu cầu và có quyền.

AI nhắc định kỳ là luồng bổ sung: tới lịch → nhắn cả nhóm kiểm tra/mua → người dùng chọn nhờ AI chuẩn bị đơn hoặc mở Order Supplies để tự chọn. Lời nhắc chưa phải đơn đã đặt, không tạo thanh toán hay nợ. Nếu đã có nháp/đơn cùng nhu cầu, dẫn tới đơn đó và yêu cầu xác nhận trước khi tạo thêm.

### Luồng chung sau khi chuẩn bị đơn

```text
Prompt/voice hoặc chọn catalog
 → tạo nháp đơn và lấy báo giá thật
 → chọn người trả + người dùng chung + phần chia
 → người trả đồng ý ứng tiền, từng người đồng ý phần của mình
 → khóa phiên bản báo giá/phần chia
 → người trả mở checkout payOS trả supplier
 → backend xác minh giao dịch
 → đánh dấu đơn đã thanh toán và tạo nợ trực tiếp đúng một lần
 → supplier giao → nhà xác nhận nhận hàng
 → từng người hoàn trả người ứng, người nhận xác nhận từng khoản
```

- Mỗi đơn có một DesignatedPayerUserId. Chỉ người đó tạo checkout và xác nhận mình sẽ ứng tiền. Không mặc định chủ nhà phải trả.
- Không dùng người mở QR làm bằng chứng về danh tính tài khoản ngân hàng thực sự chuyển. Nếu người khác trả hộ QR, không thể suy ra payer từ tên/ngân hàng tự do trong callback; cần đối soát và các bên xác nhận trước khi sửa người ứng tiền.
- Chỉ tạo nợ khi xác minh đủ tiền đúng đơn. Chưa trả, đang chờ, timeout hoặc chỉ quay về success URL không tạo nợ.
- Nợ có thể bắt đầu khi đơn PAID, độc lập trạng thái giao hàng. Đơn bị hủy/hoàn sau đó phải có điều chỉnh liên kết rõ ràng, không xóa lịch sử.
- Không tạo nghĩa vụ cho người chưa đồng ý hoặc rời nhà trước khi chốt. Nghĩa vụ đã chấp nhận trước khi rời nhà giữ lịch sử và quyền xử lý tối thiểu theo policy.
- Thay giá, phí giao, hàng, người trả hoặc phần chia trước thanh toán tạo version mới và duyệt lại phần bị ảnh hưởng. Đơn đã có giao dịch không sửa trực tiếp số tiền.

### Công thức tiền

Tổng đơn = tổng dòng hàng − giảm giá + phí giao. Tổng phần chia phải bằng tổng đơn. Dùng số nguyên đồng/decimal chính xác, không dùng float. Chia đều có dư áp dụng thứ tự cố định trong snapshot và hiển thị rõ trước duyệt.

Nợ mỗi người khác payer = phần chia đã duyệt của người đó. Phần của payer là chi phí cá nhân, không phải khoản phải thu. Không áp dụng phí nợ, Karma hay penalty chore lên khoản mua hàng.

## 5. Sổ nợ và thống kê từng người

Mỗi khoản nợ có nguồn đơn, người nợ, người được nhận, tiền gốc, điều chỉnh, các lần hoàn đã xác nhận và tiền còn lại. Luôn giữ nguyên cặp debtor/creditor; không chuyển nợ sang người thứ ba hoặc bù nợ chéo.

- Tôi phải trả: gom theo từng người nhận trong cùng nhà, mở ra xem từng đơn.
- Tôi được nhận: gom theo từng người nợ, có chi tiết tiền và lịch sử.
- Đã ứng mua hàng, chi phí cá nhân, tiền đã hoàn người khác, tiền được hoàn và các khoản còn chờ là số liệu riêng.
- Cho phép hoàn một phần: B nợ A 120.000đ, A xác nhận 50.000đ thì còn 70.000đ.
- Debtor tạo báo cáo đã chuyển; creditor xác nhận hoặc từ chối. Chỉ khoản xác nhận mới giảm nợ.
- Không cho debtor tự đánh dấu PAID, không để owner/supplier xác nhận hộ creditor chỉ vì họ có vai trò cao hơn.
- Biên lai là bằng chứng người dùng cung cấp, không phải xác minh ngân hàng tự động. Giao dịch nội bộ không đi qua payOS.
- Không đổi/xóa lịch sử nhận tiền; sai sót dùng reversal/adjustment có lý do và người xác nhận. Có tranh chấp thì giữ tiền đã biết và cờ tranh chấp, không làm mất bản ghi.
- Chặn xác nhận vượt tiền còn nợ; báo cáo trùng hoặc nhiều lần chuyển chồng nhau phải đối soát, không tự ghi người nhận đang nợ lại phần dư.

## 6. Hủy, hoàn tiền và ngoại lệ

- Checkout hết hạn/chưa nhận đủ: chưa tạo nợ; đối soát callback đến muộn trước khi quyết định hủy hay tạo checkout khác.
- Supplier nhận thiếu/thừa/sai reference: trạng thái cần đối soát, không tự coi đơn đủ tiền hoặc tạo nợ nhiều lần.
- Hết hàng/thay giá: báo giá lại và duyệt trước thanh toán. Không tự thay sản phẩm hoặc tăng tiền.
- Supplier hoàn tiền cho người trả: lưu giao dịch hoàn đã xác minh hoặc xác nhận theo phương thức thực; yêu cầu hoàn chưa phải đã hoàn.
- Hoàn toàn phần trước ai trả nội bộ: tạo điều chỉnh giảm nghĩa vụ tương ứng sau khi hoàn supplier được xác nhận.
- Nếu B đã trả A rồi đơn được hoàn, A phải hoàn lại B phần B được hưởng. Ghi nghĩa vụ hoàn A → B liên kết đơn và khoản đã nhận; đây là trả lại tiền do hoàn đơn, không phải bù trừ/chuyển nợ tùy ý.
- Hoàn một phần: phân bổ theo mặt hàng/phần chia đã duyệt, hiển thị từng người được giảm/nhận lại bao nhiêu. Phí giao có hoàn hay không dựa trên dữ liệu thực và chính sách đã công bố.
- Giao thiếu/hỏng mở tranh chấp theo dòng hàng; supplier PAID chưa đồng nghĩa đơn DELIVERED/COMPLETED. Nợ nội bộ chưa trả vẫn phải hiển thị sau khi giao xong.

## 7. Backend: Domain và Application

| Thành phần | Mục đích |
|---|---|
| Supplier, SupplierMember | Nhà cung cấp, số điện thoại liên hệ công khai và tài khoản vận hành có quyền kinh doanh |
| SupplyProduct | SKU, tên, đơn vị, giá/tồn thực, trạng thái bán |
| SupplyOrder, SupplyOrderLine | Nhà mua, supplier, payer, snapshot hàng/giá/phí/địa chỉ, version/trạng thái |
| OrderCostShare | Người chịu tiền, phần tiền và phiên bản đã đồng ý |
| SupplierPayment | Request payOS, orderCode, amount, reference, xác minh trả supplier/hoàn |
| PaymentWebhookReceipt | Event/reference duy nhất, kết quả xác minh/chống callback trùng |
| PaymentObligation mở rộng | Nợ trực tiếp debtor → creditor, Reason HOUSEHOLD_PURCHASE và SourceOrderId |
| InternalRepayment | Báo cáo chuyển tiền, khoản nợ nguồn, amount, người nhận xác nhận/từ chối |
| ObligationAdjustment | Điều chỉnh/reversal có lý do, nguồn hoàn đơn và version; không sửa tiền gốc ngầm |
| SupplySchedule | Nhà, hàng, lịch/timezone, nextDueAt, snooze, trạng thái |
| SupplyReminderDelivery | Occurrence, người/phòng nhận, outbox ID và chống nhắc trùng |

Tái sử dụng PaymentObligation để hiển thị nợ chung nhưng giữ nguyên quy tắc bounty hiện hữu. Bổ sung DTO/tính remainingAmount theo reason, giao dịch xác nhận và điều chỉnh. Không ép reason mới vào OTHER để bỏ mất truy vết; constraint unique theo source order/debtor/creditor/kind chống tạo nợ hai lần.

ActionProposal thêm loại SUPPLY_PURCHASE trỏ OrderId/version. Core kiểm tra schema/người duyệt, không tin payload AI như quyền thực thi.

Service dự kiến:

- ISupplyCatalogService: catalog/báo giá/tồn, quyền supplier.
- ISupplyOrderService: nháp, phần chia, gửi duyệt, xác nhận payer, giao/nhận/hủy.
- ISupplierPaymentService: checkout, callback/query, refund tracking; xác minh trả supplier rồi tạo nghĩa vụ trong transaction idempotent.
- IInternalRepaymentService: debtor báo chuyển, creditor xác nhận từng khoản, thống kê phải trả/được nhận.
- ISupplyReminderService: lưu rule, tính lần tới hạn và tạo sự kiện thông báo.
- IPurchasePaymentGateway: contract payment request/query/verify; payOS adapter ở Infrastructure, secret chỉ ở backend.

Controller mỏng → Application service → repository/UnitOfWork. Domain không phụ thuộc provider. Membership theo HouseId cho người mua; supplier endpoints chỉ cho supplier sở hữu đơn. Chính sách xử lý nghĩa vụ cũ của người rời nhà phải tách khỏi quyền truy cập chat/nhà hiện tại.

### Tính nhất quán

- Khóa/version đơn khi duyệt/sửa/pay; reservation tồn trong transaction, không bán vượt tồn cho hai nhà.
- Không gọi provider lâu trong transaction. Lưu pending request có idempotency key → gọi provider → ghi kết quả; timeout query reconcile trước khi tạo yêu cầu khác.
- Callback xác thực chữ ký và đối chiếu orderCode, amount, currency, kênh nhận; không tin client success URL.
- Ghi trạng thái supplier paid + nguồn giao dịch + khoản nợ + outbox trong cùng transaction. Callback trùng hoặc retry không tạo thêm nợ.
- InternalRepayment được khóa cùng obligation khi creditor xác nhận, tránh hai lần nhận vượt số còn lại.
- Transactional outbox và Kafka cho side effect; DB là nguồn thật, Redis chỉ cache. Worker xử lý callback pending, đối soát/hết hạn, outbox và lịch nhắc.
- Backend/DB chung và HTTPS ổn định cho webhook/realtime; hai DB độc lập trên hai máy không tạo một sổ nợ chung.

### API dự kiến

```text
GET    /api/suppliers/{supplierId}/products
GET    /api/suppliers/{supplierId}                    [hồ sơ liên hệ công khai]
POST/PATCH /api/supplier/products/{productId?}
POST/GET /api/houses/{houseId}/supply-orders
GET    /api/houses/{houseId}/supply-orders/{id}
POST   /api/houses/{houseId}/supply-orders/{id}/submit
POST   /api/houses/{houseId}/supply-orders/{id}/approve
POST   /api/houses/{houseId}/supply-orders/{id}/reject
POST   /api/houses/{houseId}/supply-orders/{id}/checkout
POST   /api/houses/{houseId}/supply-orders/{id}/receive
POST   /api/houses/{houseId}/supply-orders/{id}/cancel
GET    /api/houses/{houseId}/purchase-debts
POST   /api/payment-obligations/{id}/repayments
POST   /api/payment-obligations/{id}/repayments/{repaymentId}/confirm
POST   /api/payment-obligations/{id}/repayments/{repaymentId}/reject
GET    /api/supplier/orders
POST   /api/supplier/orders/{id}/fulfillment
POST   /api/supplier/orders/{id}/refunds
POST   /api/payments/webhooks/payos
GET/POST/PATCH /api/houses/{houseId}/supply-schedules
```

Đây là contract dự kiến, kiểm tra route hiện có trước khi code. Mutation có requestId/expectedVersion; quyền và số tiền tính ở server. Báo cáo cá nhân có thể tổng hợp nhiều nhà nhưng phải ghi rõ nhà và không trộn danh tính/khoản nợ giữa nhà.

## 8. AI: prompt, voice và nhắc cả nhóm đúng lịch

Ví dụ: “Mua 10 kg gạo với 2 bình nước, tôi trả trước, chia đều tôi với Trinh; ngày 5 hàng tháng lúc 19 giờ nhắc cả nhóm kiểm tra để mua tiếp”.

Pipeline: speech-to-text hiện có → SUPPLY_PURCHASE / SUPPLY_REMINDER → structured schema → Core kiểm tra catalog, người thật trong nhà, phần chia, quyền, lịch → nháp đơn/lịch → duyệt. Cả private AI chat và group chat khi gọi AI dùng chung service này. Tạo nháp từ private chat chưa tự tiết lộ nội dung ra nhóm; thao tác gửi duyệt mới chia sẻ thông tin mua cần thiết.

- AI không bịa SKU/giá/tồn/tài khoản nhận hoặc suy người trả từ câu mơ hồ. Thiếu loại gạo, lượng, người chia hoặc ngày nhắc thì hỏi lại. Tên trùng phải chọn người đúng.
- Hàng không có trong catalog ghi “chưa có”. Không tự tạo sản phẩm supplier đang bán.
- AI không đánh dấu đơn PAID hay nợ SETTLED từ prompt. Người trả phải checkout; mỗi người đồng ý phần của mình; creditor xác nhận hoàn nội bộ.
- Lịch lưu PostgreSQL theo timezone Asia/Ho_Chi_Minh và nextDueAt UTC. Backend worker đến hạn claim schedule có lease; AI chỉ giúp diễn đạt/gợi ý, không có phiên AI ngủ chờ nhiều ngày.
- Lịch theo ngày tháng dùng calendar timezone, không cộng cố định 30 ngày. Ngày 29–31 trong tháng ngắn có policy ngày cuối tháng được hiển thị trước duyệt.
- Member đề xuất lịch; owner hoặc quyền quản lý lịch đã cấu hình xác nhận để nhắc nhóm. Có tắt/snooze/giới hạn/giờ yên lặng và audit ai bật.
- Chưa có dữ liệu tồn: nói “đến lịch kiểm tra”, không khẳng định “sắp hết”. Gợi ý dựa lịch sử phải nêu nguồn/ngày và cho người dùng sửa.
- Đã có đơn tương tự đang duyệt/đang giao thì dẫn về đơn đó, không tạo đơn mới tự động. Có thể ghi “đã mua ở ngoài” để cập nhật lần mua sau xác nhận.
- Unique schedule/occurrence/channel/recipient + outbox chống trùng khi restart/nhiều worker. Quá nhiều lần lỡ lịch chỉ gộp một nhắc còn phù hợp.
- AI lỗi: mẫu nhắc cố định từ lịch vẫn gửi; không làm mất chức năng mua hàng. Không gửi lại mỗi vòng worker chỉ vì AI/provider lỗi.
- Gửi thẻ nhóm + notification đúng HouseId/OrderId/ScheduleId và SignalR. Push nền chỉ khi đã được cấu hình và có quyền thiết bị; tôn trọng mute/quiet hours.
- Ghi rõ supplier/giá, cho bỏ qua hoặc mua ngoài; mua hàng không làm thay đổi Karma/quota chore.

## 9. Flutter

Giữ core UI đã chốt: nền be, surface trắng, tím chủ đạo, Be Vietnam Pro. Nhãn giao diện tiếng Anh, tên sản phẩm/nội dung người dùng giữ nguyên.

Dashboard của nhà có khối Household Supplies với nút Order Supplies luôn truy cập được khi catalog khả dụng. Nút mở catalog → chọn hàng/số lượng → xem giá, phí giao, người trả và phần chia → duyệt → checkout. Luồng tự đặt và luồng AI dùng chung order service, validation và thanh toán; AI không phải điều kiện để mua.

Khối này hiển thị Supplier, tên cửa hàng/người cung cấp và Phone của bạn; màn catalog và chi tiết đơn cũng có thông tin liên hệ. Số điện thoại cấu hình trong hồ sơ supplier phía backend, không hard-code trong Flutter và không dùng số của member trong nhà. Nút Call dùng liên kết tel khi thiết bị hỗ trợ; có Copy number để dùng trên máy tính. Không tự gọi khi vừa mở trang. Khi chưa cấu hình số, hiện Contact number not available, không điền số mẫu. Hồ sơ công khai chỉ trả trường liên hệ đã cho phép, không trả thông tin ngân hàng hoặc credential payOS.

1. Household Supplies: catalog thật, lần mua gần nhất, lịch nhắc, Ask AI/Shop.
2. Order Review: tổng đơn/phí, payer, mỗi người chịu bao nhiêu, duyệt phần chia.
3. Checkout/Order Detail: payOS trả supplier, trạng thái ngân hàng/giao hàng/hoàn rõ ràng.
4. Household Debts: I owe / Owed to me; nhóm theo người, mở từng nguồn đơn; không có nút tối ưu hoặc bù nợ.
5. Repayment: người nợ báo chuyển, creditor xác nhận/khước từ, lịch sử hoàn một phần.
6. Supplier workspace: sản phẩm, đơn, tiền nhận/giao hàng; không lộ công cụ supplier cho member thông thường.
7. AI card: Review purchase / Approve share / View order / Snooze; điều hướng đúng nhà, không thêm navigator trùng.

## 10. Các đợt thực hiện

| Đợt | Phạm vi | Tiêu chí hoàn thành |
|---|---|---|
| 1 | Domain/migration/catalog/order/role/phần chia | Tổng tiền đúng, version và duyệt đúng người |
| 2 | payOS supplier payment, webhook/query, tạo nợ trực tiếp | Chỉ giao dịch xác minh tạo nợ, callback trùng không nhân đôi |
| 3 | Sổ nợ, hoàn nội bộ một phần, xác nhận và thống kê | Giữ debtor/creditor, không bù trừ, tiền còn lại đúng |
| 4 | Supplier giao/nhận, hủy/hoàn và điều chỉnh nợ | Không xóa lịch sử; hoàn người đã trả nội bộ được theo dõi |
| 5 | Lịch backend/outbox/notification | Đúng ngày/nhà, restart/nhiều instance không nhắc trùng |
| 6 | AI text/voice ở hai chat và thẻ đề xuất | Grounding catalog, quyền Core, thiếu dữ liệu hỏi lại, AI lỗi có fallback |

Không tuyên bố payOS hoạt động trước khi có kênh supplier hợp lệ, cấu hình server và webhook HTTPS thật. Môi trường test/mock phải ghi rõ, không gắn giao dịch giả thành tiền thật.

## 11. Kiểm thử bắt buộc

- A trả 360.000đ cho supplier, chia A/B/C: chỉ sinh B → A và C → A 120.000đ; nguồn mỗi khoản xem được.
- A nợ B, B nợ C vẫn giữ nguyên hai cặp; kể cả nợ ngược chiều không tự bù trừ.
- B báo hoàn A 50.000đ: chưa giảm nợ tới khi A xác nhận; xác nhận xong còn 70.000đ. Retry/concurrent confirm không trừ hai lần.
- Người không phải creditor, owner hoặc supplier không xác nhận hộ; người ngoài không đọc đơn/biên lai/nhà khác.
- Chia lẻ, phí giao, giảm giá, thay version, người không đồng ý, đổi payer, rời nhà, đơn cuối tồn kho đồng thời.
- Callback giả/trùng/thiếu/dư/sai reference/đến muộn, timeout/query; không tạo nợ hoặc nhận doanh thu hai lần.
- Supplier hoàn sau khi B đã trả A: tạo nghĩa vụ hoàn đúng người; giữ audit và không vừa giảm nợ vừa hoàn hai lần cùng phần tiền.
- Tổng chi phí cá nhân khác tổng đã ứng; tiền hoàn không tăng chi tiêu hoặc doanh thu supplier.
- Hai chat, voice mơ hồ, lịch cuối tháng/snooze/tắt, worker restart/multi-instance, Kafka/AI lỗi; không mua hay nhắc trùng.
- Hai máy khác mạng cùng backend/DB: thanh toán, nợ, xác nhận và notification cập nhật cùng nguồn dữ liệu.
- Dashboard đặt trực tiếp được khi AI lỗi/tắt; nút mở đúng catalog và house. Số supplier lấy đúng hồ sơ, copy/call hoạt động theo khả năng thiết bị; thiếu số hiện thông báo thật, không số mẫu.
- Chạy cùng một giỏ hàng qua cả MANUAL và AI: cùng giá/phí/phần chia và điều kiện duyệt; mỗi đơn thanh toán chỉ tạo đúng một bộ nợ. Nháp AI mở được từ lịch sử đơn, đơn manual không phụ thuộc AI. Từ lời nhắc nhóm có thể tiếp tục bằng một trong hai luồng mà không tạo đơn trùng.

## 12. Cấu hình còn cần trước triển khai thực tế

Tên nhà cung cấp và số điện thoại bạn muốn công khai, catalog/giá/đơn vị, khu vực/phí giao, thời hạn báo giá, chính sách hoàn, kênh payOS supplier và địa chỉ backend HTTPS. Chưa có số điện thoại được cung cấp nên plan để cấu hình, không tự điền. Mặc định một người ứng/mỗi đơn và mọi người chịu tiền đồng ý trước checkout.

payOS chỉ xác minh chiều trả supplier qua kênh supplier đã cấu hình. Không cần cấu hình payOS cho A/B/C vì hoàn nội bộ chỉ là ghi nhận ngoài hệ thống. Nếu sau này muốn thanh toán tự động nội bộ thì đó là phạm vi mới, không nằm trong plan này.

Tham khảo kỹ thuật: [payOS API](https://payos.vn/docs/api/), [webhook](https://payos.vn/docs/du-lieu-tra-ve/webhook/), [signature](https://payos.vn/docs/tich-hop-webhook/kiem-tra-du-lieu-voi-signature/). Tài liệu plan không phải bằng chứng đã triển khai hoặc nghiệm thu.

## 13. Future feature: ngân hàng cá nhân để hoàn tiền thuận tiện

Đây là phần nâng cấp tương lai, không thuộc MVP supplier checkout. Không thay quyết định giữ nguyên nợ trực tiếp A → B, B → C; không bù trừ, không chuyển nợ qua người thứ ba.

### F1 — Thêm thông tin nhận tiền và hỗ trợ thao tác

- Mỗi A/B/C tự thêm, sửa hoặc tắt tài khoản nhận tiền của chính mình: ngân hàng, số tài khoản, tên người nhận, tài khoản mặc định. Không ai được sửa tài khoản của người khác; supplier có hồ sơ nhận tiền kinh doanh riêng.
- Từ khoản A nợ B, A bấm Repay để thấy đúng thông tin nhận của B, số tiền còn nợ và mã nội dung liên kết khoản nợ. Có Copy account / Copy amount / Copy reference; có QR hoặc mở ứng dụng ngân hàng nếu khả năng thiết bị và tích hợp thực tế hỗ trợ.
- Cho nhập số tiền trả một phần, nhưng không vượt số còn lại. Trước khi rời app để chuyển tiền, hiển thị người nhận/ngân hàng/số tiền để A kiểm tra.
- Chỉ lưu tài khoản nhận tiền không có nghĩa đã liên kết ngân hàng hoặc xác minh danh tính/chủ tài khoản. UI phân biệt Self-declared / Verified khi thực sự có tích hợp xác minh.
- Không lưu mật khẩu ngân hàng, PIN, OTP; không xin quyền đăng nhập ngân hàng bằng form tự tạo.
- QR/deep link/copy chỉ giúp thao tác. Khi quay lại app, khoản vẫn chờ B xác nhận thực nhận theo cơ chế MVP; không đổi PAID chỉ vì mở app ngân hàng, quét QR hoặc bấm đã chuyển.
- Nếu B chưa khai báo tài khoản: ghi Bank details not added yet, cho gửi yêu cầu B bổ sung hoặc ghi nhận chuyển ngoài như hiện tại. Không dùng tài khoản supplier để thay thế B.
- Chỉ debtor/creditor của nghĩa vụ được xem thông tin cần chuyển; không mặc định công khai số tài khoản của mọi member trong chat hay cho supplier. Mask trong danh sách, không đưa đầy đủ vào notification/log/AI prompt.
- Khi tạo hướng dẫn trả tiền, snapshot người nhận, phiên bản tài khoản, số tiền và reference. B đổi tài khoản thì hướng dẫn cũ được cảnh báo/hết hiệu lực theo policy; việc tiền đã gửi đến tài khoản cũ phải được đối soát trước khi A thử lại. Không tạo nợ mới do đổi tài khoản.

### F2 — Liên kết/xác minh giao dịch ngân hàng thực sự

Chỉ triển khai sau khi chọn được dịch vụ và xác nhận khả năng tài khoản, quyền truy cập, onboarding và consent. Không giả định một bộ key payOS supplier có thể đọc giao dịch hoặc chuyển tiền thay cho A/B/C.

- Dùng flow xác thực/ủy quyền chính thức của đối tác nếu được hỗ trợ; lưu token ở backend theo chính sách của đối tác, có revoke/expiry/audit, không để token trong Flutter hoặc AI.
- Có thể tự đối soát khoản đến tài khoản creditor khi dịch vụ cung cấp bằng chứng phù hợp, nhưng phải khớp người nhận, số tiền, reference và nghĩa vụ. Không tự gán giao dịch mơ hồ.
- Nếu làm payment initiation: người trả vẫn xem và chủ động xác nhận qua luồng chính thức; ứng dụng không tự phát lệnh chuyển khi AI nhắc hoặc khi đến hạn.
- Sự kiện trùng, callback sai chữ ký, timeout, hoàn/chuyển lỗi hoặc revoke quyền không được giảm nợ hai lần. Có query reconcile và fallback xác nhận thủ công.
- F2 không tự mở ví, không bù nợ, không làm thay đổi supplier checkout. Thiết kế adapter khác với payOS nhận tiền hàng.

Điều kiện nghiệm thu F1: A xem đúng tài khoản B và số phải trả, B chưa thêm tài khoản có empty state thật, tài khoản C/nhà khác không bị lộ, mở QR không tự đóng nợ, B xác nhận trả một phần vẫn đúng. F2 cần bộ test provider riêng và bằng chứng giao dịch thật/sandbox ghi rõ môi trường.

## 14. Bản đồ kiến trúc và ranh giới xử lý

```text
Flutter screen/widget
 → Riverpod provider
 → domain repository contract
 → data repository + remote data source
 → authenticated HTTP
 → Presentation controller (nhận DTO/actor)
 → Application service (quyền, tiền, state transition, transaction)
 → repository contract + IUnitOfWork
 → Infrastructure repository / EF Core / PostgreSQL

Application IPurchasePaymentGateway
 → Infrastructure PayOsPurchasePaymentGateway
 → payOS supplier channel

Application IAIHousekeeperClient
 → Infrastructure AIHousekeeperHttpClient
 → Python main.py → provider.py + supply schema/planning
 → structured suggestion về Core để xác thực và tạo nháp

DB transaction + OutboxMessage
 → OutboxDispatcherWorker → Kafka consumer
 → lưu chat/notification có HouseId
 → publisher/SignalR → Flutter provider → màn hình/thẻ cập nhật
```

Domain không tham chiếu EF/payOS/HTTP/AI SDK. Application chỉ tham chiếu Domain, contract không chứa HttpContext/DbContext/SignalR. I/O nằm ở Infrastructure. Presentation không tính phần chia hoặc trực tiếp ghi nợ. Python không ghi database Core, không tạo payment, không quyết định quyền người dùng. Flutter không giữ credential supplier.

Sử dụng outbox đã có: Infrastructure/Messaging/OutboxEventPublisher.cs, Workers/OutboxDispatcherWorker.cs và Domain/Entities/OutboxMessage.cs. Không dựng thêm hệ thống queue/outbox thứ hai. Trước khi code phải đối chiếu event registry/consumer registration hiện tại và ghi migration/compatibility tương ứng.

## 15. Manifest file hiện có cần sửa

Đường dẫn trong mục này tương đối với thư mục gốc repository. Đây là manifest triển khai dự kiến theo source đã kiểm tra, không phải danh sách file đã sửa. Chỉ sửa đúng phần thuộc tính năng, giữ regression bounty/urgent/chat hiện hữu.

### 15.1 Backend Domain / Application

| File hiện có | Nội dung cần thay đổi |
|---|---|
| backend/src/Domain/Entities/PaymentObligation.cs | SourceOrderId nullable cho reason mua hàng; liên kết nhật ký hoàn/điều chỉnh; bảo toàn nghĩa vụ cũ |
| backend/src/Domain/Enums/PaymentObligationReason.cs | Append HOUSEHOLD_PURCHASE và loại hoàn đơn nếu cần, không đổi số enum đã lưu |
| backend/src/Domain/Enums/ProposalType.cs | Append SUPPLY_PURCHASE; không sửa ý nghĩa CHORE_SWAP/URGENT_EVENT |
| backend/src/Domain/Enums/NotificationType.cs | Append loại mua hàng, nhắc mua, báo hoàn và xác nhận; client cũ có fallback |
| backend/src/Domain/Common/Constants/NotificationTargets.cs | SUPPLY_ORDER, SUPPLY_SCHEDULE, INTERNAL_REPAYMENT |
| backend/src/Application/Interfaces/Repositories/IUnitOfWork.cs | Expose repository mua hàng/thanh toán/hoàn nội bộ/lịch để cùng transaction |
| backend/src/Application/DTOs/Proposal/ActionProposalDTOs.cs | Mở contract proposal mua hàng trỏ OrderId/version; validator schema chặt |
| backend/src/Application/Services/ActionProposalService.cs | Thêm nhánh validate/execute SUPPLY_PURCHASE; xác nhận đủ phần chia chỉ mở khả năng checkout, không tự trả tiền |
| backend/src/Application/Interfaces/Services/IAIHousekeeperService.cs | Contract tiếp nhận/chuẩn bị đơn mua từ interpret/chat, trả structured draft |
| backend/src/Application/Interfaces/Services/IAIHousekeeperClient.cs | Contract trao đổi supply intent/schema với Python, không gửi bank credentials |
| backend/src/Application/Services/AI/AIHousekeeperService.cs | Route supply intent sang service tạo nháp, kiểm tra scope; không đụng nghiệp vụ urgent |
| backend/src/Application/Interfaces/Repositories/IPaymentObligationRepository.cs | Query nợ mua hàng theo debtor/creditor/house/source và khóa xác nhận |
| backend/src/Application/Services/BountyService.cs | Chặn SettlePaymentAsync cũ đóng tắt nghĩa vụ mua hàng; giữ rule bounty nguyên vẹn |
| backend/src/Application/DTOs/Bounty/PaymentObligationResponse.cs | Nếu còn dùng response chung, thêm trường nullable SourceOrderId/remainingAmount; không rename route/DTO cũ phá client |

Contract mới của mua hàng nằm trong DTOs/Supplies, không tiếp tục đưa request supplier vào namespace Bounty. Có thể map projection cũ khi cần tương thích; nội dung mua hàng mới dùng API chuyên trách.

### 15.2 Backend Infrastructure / Presentation

| File hiện có | Nội dung cần thay đổi |
|---|---|
| backend/src/Infrastructure/Data/AppDbContext.cs | DbSet và quan hệ entity mới |
| backend/src/Infrastructure/Data/Configurations/PaymentObligationConfiguration.cs | FK SourceOrderId nullable, constraint reason/source và index tra nợ |
| backend/src/Infrastructure/Repositories/UnitOfWork.cs | Inject repository mới, dùng cùng DbContext/transaction |
| backend/src/Infrastructure/Repositories/PaymentObligationRepository.cs | Query projection/lock/update nghĩa vụ mua hàng theo contract |
| backend/src/Infrastructure/AI/AIHousekeeperHttpClient.cs | Supply contract/version, timeout và mapping lỗi Python |
| backend/src/Presentation/Extensions/ApplicationServiceExtensions.cs | DI service mới và validator theo cơ chế hiện có |
| backend/src/Presentation/Extensions/InfrastructureServiceExtensions.cs | DI repository, gateway typed client/options, worker/consumer |
| backend/src/Presentation/Controllers/AIHousekeeperController.cs | Nếu cần endpoint supply chuyên trách: nhận DTO, actor rồi gọi service; không xử lý đơn trực tiếp |
| backend/src/Infrastructure/Migrations/AppDbContextModelSnapshot.cs | EF sinh cùng migration, không tự sửa snapshot một mình |
| backend/src/Presentation/appsettings.json | Options công khai không nhạy cảm: hạn quote, reminder batch/interval, payment provider enabled=false mặc định |

Credential payOS lấy từ environment/secret store hoặc file local đã được ignore, không ghi key vào appsettings được commit. Seed chỉ tạo catalog thật đã được supplier nhập hoặc dữ liệu test có nhãn; không bật tài khoản thu tiền mẫu.

### 15.3 Flutter hiện có

| File hiện có | Nội dung cần thay đổi |
|---|---|
| mobile/lib/features/house/presentation/screens/house_detail_screen.dart | Dashboard theo house: gắn Household Supplies card và Order Supplies |
| mobile/lib/features/home/presentation/screens/home_screen.dart | Nếu Home có dashboard cùng mục đích, tái sử dụng card theo HouseId; không đặt đơn trước khi chọn nhà |
| mobile/lib/core/router/app_router.dart | Routes supplies/order/debts/supplier và deep link notification, giữ một household shell |
| mobile/lib/core/network/api_endpoints.dart | Endpoint catalog, order, checkout, repayment và schedules |
| mobile/lib/features/chat/presentation/screens/assistant_chat_screen.dart | Render kết quả nháp mua, xác nhận và điều hướng màn review |
| mobile/lib/features/chat/presentation/screens/chat_room_screen.dart | Gọi AI mua trong nhóm, render card cùng nguồn order |
| mobile/lib/features/chat/presentation/widgets/interactive_action_card.dart | Proposal SUPPLY_PURCHASE, duyệt version đúng; cập nhật realtime |
| mobile/lib/features/chat/data/models/action_proposal_model.dart | Parse loại mới và payload trỏ order/version |
| mobile/lib/features/chat/data/services/action_proposal_service.dart | Contract duyệt/reject mua hàng nếu response cần trường mới |
| mobile/lib/features/chat/providers/action_proposal_providers.dart | Invalidate order/proposal sau phản hồi, không tạo đơn lại khi rebuild |
| mobile/lib/features/ai/data/ai_repository.dart | Parse supply intent/draft/error và cùng order reference |
| mobile/lib/features/payment/domain/entities/payment_obligation.dart | Reason/source/remaining và hỗ trợ trạng thái trả từng phần |
| mobile/lib/features/payment/data/models/payment_obligation_model.dart | Parse backward-compatible các trường mới |
| mobile/lib/features/payment/domain/repositories/payment_repository.dart | Nếu màn payment tổng hợp cần đọc nợ mua, thêm query riêng; không map confirm nội bộ thành settle bounty |
| mobile/lib/features/payment/data/repositories/payment_repository_impl.dart | Map đúng endpoint theo reason |
| mobile/lib/features/payment/presentation/providers/payment_providers.dart | Refresh projection sau xác nhận hoàn/điều chỉnh |
| mobile/lib/features/payment/presentation/screens/payment_obligations_screen.dart | Mua hàng dẫn sang repayment detail; không dùng nút settle cũ để đóng tắt |
| mobile/lib/features/notifications/domain/entities/notification_models.dart | destination theo SUPPLY_ORDER/SUPPLY_SCHEDULE/INTERNAL_REPAYMENT có HouseId |
| mobile/lib/features/notifications/presentation/screens/notifications_screen.dart | Nhãn/filter thật cho mua hàng, giữ scope từng nhà |

Không thay hệ thống camera/voice đã có chỉ để thêm mua hàng. Chỉ tái sử dụng voice transcript trong AI chat, có kiểm tra nội dung trước tạo nháp.

### 15.4 Python AI hiện có

| File hiện có | Nội dung cần thay đổi |
|---|---|
| ai-service/app/schemas.py | Thêm intent supply_purchase/supply_reminder và structured fields; version schema |
| ai-service/app/provider.py | Prompt trích xuất SKU/người/lịch/số lượng, hỏi lại thiếu dữ liệu; không tạo giá/bank/transaction |
| ai-service/app/main.py | Route endpoint supply/interpret response; giữ scope auth và request size/timeout |
| ai-service/tests/test_provider_language.py | Giữ regression ngôn ngữ/urgent khi mở rộng intent |
| ai-service/tests/test_api.py | Contract intent mới, auth/missing field/failure mapping |

Lịch mua hàng chạy ở Core worker. Không thêm scheduler tài chính vào ai-service/app/worker.py; file này không cần sửa nếu chỉ có chức năng reminder theo kế hoạch này.

## 16. Manifest file mới cần tạo

Mỗi class/enum C# ở một file. Danh sách dưới phân theo đợt; không tạo file rỗng/NotImplemented để coi là hoàn thành.

### 16.1 Domain mới

Thư mục backend/src/Domain/Entities/:

- Supplier.cs, SupplierMember.cs, SupplyProduct.cs.
- SupplyOrder.cs, SupplyOrderLine.cs, OrderCostShare.cs.
- SupplierPayment.cs, PaymentWebhookReceipt.cs.
- InternalRepayment.cs, ObligationAdjustment.cs.
- SupplySchedule.cs, SupplyReminderDelivery.cs.

Thư mục backend/src/Domain/Enums/:

- SupplyOrderStatus.cs, SupplyOrderCreatedVia.cs, SupplierPaymentStatus.cs.
- InternalRepaymentStatus.cs, ObligationAdjustmentKind.cs, SupplyScheduleStatus.cs.

Các tên trên là các file riêng. Không tạo OrderFundingRound, treasury hoặc settlement netting vì đã bỏ gom quỹ/bù trừ.

### 16.2 Application mới

Thư mục backend/src/Application/Interfaces/Repositories/ (mỗi interface một file):

- ISupplierRepository.cs, ISupplyProductRepository.cs, ISupplyOrderRepository.cs.
- ISupplierPaymentRepository.cs, IInternalRepaymentRepository.cs, ISupplyScheduleRepository.cs.

Order repository quản lý lines/shares như aggregate; không tạo repository cho từng dòng chỉ vì có table. Repository payment xử lý webhook receipt; repository schedule xử lý delivery claim theo contract, không lộ EF ra Application.

Thư mục backend/src/Application/Interfaces/Services/:

- ISupplyCatalogService.cs, ISupplyOrderService.cs, ISupplierPaymentService.cs.
- IInternalRepaymentService.cs, ISupplyReminderService.cs, IPurchasePaymentGateway.cs.

Thư mục backend/src/Application/Services/Supplies/:

- SupplyCatalogService.cs, SupplyOrderService.cs, SupplierPaymentService.cs.
- InternalRepaymentService.cs, SupplyReminderService.cs, SupplyCostSplitter.cs.

SupplyCostSplitter là phép tính tiền thuần xác định, không I/O/AI; chỉ tách khi dùng chung đủ chỗ, không tạo factory/strategy framework.

Thư mục backend/src/Application/DTOs/Supplies/:

- SupplierResponse.cs, SupplyProductResponse.cs, UpsertSupplyProductRequest.cs.
- CreateSupplyOrderRequest.cs, SupplyOrderLineRequest.cs, OrderCostShareRequest.cs.
- SupplyOrderResponse.cs, SupplyOrderLineResponse.cs, OrderCostShareResponse.cs.
- SubmitSupplyOrderRequest.cs, ApproveSupplyOrderRequest.cs, SupplyPurchasePayload.cs.
- CreateSupplierCheckoutRequest.cs, SupplierCheckoutResponse.cs, SupplierPaymentResult.cs.
- ReportRepaymentRequest.cs, ConfirmRepaymentRequest.cs, InternalRepaymentResponse.cs, PurchaseDebtSummaryResponse.cs.
- CreateSupplyScheduleRequest.cs, UpdateSupplyScheduleRequest.cs, SupplyScheduleResponse.cs, AISupplyDraftResponse.cs.

Thư mục backend/src/Application/Validations/Supplies/ (theo convention hiện có):

- UpsertSupplyProductRequestValidator.cs, CreateSupplyOrderRequestValidator.cs.
- ReportRepaymentRequestValidator.cs, ConfirmRepaymentRequestValidator.cs.
- CreateSupplyScheduleRequestValidator.cs, UpdateSupplyScheduleRequestValidator.cs.

Các request lồng nhau có rule child validation; service vẫn kiểm tra catalog/version/quyền ở runtime. AddValidatorsFromAssembly hiện có sẽ tìm validators trong Application assembly.

Thư mục backend/src/Application/Events/:

- SupplyOrderPaidEvent.cs, SupplyReminderDueEvent.cs, InternalRepaymentReportedEvent.cs, InternalRepaymentConfirmedEvent.cs.

Chỉ phát dữ liệu tối thiểu cho notification/projection; không kèm credential hoặc toàn bộ tài khoản cá nhân.

### 16.3 Infrastructure / Presentation mới

Thư mục backend/src/Infrastructure/Repositories/:

- SupplierRepository.cs, SupplyProductRepository.cs, SupplyOrderRepository.cs.
- SupplierPaymentRepository.cs, InternalRepaymentRepository.cs, SupplyScheduleRepository.cs.

Thư mục backend/src/Infrastructure/Data/Configurations/:

- SupplierConfiguration.cs, SupplierMemberConfiguration.cs, SupplyProductConfiguration.cs.
- SupplyOrderConfiguration.cs, SupplyOrderLineConfiguration.cs, OrderCostShareConfiguration.cs.
- SupplierPaymentConfiguration.cs, PaymentWebhookReceiptConfiguration.cs.
- InternalRepaymentConfiguration.cs, ObligationAdjustmentConfiguration.cs.
- SupplyScheduleConfiguration.cs, SupplyReminderDeliveryConfiguration.cs.

Mỗi tên là một file riêng. FK/index/check/unique/decimal precision và concurrency phải được ghi trong configuration, không chỉ trong validation UI.

Thư mục backend/src/Infrastructure/Payments/:

- PayOsPurchasePaymentGateway.cs, PayOsOptions.cs.

Thư mục backend/src/Infrastructure/Workers/:

- SupplyReminderWorker.cs: claim lịch đến hạn, gọi service, lease và cancellation.
- SupplierPaymentReconciliationWorker.cs: query pending/late payment/expiry, không tự suy đã trả.

Thư mục backend/src/Infrastructure/Messaging/Kafka/Consumers/:

- SupplyNotificationConsumer.cs: consume các supply/repayment events, chống lặp, dùng chat/notification services hiện có và đúng house.

Thư mục backend/src/Presentation/Controllers/:

- SupplierCatalogController.cs: catalog/hồ sơ public được giới hạn trường và endpoint supplier sửa catalog.
- SupplyOrdersController.cs: thao tác đơn theo house.
- SupplierOrdersController.cs: danh sách/giao/hoàn của supplier sở hữu đơn.
- SupplierPaymentsController.cs: checkout và webhook tách auth scheme rõ ràng; webhook chỉ được miễn JWT khi xác minh provider thực.
- InternalRepaymentsController.cs: nợ và báo cáo/xác nhận hoàn theo debtor/creditor.
- SupplySchedulesController.cs: lịch và quyền quản lý lịch của nhà.

Migration dự kiến trong backend/src/Infrastructure/Migrations/:

- <timestamp>_AddHouseholdSupplies.cs + <timestamp>_AddHouseholdSupplies.Designer.cs: catalog/order/share/payment/source obligation.
- <timestamp>_AddInternalRepaymentsAndSupplySchedules.cs + file Designer tương ứng: repayments/adjustments/schedules/delivery indexes.
- EF sinh timestamp lúc triển khai, cùng AppDbContextModelSnapshot.cs; kiểm tra migration upgrade từ DB có dữ liệu bounty, không DropDatabase hoặc reset volume.

### 16.4 Flutter mới

Module mobile/lib/features/supplies/:

```text
 domain/entities/supply_product.dart
 domain/entities/supply_order.dart
 domain/entities/purchase_debt.dart
 domain/entities/supply_schedule.dart
 domain/repositories/supplies_repository.dart
 data/models/supply_product_model.dart
 data/models/supply_order_model.dart
 data/models/purchase_debt_model.dart
 data/models/supply_schedule_model.dart
 data/datasources/supplies_remote_data_source.dart
 data/repositories/supplies_repository_impl.dart
 presentation/providers/supplies_providers.dart
 presentation/screens/supplies_catalog_screen.dart
 presentation/screens/supply_order_review_screen.dart
 presentation/screens/supply_checkout_screen.dart
 presentation/screens/supply_order_detail_screen.dart
 presentation/screens/supply_order_history_screen.dart
 presentation/screens/household_debts_screen.dart
 presentation/screens/internal_repayment_screen.dart
 presentation/screens/supply_schedule_screen.dart
 presentation/widgets/household_supplies_card.dart
 presentation/widgets/supply_purchase_card.dart
 presentation/widgets/supplier_contact_card.dart
```

Supplier workspace module mobile/lib/features/supplier/:

```text
 data/supplier_remote_data_source.dart
 data/supplier_repository.dart
 presentation/providers/supplier_providers.dart
 presentation/screens/supplier_products_screen.dart
 presentation/screens/supplier_orders_screen.dart
 presentation/screens/supplier_order_detail_screen.dart
```

Supplier API cũng phải chặn quyền server, không chỉ ẩn nút Flutter. Frontend model là DTO/domain UI, không chứa secret merchant.

### 16.5 Python mới và test mới

- ai-service/app/supplies.py: schema bổ sung/chuẩn hóa structured suggestion cho mua/lịch; không đặt đơn hay ghi nợ từ Python.
- ai-service/tests/test_supplies.py: catalog grounding, tiếng Việt/Anh, tên trùng, không rõ payer/quantity, AI unavailable và schema version.
- backend/tests/UnitTests/Services/SupplyCostSplitterTests.cs.
- backend/tests/UnitTests/Services/SupplyOrderServiceTests.cs.
- backend/tests/UnitTests/Services/InternalRepaymentServiceTests.cs.
- backend/tests/UnitTests/Services/SupplyReminderServiceTests.cs.
- backend/tests/IntegrationTests/Infrastructure/SupplyPurchasePaymentTests.cs.
- backend/tests/IntegrationTests/Infrastructure/SupplyAuthorizationTests.cs.
- backend/tests/IntegrationTests/Infrastructure/SupplyReminderDeliveryTests.cs.
- backend/tests/IntegrationTests/Infrastructure/SupplyRefundAdjustmentTests.cs.
- mobile/test/features/supplies_manual_order_test.dart.
- mobile/test/features/supplies_ai_order_test.dart.
- mobile/test/features/household_debts_test.dart.
- mobile/test/features/supplier_workspace_test.dart.
- docs/testing/supplies-two-person-test.vi.md: runbook hai member + supplier, manual/AI và log bằng chứng.

Test hiện có phải chạy hồi quy: PaymentObligationTests.cs, PaymentConfirmationTests.cs, BountyCompensationTests.cs, ActionProposalServiceTests.cs, UrgentProposalTests.cs, notification navigation/house scope và profile/chat tests. Không coi provider mock pass là đã chuyển tiền thật.

## 17. Luồng di chuyển và gọi giữa các file

### 17.1 Tự đặt từ Dashboard

```text
house_detail_screen.dart
 → household_supplies_card.dart [Order Supplies, HouseId]
 → app_router.dart [route /houses/:houseId/supplies]
 → supplies_catalog_screen.dart + supplier_contact_card.dart
 → supplies_providers.dart → supplies_repository.dart (contract)
 → supplies_repository_impl.dart → supplies_remote_data_source.dart
 → SupplierCatalogController.cs → SupplyCatalogService.cs
 → SupplyProductRepository.cs → AppDbContext.cs

chọn hàng → supply_order_review_screen.dart
 → cùng repository chain → SupplyOrdersController.cs
 → SupplyOrderService.cs → SupplyCostSplitter.cs
 → SupplyOrderRepository.cs + ActionProposalService.cs
 → IUnitOfWork/UnitOfWork.cs → order/share/proposal + outbox
 → SupplyNotificationConsumer.cs → chat/notification realtime
 → supply_purchase_card.dart / interactive_action_card.dart
```

Review chỉ hiển thị dự tính trước khi server trả quote; giá và version server là chuẩn. Khi duyệt đủ, order chuyển checkout-eligible; bấm duyệt không gọi payOS tự động.

### 17.2 Nhờ AI bằng prompt/voice ở hai chat

```text
assistant_chat_screen.dart hoặc chat_room_screen.dart
 → voice transcript hiện có / text
 → ai_repository.dart → AIHousekeeperController.cs
 → AIHousekeeperService.cs → IAIHousekeeperClient
 → AIHousekeeperHttpClient.cs → Python main.py
 → provider.py + schemas.py + supplies.py
 → structured supply draft/needs clarification
 → AIHousekeeperService.cs kiểm tra scope/catalog/người thật
 → SupplyOrderService.cs tạo nháp CreatedVia=AI
 → trả OrderId/version → supply_purchase_card.dart
 → supply_order_review_screen.dart → cùng approval/checkout như manual
```

Group chat chỉ chia sẻ đơn khi người tạo gửi duyệt. Python không tự gửi chat Core hoặc ghi database kinh doanh. Nếu người dùng đổi sang tự bấm, mở đúng nháp cũ bằng OrderId thay vì tạo đơn mới.

### 17.3 Thanh toán supplier và tạo nợ

```text
supply_checkout_screen.dart → supplies_providers.dart → repository/datasource
 → SupplierPaymentsController.cs → SupplierPaymentService.cs
 → PayOsPurchasePaymentGateway.cs → payOS supplier channel
 → trả link/QR checkout, SupplierPayment pending

payOS webhook → SupplierPaymentsController.cs
 → gateway verify signature → SupplierPaymentService.cs
 → validate order/reference/amount/channel + lock/version + unique receipt
 → UnitOfWork transaction: supplier payment verified + order paid
    + PaymentObligation B→A, C→A + outbox event
 → commit → OutboxDispatcherWorker.cs → Kafka
 → SupplyNotificationConsumer.cs → chat/notification/SignalR
 → Flutter invalidate order/debts → supply_order_detail_screen.dart
```

SupplierPaymentReconciliationWorker.cs gọi cùng SupplierPaymentService khi webhook lỡ/timeout. Một event xử lý lại không tạo nợ lại. Client quay về checkout chỉ refresh/query, không trực tiếp set paid. Tên gateway là thiết kế dự kiến, chọn official SDK/HTTP implementation sau khi kiểm tra phiên bản thực tế.

### 17.4 Hoàn tiền nội bộ giữa member

```text
household_debts_screen.dart → internal_repayment_screen.dart [B nợ A]
 → report transfer → InternalRepaymentsController.cs
 → InternalRepaymentService.cs kiểm tra B là debtor và amount còn hợp lệ
 → InternalRepaymentRepository.cs + outbox [REPORTED]
 → thông báo A

A mở thẻ → confirm → cùng controller/service
 → kiểm tra A là creditor, khóa nghĩa vụ, chống trùng
 → ghi CONFIRMED + projection remainingAmount + outbox
 → payment_providers.dart / supplies_providers.dart refresh
```

Không gọi PayOsPurchasePaymentGateway ở luồng nội bộ này. Bấm report chưa giảm nợ; supplier không có quyền xác nhận tiền B trả A.

### 17.5 Nhắc định kỳ và cập nhật đơn

```text
supply_schedule_screen.dart hoặc AI draft lịch
 → SupplySchedulesController.cs → SupplyReminderService.cs
 → SupplyScheduleRepository.cs → PostgreSQL [rule, timezone, nextDueAt]

SupplyReminderWorker.cs → claim lịch tới hạn có lease
 → SupplyReminderService.cs kiểm tra enabled/quiet hours/đơn hiện tại
 → tùy chọn AI diễn đạt; lỗi dùng mẫu cố định
 → transaction delivery occurrence + outbox → commit
 → OutboxDispatcherWorker.cs → SupplyNotificationConsumer.cs
 → chat nhóm/notification đúng HouseId → card Open order / Order Supplies
 → người dùng tiếp tục bằng manual hoặc AI, chưa tự checkout
```

## 18. Manifest tương lai cho ngân hàng cá nhân — chưa tạo trong MVP

F1 dự kiến tạo:

- backend/src/Domain/Entities/UserBankAccount.cs; backend/src/Infrastructure/Data/Configurations/UserBankAccountConfiguration.cs.
- backend/src/Application/Interfaces/Repositories/IUserBankAccountRepository.cs; backend/src/Infrastructure/Repositories/UserBankAccountRepository.cs.
- backend/src/Application/Interfaces/Services/IUserBankAccountService.cs; backend/src/Application/Services/UserBankAccountService.cs.
- backend/src/Application/DTOs/BankAccounts/UpsertBankAccountRequest.cs; BankAccountResponse.cs; RepaymentInstructionsResponse.cs (ba file riêng trong cùng thư mục).
- backend/src/Presentation/Controllers/UserBankAccountsController.cs.
- mobile/lib/features/payment/presentation/screens/bank_accounts_screen.dart.
- mobile/lib/features/payment/presentation/widgets/repayment_bank_details.dart.
- migration <timestamp>_AddUserBankAccounts.cs + Designer + snapshot.

Sửa ở F1: AppDbContext.cs, IUnitOfWork.cs/UnitOfWork.cs, DI, profile_screen.dart để mở My bank accounts, app_router.dart, payment repository/provider và internal_repayment_screen.dart để lấy hướng dẫn chuyển. InternalRepayment lưu snapshot phiên bản hướng dẫn; không mặc định đưa thông tin ngân hàng vào mọi response nợ.

Luồng F1:

```text
bank_accounts_screen.dart → UserBankAccountsController.cs
 → UserBankAccountService.cs [actor chỉ sửa tài khoản của mình]
 → UserBankAccountRepository.cs → DB

internal_repayment_screen.dart [A nợ B]
 → InternalRepaymentService.cs kiểm tra nghĩa vụ/quyền
 → UserBankAccountService.cs lấy tài khoản nhận được B cho phép
 → RepaymentInstructionsResponse [B, amount, reference, account version]
 → repayment_bank_details.dart [copy/QR/deep link nếu hỗ trợ]
 → app ngân hàng ngoài → quay lại report transfer → B confirm như MVP
```

F2 chỉ sau khi đã chọn đối tác: thêm IBankTransferGateway.cs ở Application, adapter/options của đối tác ở Infrastructure và callback controller xác thực riêng. Chốt tên file theo nhà cung cấp thật, không tạo sẵn adapter rỗng giả hoàn thành. Thêm bank connection/consent/token reference và migration riêng; bật feature flag sau nghiệm thu. Luồng callback ngân hàng chỉ gọi InternalRepaymentService để đối soát nghĩa vụ gốc; không sửa trực tiếp debt từ controller hoặc AI.

## 19. Điều chỉnh khi triển khai và future SMS

- Supplier được chỉnh tên, phone, email, khu vực và phí giao trong SupplierWorkspaceScreen. Các trường công khai chỉ dùng cho liên hệ mua hàng. Nút email mở ứng dụng mail, không tự gửi thư.
- Một supplier/operator trong MVP được lưu trực tiếp trên Supplier.OperatorUserId. Quyền mở hồ sơ mới lấy từ cấu hình server; không mặc định mọi member là supplier. SupplierMember cho nhiều nhân viên giữ ở giai đoạn mở rộng.
- Repository được gom thành ISupplyRepository/SupplyRepository cho aggregate mua hàng và journal liên quan, expose qua IUnitOfWork.Supplies để chung transaction. Không tạo sáu repository mỏng chỉ để chuyển tiếp EF. Service vẫn tách catalog/order/payment/repayment/refund/dispute/reminder và bank details.
- SupplyNotificationEvent là envelope có EventId/HouseId/ResourceType/ResourceId, consumer kiểm tra resource thuộc đúng house và dùng outbox/Kafka đã có. Thông báo nhóm có SUPPLY_CARD riêng, không nhân đôi thành notification chat thường.
- Lịch dùng khóa transaction PostgreSQL theo household, unique schedule/occurrence và outbox atomic thay cho một lease ngoài DB. Không giữ transaction trong lúc gọi AI; lời nhắc cố định vẫn chạy khi AI lỗi.
- Problem report/giải pháp supplier là SupplyDispute riêng. Xác nhận giải quyết hàng hóa không tự thay trạng thái tiền; refund vẫn có journal và xác nhận payer riêng.
- Actual migrations: AddHouseholdSupplies, AddSupplyProductConcurrency, AddSupplyOrderRevisions, AddSupplyDisputes, AddSupplierRefundRejection. Snapshot do EF sinh. Không reset dữ liệu cũ.
- Sổ nợ mua hàng có endpoint và màn riêng; Payments cũ có nút mở Household purchase debts. Danh sách bounty không trộn khoản mua và nút settle bounty bị chặn với reason mới.

### Future SMS cho supplier và thành viên

SMS chưa được gửi trong MVP. Sau khi chọn dịch vụ SMS/brandname, bổ sung ISmsSender ở Application, adapter/options của nhà cung cấp ở Infrastructure, SmsDeliveryAttempt/SmsNotificationPreference và consumer xử lý từ outbox. Chỉ cấu hình server/secret store giữ credential; Flutter chỉ có tùy chọn bật/tắt nếu kênh thật đã sẵn sàng.

Use case dự kiến: supplier nhận thông báo đơn đã thanh toán/khách báo vấn đề; member nhận nhắc theo lịch khi chủ động đăng ký. Cần xác minh quyền sở hữu số điện thoại bằng flow đối tác hỗ trợ, consent riêng, unsubscribe, quiet hours, giới hạn tần suất/chi phí và idempotency key. Không tự bật SMS vì người dùng đã nhập phone giao hàng hoặc số supplier công khai.

Delivery callback chỉ xác nhận SMS được tiếp nhận/phát theo bằng chứng dịch vụ; không xác nhận thanh toán, nhận hàng hay trả nợ. Hạn chế nội dung SMS: tên ứng dụng, mã đơn ngắn, link mở app; không nhét số tài khoản, khoản nợ chi tiết hay nội dung chat. SMS lỗi giữ thông báo trong app và ghi lỗi để retry có giới hạn, không gửi lặp vô hạn.

Files tương lai: Application/Interfaces/Services/ISmsSender.cs; Infrastructure/Notifications/<Provider>SmsSender.cs và SmsOptions.cs; Domain/Entities/SmsDeliveryAttempt.cs, SmsNotificationPreference.cs; EF configurations/migration; API cài đặt notification; Flutter phần tùy chọn SMS. Tên provider/SDK chỉ chốt khi có dịch vụ thật, không tạo adapter giả báo gửi thành công.

Xem [runbook test mua hàng](../testing/supplies-two-person-test.vi.md) để phân biệt test adapter, DB test và giao dịch ngân hàng thật cần cấu hình.
