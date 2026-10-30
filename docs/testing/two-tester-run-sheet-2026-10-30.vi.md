# Chore Wars: phiếu chạy test cho hai người

Ngày soạn 30/10/2026. Bộ kịch bản tham chiếu source main `6247d59`.

Có **281 ca** thuộc **23 nhóm/hành trình**. Phân bố ưu tiên: P0: 227, P1: 53, P2: 1.

Đọc bước A/B, dữ liệu chuẩn bị và expected trong [kịch bản đầy đủ](two-tester-full-system-2026-10-30.vi.md).
Hai người có thể thực hiện nhưng cần A/B/C và tài khoản phụ theo hướng dẫn; không đánh Pass lịch ba người khi chỉ có hai tài khoản.

## Thông tin lượt chạy

| Trường | Điền khi bắt đầu |
|---|---|
| Mã lượt / ngày giờ UTC+7 | |
| Backend SHA thực tế | |
| Frontend build / SHA | |
| URL môi trường | |
| Người A / thiết bị / OS | |
| Người B / thiết bị / OS | |
| House / season QA sử dụng | |
| Dịch vụ chưa cấu hình / ca Blocked | |

Kết quả hợp lệ: **Chưa chạy, Pass, Fail, Blocked, N/A**. Ghi actual và mã bug khi Fail, lý do khi Blocked/N/A.
Cột Retest ghi ngày + kết quả chạy lại, không xóa kết quả lỗi ban đầu. Không ghi token, mật khẩu, OTP hoặc API key.

## Tổng hợp lượt chạy

Ban đầu tất cả ca Chưa chạy. Cập nhật thủ công các số dưới đây sau mỗi phiên; đây không phải dashboard tự tính.

| Tổng ca | Pass | Fail | Blocked | N/A | Chưa chạy |
|---|---|---|---|---|---|
| 281 | 0 | 0 | 0 | 0 | 281 |

## ENV — 6 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| ENV-01 | P0 HT | | Chưa chạy | | |
| ENV-02 | P0 UI | | Chưa chạy | | |
| ENV-03 | P1 HT | | Chưa chạy | | |
| ENV-04 | P0 UI | | Chưa chạy | | |
| ENV-05 | P1 UI | | Chưa chạy | | |
| ENV-06 | P1 HT | | Chưa chạy | | |

## AUTH — 19 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| AUTH-01 | P0 UI HT | | Chưa chạy | | |
| AUTH-02 | P0 UI HT | | Chưa chạy | | |
| AUTH-03 | P1 UI | | Chưa chạy | | |
| AUTH-04 | P0 UI | | Chưa chạy | | |
| AUTH-05 | P0 UI | | Chưa chạy | | |
| AUTH-06 | P0 TG | | Chưa chạy | | |
| AUTH-07 | P0 UI HT | | Chưa chạy | | |
| AUTH-08 | P0 API HT | | Chưa chạy | | |
| AUTH-09 | P0 API | | Chưa chạy | | |
| AUTH-10 | P1 UI | | Chưa chạy | | |
| AUTH-11 | P0 UI HT | | Chưa chạy | | |
| AUTH-12 | P0 API | | Chưa chạy | | |
| AUTH-13 | P0 UI | | Chưa chạy | | |
| AUTH-14 | P0 UI TG | | Chưa chạy | | |
| AUTH-15 | P0 UI API | | Chưa chạy | | |
| AUTH-16 | P0 UI HT | | Chưa chạy | | |
| AUTH-17 | P0 UI HT | | Chưa chạy | | |
| AUTH-18 | P0 UI API | | Chưa chạy | | |
| AUTH-19 | P0 API HT | | Chưa chạy | | |

## ACCOUNT — 7 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| ACCOUNT-01 | P1 UI | | Chưa chạy | | |
| ACCOUNT-02 | P0 UI HT | | Chưa chạy | | |
| ACCOUNT-03 | P1 UI API | | Chưa chạy | | |
| ACCOUNT-04 | P0 UI | | Chưa chạy | | |
| ACCOUNT-05 | P1 UI HT | | Chưa chạy | | |
| ACCOUNT-06 | P1 UI | | Chưa chạy | | |
| ACCOUNT-07 | P1 UI | | Chưa chạy | | |

