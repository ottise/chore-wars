# Runbook mua hàng hai người và supplier

Ngày cập nhật: 27/10/2026. Không dùng số thẻ/tài khoản thật hoặc chuyển tiền thật trong automated test.

## Chuẩn bị

Hai member A/B cùng nhà, một tài khoản supplier riêng. Hai máy dùng cùng backend/DB; xem [shared testing](../shared-testing.vi.md). Dùng hàng/giá do supplier nhập thật khi test thủ công; các fixture automated được gắn nhãn test và nằm trong DB tạm.

Backend cần áp dụng các migration AddHouseholdSupplies, AddSupplyProductConcurrency, AddSupplyOrderRevisions, AddSupplyDisputes, AddSupplierRefundRejection. Migration bổ sung bảng/cột và FK, không reset DB.

Chạy dotnet: copy backend/src/Presentation/appsettings.Supplies.example.json thành appsettings.Supplies.local.json (được gitignore). Điền OperatorUserId của tài khoản supplier để mở workspace. Chỉ bật Enabled khi có ClientId, ApiKey, ChecksumKey, AccountNumber của kênh supplier và WebBaseUrl phù hợp. Khóa nhập trên máy, không gửi vào chat/commit.

Docker: copy .env.supplies.example thành .env.supplies.local, đặt SUPPLIER_OPERATOR_USER_ID. Khi chạy cả AI, dùng hai --env-file .env.ai.local và --env-file .env.supplies.local cùng docker-compose.yml/docker-compose.ai.yml/docker-compose.ai.local.yml. Các biến SUPPLIER_PAYOS_* chỉ vào backend. Không mở database ra Internet.

Đăng ký webhook supplier: /api/payments/webhooks/payos trên địa chỉ HTTPS backend dùng chung. Return URL là web frontend đã cấu hình, không phải bằng chứng thanh toán. Chưa có cấu hình thì checkout phải báo chưa cấu hình, không tạo nợ hoặc PAID giả.

## Tự đặt

1. Supplier mở Profile → Supplier workspace, sửa tên/phone/email/delivery area/fee; thêm SKU/đơn vị/giá/tồn. Không seed mặt hàng giả.
2. A mở Overview → Order Supplies. Kiểm tra tên/phone supplier và Call/Copy/email; thiếu phone hiện Contact number not available.
3. A chọn hàng, Review purchase, nhập địa chỉ/phone, chọn A ứng tiền và chia A/B. Create draft.
4. A gửi duyệt. B mở notification/chat card đúng nhà, xem từng phần tiền rồi Approve my share. A cũng duyệt phần của mình và việc ứng tiền.
5. Trước đủ duyệt không mở checkout. Sau đủ duyệt chỉ A mở Checkout with payOS. Khi chưa có kênh thật, dừng ở lỗi cấu hình đúng; không đánh dấu pass ngân hàng.
6. Với kênh được cấu hình và một giao dịch thử đã được người trả chủ động cho phép: xác minh supplier thực nhận, query/callback chỉ tạo B nợ A đúng một lần. Callback lặp không tăng nợ. Mở checkout/redirect thành công không đủ để báo PAID.
7. Supplier chuyển Start preparing → Mark delivered. A xác nhận hàng đã nhận. B nợ A vẫn còn nếu chưa hoàn tiền.

## Nhờ AI

1. A nhập hoặc đọc prompt trong private AI chat: “Mua một [đơn vị chính xác trong catalog] [tên hàng], tôi trả trước, chia đều tôi và [tên B]”.
2. AI dùng đúng product ID/đơn vị/người trong nhà, trả thẻ Review AI selection. Xem lại giá/phí giao, địa chỉ, payer và shares rồi tạo draft.
3. Chạy lại qua gọi AI trong group chat. Cả hai cùng dùng order service/payOS/sổ nợ như manual; không chuyển tiền chỉ từ prompt.
4. Yêu cầu hàng chưa có, tên trùng/không tồn tại, số lượng mơ hồ: hỏi lại/hiện chưa có, không bịa sản phẩm hoặc người trả.
5. “Ngày 5 hàng tháng 19 giờ nhắc cả nhóm kiểm tra gạo/nước”: Review group reminder; owner xác nhận lưu lịch. Đúng hạn nhắc nhóm, không tự đặt. Member không phải owner chưa được tự bật lịch cho cả nhóm.

## Nợ trực tiếp và hoàn một phần

1. B mở Household Debts → Pay A, xem khoản nguồn. Nếu A có bank details, chỉ B xem được hướng dẫn của khoản này. C là người không liên quan không đọc được tài khoản.
2. B chuyển ngoài app, Report transfer 50.000đ và reference. Tiền còn nợ chưa giảm.
3. B không thể tự confirm. A bấm I received this amount sau khi thực nhận; còn lại = phần gốc − các khoản đã xác nhận + điều chỉnh.
4. A từ chối báo cáo sai: giữ nguyên nợ. Retry cùng request/confirm không ghi nhận hai lần.
5. Nếu A nợ B ở đơn khác: giữ nguyên hai chiều, không bù trừ, không chuyển cho C.

## Sửa, hết kho, refund và khiếu nại

- A Revise purchase trước checkout: báo giá/phần chia mới, DRAFT mới version; consent cũ bị hủy, stock đã giữ được trả lại. Cần gửi duyệt lại. Sau khi đã tạo checkout phải reconcile trước khi sửa.
- Hai nhà cùng mua món cuối kho: chỉ một đơn duyệt/giữ được hàng. Supplier sửa stock từ màn cũ bị conflict, cần refresh.
- Supplier Report money refunded to payer: nợ chưa giảm tới khi payer xác nhận tiền thực nhận. Payer có thể Not received để bác báo cáo sai.
- Nếu B đã hoàn A rồi supplier hoàn đơn, ghi A phải trả lại B phần được hưởng; giữ log, không xóa giao dịch B → A.
- Missing/damaged goods: member tạo problem report, supplier đề xuất giải pháp, chính người báo chấp nhận. Đóng problem report không tự xác nhận refund hoặc xóa nợ.
- Worker restart/hai instance không nhắc trùng; giờ yên lặng 22:00–08:00, lịch cuối tháng dùng ngày cuối tháng ngắn.

## Lệnh test

```powershell
cd backend
dotnet test tests/UnitTests/UnitTests.csproj
$env:CHOREWARS_TEST_POSTGRES='Host=localhost;Port=5435;Database=postgres;Username=postgres;Password=postgres'
dotnet test tests/IntegrationTests/IntegrationTests.csproj --filter 'FullyQualifiedName~SupplyPurchaseTests|FullyQualifiedName~SupplyHttpTests'
cd ../mobile
flutter analyze lib test
flutter test
cd ../ai-service
.venv/Scripts/python.exe -m pytest tests/test_supplies.py tests/test_provider_language.py -q
```

PostgresFixture chỉ cho server local, tạo cw_test_<random> và dọn đúng DB test của nó. Không dùng database thật làm fixture. Test gateway nằm trong test assembly, không được đăng ký ở production.