## HOUSE — 17 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| HOUSE-01 | P0 UI | | Chưa chạy | | |
| HOUSE-02 | P0 UI | | Chưa chạy | | |
| HOUSE-03 | P0 UI | | Chưa chạy | | |
| HOUSE-04 | P1 UI HT | | Chưa chạy | | |
| HOUSE-05 | P1 UI | | Chưa chạy | | |
| HOUSE-06 | P0 UI API | | Chưa chạy | | |
| HOUSE-07 | P0 UI API | | Chưa chạy | | |
| HOUSE-08 | P0 API HT | | Chưa chạy | | |
| HOUSE-09 | P0 UI API | | Chưa chạy | | |
| HOUSE-10 | P0 API | | Chưa chạy | | |
| HOUSE-11 | P0 UI | | Chưa chạy | | |
| HOUSE-12 | P0 API | | Chưa chạy | | |
| HOUSE-13 | P0 UI | | Chưa chạy | | |
| HOUSE-14 | P0 UI API | | Chưa chạy | | |
| HOUSE-15 | P0 UI API | | Chưa chạy | | |
| HOUSE-16 | P0 UI | | Chưa chạy | | |
| HOUSE-17 | P0 UI API | | Chưa chạy | | |

## PREF — 8 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| PREF-01 | P0 UI | | Chưa chạy | | |
| PREF-02 | P0 UI | | Chưa chạy | | |
| PREF-03 | P0 UI API | | Chưa chạy | | |
| PREF-04 | P1 UI API | | Chưa chạy | | |
| PREF-05 | P0 UI | | Chưa chạy | | |
| PREF-06 | P1 UI API | | Chưa chạy | | |
| PREF-07 | P1 UI | | Chưa chạy | | |
| PREF-08 | P0 UI API | | Chưa chạy | | |

## SEASON — 15 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| SEASON-01 | P0 UI | | Chưa chạy | | |
| SEASON-02 | P0 API | | Chưa chạy | | |
| SEASON-03 | P1 UI API | | Chưa chạy | | |
| SEASON-04 | P0 UI | | Chưa chạy | | |
| SEASON-05 | P0 UI | | Chưa chạy | | |
| SEASON-06 | P0 UI API | | Chưa chạy | | |
| SEASON-07 | P0 UI | | Chưa chạy | | |
| SEASON-08 | P0 UI | | Chưa chạy | | |
| SEASON-09 | P0 UI | | Chưa chạy | | |
| SEASON-10 | P0 UI API | | Chưa chạy | | |
| SEASON-11 | P0 UI | | Chưa chạy | | |
| SEASON-12 | P0 UI | | Chưa chạy | | |
| SEASON-13 | P0 UI | | Chưa chạy | | |
| SEASON-14 | P0 UI | | Chưa chạy | | |
| SEASON-15 | P0 UI TG | | Chưa chạy | | |

## CHORE — 18 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| CHORE-01 | P0 UI | | Chưa chạy | | |
| CHORE-02 | P0 UI | | Chưa chạy | | |
| CHORE-03 | P0 UI | | Chưa chạy | | |
| CHORE-04 | P0 UI | | Chưa chạy | | |
| CHORE-05 | P0 UI | | Chưa chạy | | |
| CHORE-06 | P1 UI API | | Chưa chạy | | |
| CHORE-07 | P0 UI API | | Chưa chạy | | |
| CHORE-08 | P0 API | | Chưa chạy | | |
| CHORE-09 | P0 UI | | Chưa chạy | | |
| CHORE-10 | P1 UI | | Chưa chạy | | |
| CHORE-11 | P1 TG API | | Chưa chạy | | |
| CHORE-12 | P1 TG API | | Chưa chạy | | |
| CHORE-13 | P0 UI API | | Chưa chạy | | |
| CHORE-14 | P0 UI | | Chưa chạy | | |
| CHORE-15 | P1 API | | Chưa chạy | | |
| CHORE-16 | P0 UI | | Chưa chạy | | |
| CHORE-17 | P0 UI API | | Chưa chạy | | |
| CHORE-18 | P0 UI API | | Chưa chạy | | |

## EXEC — 14 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| EXEC-01 | P0 UI | | Chưa chạy | | |
| EXEC-02 | P0 UI | | Chưa chạy | | |
| EXEC-03 | P0 UI | | Chưa chạy | | |
| EXEC-04 | P0 UI | | Chưa chạy | | |
| EXEC-05 | P0 API UI | | Chưa chạy | | |
| EXEC-06 | P0 API | | Chưa chạy | | |
| EXEC-07 | P0 UI API | | Chưa chạy | | |
| EXEC-08 | P0 UI HT | | Chưa chạy | | |
| EXEC-09 | P1 UI HT | | Chưa chạy | | |
| EXEC-10 | P0 API UI | | Chưa chạy | | |
| EXEC-11 | P0 TG | | Chưa chạy | | |
| EXEC-12 | P0 UI TG | | Chưa chạy | | |
| EXEC-13 | P0 UI TG | | Chưa chạy | | |
| EXEC-14 | P0 UI | | Chưa chạy | | |

## JOIN — 12 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| JOIN-01 | P0 UI | | Chưa chạy | | |
| JOIN-02 | P0 UI | | Chưa chạy | | |
| JOIN-03 | P0 UI | | Chưa chạy | | |
| JOIN-04 | P0 UI API | | Chưa chạy | | |
| JOIN-05 | P0 UI | | Chưa chạy | | |
| JOIN-06 | P0 UI | | Chưa chạy | | |
| JOIN-07 | P0 API UI | | Chưa chạy | | |
| JOIN-08 | P0 UI API | | Chưa chạy | | |
| JOIN-09 | P0 UI API | | Chưa chạy | | |
| JOIN-10 | P0 API | | Chưa chạy | | |
| JOIN-11 | P0 UI | | Chưa chạy | | |
| JOIN-12 | P0 API UI | | Chưa chạy | | |

## BOUNTY — 18 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| BOUNTY-01 | P0 UI | | Chưa chạy | | |
| BOUNTY-02 | P0 UI | | Chưa chạy | | |
| BOUNTY-03 | P0 UI | | Chưa chạy | | |
| BOUNTY-04 | P0 UI API | | Chưa chạy | | |
| BOUNTY-05 | P0 UI API | | Chưa chạy | | |
| BOUNTY-06 | P0 UI API | | Chưa chạy | | |
| BOUNTY-07 | P0 UI | | Chưa chạy | | |
| BOUNTY-08 | P0 UI API | | Chưa chạy | | |
| BOUNTY-09 | P0 API UI | | Chưa chạy | | |
| BOUNTY-10 | P0 UI API | | Chưa chạy | | |
| BOUNTY-11 | P0 UI API | | Chưa chạy | | |
| BOUNTY-12 | P0 UI | | Chưa chạy | | |
| BOUNTY-13 | P0 UI | | Chưa chạy | | |
| BOUNTY-14 | P0 UI | | Chưa chạy | | |
| BOUNTY-15 | P0 UI API | | Chưa chạy | | |
| BOUNTY-16 | P0 UI API | | Chưa chạy | | |
| BOUNTY-17 | P0 TG API | | Chưa chạy | | |
| BOUNTY-18 | P1 UI | | Chưa chạy | | |

## DEBT — 14 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| DEBT-01 | P0 UI | | Chưa chạy | | |
| DEBT-02 | P0 UI | | Chưa chạy | | |
| DEBT-03 | P0 UI | | Chưa chạy | | |
| DEBT-04 | P0 UI API | | Chưa chạy | | |
| DEBT-05 | P0 API | | Chưa chạy | | |
| DEBT-06 | P0 UI API | | Chưa chạy | | |
| DEBT-07 | P0 API | | Chưa chạy | | |
| DEBT-08 | P0 UI | | Chưa chạy | | |
| DEBT-09 | P0 UI | | Chưa chạy | | |
| DEBT-10 | P0 UI | | Chưa chạy | | |
| DEBT-11 | P0 UI API | | Chưa chạy | | |
| DEBT-12 | P1 UI | | Chưa chạy | | |
| DEBT-13 | P0 API | | Chưa chạy | | |
| DEBT-14 | P0 UI API | | Chưa chạy | | |

## SHOP — 15 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| SHOP-01 | P0 UI | | Chưa chạy | | |
| SHOP-02 | P0 UI | | Chưa chạy | | |
| SHOP-03 | P0 UI | | Chưa chạy | | |
| SHOP-04 | P1 UI | | Chưa chạy | | |
| SHOP-05 | P0 UI API | | Chưa chạy | | |
| SHOP-06 | P0 API | | Chưa chạy | | |
| SHOP-07 | P1 UI HT | | Chưa chạy | | |
| SHOP-08 | P0 UI HT | | Chưa chạy | | |
| SHOP-09 | P0 UI HT | | Chưa chạy | | |
| SHOP-10 | P0 UI API | | Chưa chạy | | |
| SHOP-11 | P0 UI API | | Chưa chạy | | |
| SHOP-12 | P0 UI | | Chưa chạy | | |
| SHOP-13 | P0 API UI | | Chưa chạy | | |
| SHOP-14 | P0 UI | | Chưa chạy | | |
| SHOP-15 | P1 API HT | | Chưa chạy | | |

## SUPPLIER — 12 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| SUPPLIER-01 | P0 API HT | | Chưa chạy | | |
| SUPPLIER-02 | P1 API UI | | Chưa chạy | | |
| SUPPLIER-03 | P0 API UI | | Chưa chạy | | |
| SUPPLIER-04 | P0 API UI | | Chưa chạy | | |
| SUPPLIER-05 | P0 API | | Chưa chạy | | |
| SUPPLIER-06 | P0 API HT | | Chưa chạy | | |
| SUPPLIER-07 | P0 API HT | | Chưa chạy | | |
| SUPPLIER-08 | P0 API HT | | Chưa chạy | | |
| SUPPLIER-09 | P1 API UI | | Chưa chạy | | |
| SUPPLIER-10 | P0 API HT | | Chưa chạy | | |
| SUPPLIER-11 | P0 API UI | | Chưa chạy | | |
| SUPPLIER-12 | P1 API TG | | Chưa chạy | | |

## CHAT — 14 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| CHAT-01 | P1 UI | | Chưa chạy | | |
| CHAT-02 | P0 UI | | Chưa chạy | | |
| CHAT-03 | P1 UI API | | Chưa chạy | | |
| CHAT-04 | P0 UI | | Chưa chạy | | |
| CHAT-05 | P0 UI | | Chưa chạy | | |
| CHAT-06 | P0 UI | | Chưa chạy | | |
| CHAT-07 | P0 UI | | Chưa chạy | | |
| CHAT-08 | P0 API UI | | Chưa chạy | | |
| CHAT-09 | P1 UI | | Chưa chạy | | |
| CHAT-10 | P0 UI HT | | Chưa chạy | | |
| CHAT-11 | P0 HT API | | Chưa chạy | | |
| CHAT-12 | P1 UI HT | | Chưa chạy | | |
| CHAT-13 | P0 API | | Chưa chạy | | |
| CHAT-14 | P0 API HT | | Chưa chạy | | |

## VOICE — 8 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| VOICE-01 | P0 UI HT | | Chưa chạy | | |
| VOICE-02 | P1 UI HT | | Chưa chạy | | |
| VOICE-03 | P0 UI HT | | Chưa chạy | | |
| VOICE-04 | P0 UI HT | | Chưa chạy | | |
| VOICE-05 | P0 HT API | | Chưa chạy | | |
| VOICE-06 | P1 UI HT | | Chưa chạy | | |
| VOICE-07 | P0 HT API | | Chưa chạy | | |
| VOICE-08 | P1 UI API | | Chưa chạy | | |

## NOTI — 6 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| NOTI-01 | P0 UI | | Chưa chạy | | |
| NOTI-02 | P0 UI | | Chưa chạy | | |
| NOTI-03 | P1 UI | | Chưa chạy | | |
| NOTI-04 | P0 UI | | Chưa chạy | | |
| NOTI-05 | P0 HT API | | Chưa chạy | | |
| NOTI-06 | P1 UI HT | | Chưa chạy | | |

## SUMMARY — 10 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| SUMMARY-01 | P0 UI | | Chưa chạy | | |
| SUMMARY-02 | P0 UI | | Chưa chạy | | |
| SUMMARY-03 | P0 UI | | Chưa chạy | | |
| SUMMARY-04 | P0 UI API | | Chưa chạy | | |
| SUMMARY-05 | P0 UI | | Chưa chạy | | |
| SUMMARY-06 | P0 UI | | Chưa chạy | | |
| SUMMARY-07 | P0 TG UI | | Chưa chạy | | |
| SUMMARY-08 | P1 UI | | Chưa chạy | | |
| SUMMARY-09 | P1 UI API | | Chưa chạy | | |
| SUMMARY-10 | P1 HT UI | | Chưa chạy | | |

## REWARD — 9 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| REWARD-01 | P0 UI | | Chưa chạy | | |
| REWARD-02 | P0 UI TG | | Chưa chạy | | |
| REWARD-03 | P0 UI API | | Chưa chạy | | |
| REWARD-04 | P0 UI API | | Chưa chạy | | |
| REWARD-05 | P0 API | | Chưa chạy | | |
| REWARD-06 | P1 HT API | | Chưa chạy | | |
| REWARD-07 | P1 API UI | | Chưa chạy | | |
| REWARD-08 | P0 API | | Chưa chạy | | |
| REWARD-09 | P0 API | | Chưa chạy | | |

## AI — 22 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| AI-01 | P0 UI HT | | Chưa chạy | | |
| AI-02 | P0 UI HT | | Chưa chạy | | |
| AI-03 | P1 UI HT | | Chưa chạy | | |
| AI-04 | P0 UI API HT | | Chưa chạy | | |
| AI-05 | P0 UI API HT | | Chưa chạy | | |
| AI-06 | P0 UI API TG | | Chưa chạy | | |
| AI-07 | P0 UI API | | Chưa chạy | | |
| AI-08 | P0 API UI | | Chưa chạy | | |
| AI-09 | P0 UI HT | | Chưa chạy | | |
| AI-10 | P0 UI | | Chưa chạy | | |
| AI-11 | P0 UI API | | Chưa chạy | | |
| AI-12 | P0 UI HT | | Chưa chạy | | |
| AI-13 | P0 UI HT | | Chưa chạy | | |
| AI-14 | P0 UI API | | Chưa chạy | | |
| AI-15 | P0 UI API HT | | Chưa chạy | | |
| AI-16 | P0 UI API HT | | Chưa chạy | | |
| AI-17 | P0 UI HT | | Chưa chạy | | |
| AI-18 | P0 API HT | | Chưa chạy | | |
| AI-19 | P2 API HT | | Chưa chạy | | |
| AI-20 | P0 HT UI | | Chưa chạy | | |
| AI-21 | P0 API HT | | Chưa chạy | | |
| AI-22 | P0 API HT | | Chưa chạy | | |

## SECURITY — 12 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| SECURITY-01 | P0 API | | Chưa chạy | | |
| SECURITY-02 | P0 API | | Chưa chạy | | |
| SECURITY-03 | P0 API | | Chưa chạy | | |
| SECURITY-04 | P0 UI | | Chưa chạy | | |
| SECURITY-05 | P0 API UI | | Chưa chạy | | |
| SECURITY-06 | P0 API | | Chưa chạy | | |
| SECURITY-07 | P0 HT API | | Chưa chạy | | |
| SECURITY-08 | P0 API | | Chưa chạy | | |
| SECURITY-09 | P1 UI API | | Chưa chạy | | |
| SECURITY-10 | P0 UI API | | Chưa chạy | | |
| SECURITY-11 | P0 API HT | | Chưa chạy | | |
| SECURITY-12 | P0 API HT | | Chưa chạy | | |

## UI — 9 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| UI-01 | P1 UI | | Chưa chạy | | |
| UI-02 | P1 UI HT | | Chưa chạy | | |
| UI-03 | P0 UI | | Chưa chạy | | |
| UI-04 | P1 UI | | Chưa chạy | | |
| UI-05 | P1 UI | | Chưa chạy | | |
| UI-06 | P1 UI HT | | Chưa chạy | | |
| UI-07 | P1 UI | | Chưa chạy | | |
| UI-08 | P1 UI | | Chưa chạy | | |
| UI-09 | P0 UI HT | | Chưa chạy | | |

## OPS — 8 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| OPS-01 | P0 HT | | Chưa chạy | | |
| OPS-02 | P0 HT API | | Chưa chạy | | |
| OPS-03 | P0 HT API | | Chưa chạy | | |
| OPS-04 | P0 API HT | | Chưa chạy | | |
| OPS-05 | P0 HT | | Chưa chạy | | |
| OPS-06 | P0 HT API | | Chưa chạy | | |
| OPS-07 | P0 HT | | Chưa chạy | | |
| OPS-08 | P0 HT API | | Chưa chạy | | |

## E2E — 8 ca

| Mã | Mức / cách | Người ghi | Kết quả | Actual / Bug ID / bằng chứng | Retest |
|---|---|---|---|---|---|
| E2E-01 | P0 UI HT | | Chưa chạy | | |
| E2E-02 | P0 UI | | Chưa chạy | | |
| E2E-03 | P0 UI HT | | Chưa chạy | | |
| E2E-04 | P0 UI HT | | Chưa chạy | | |
| E2E-05 | P0 UI HT | | Chưa chạy | | |
| E2E-06 | P0 UI HT | | Chưa chạy | | |
| E2E-07 | P0 UI TG | | Chưa chạy | | |
| E2E-08 | P0 UI API | | Chưa chạy | | |

## Phiếu một bug

| Trường | Nội dung |
|---|---|
| Bug ID / Case ID | |
| Mức ảnh hưởng | |
| SHA / môi trường / thiết bị | |
| Vai trò và entity ID QA | |
| Thời điểm UTC+7 | |
| Bước tái hiện | |
| Kết quả mong đợi | |
| Kết quả thực tế | |
| Ảnh/video/request đã che secret | |
| Tần suất / người tái hiện thứ hai | |
| Fix commit / retest | |
