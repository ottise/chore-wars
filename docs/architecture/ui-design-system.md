# 🎨 Chore Wars — UI Design System

Hệ thống thiết kế (Design System) này định hình toàn bộ trải nghiệm UI/UX cho ứng dụng di động Chore Wars, đặc biệt tập trung vào trải nghiệm Gamification.

---

## 1. Color Palette (Bảng màu)

| Role | Color | Hex | Ý nghĩa & Ứng dụng |
| :--- | :--- | :--- | :--- |
| **Primary** | Purple | `#6C5CE7` | Hành động chính (Primary action), brand, điều hướng (navigation). |
| **Secondary / Accent** | Yellow | `#FDCB6E` | Điểm Karma, phần thưởng (reward), danh hiệu (achievement), điểm nhấn. |
| **Success** | Green | `#00B894` | Thành công, trạng thái hoàn thành việc (completed chore). |
| **Warning** | Orange | `#E17055` | Cảnh báo, sắp đến hạn (upcoming), cảnh báo quá hạn. |
| **Error / Danger** | Red | `#D63031` | Lỗi, quá hạn nghiêm trọng (critical overdue), hành động xóa/hủy. |
| **Background** | Light Gray | `#F8F9FA` | Màu nền chính của ứng dụng. |
| **Surface / Card** | White | `#FFFFFF` | Nền của các thẻ (Cards), bề mặt nổi. |
| **Text Primary** | Dark | `#2D3436` | Văn bản chính. |
| **Text Secondary** | Gray | `#636E72` | Văn bản phụ, chú thích. |

---

## 🔤 2. Typography (Kiểu chữ)

| Size | Phân loại | Mục đích sử dụng |
| :--- | :--- | :--- |
| **32–36 px** | **Display** | Điểm Karma lớn, Hạng (Rank) lớn, Dashboard hero, Trạng thái Empty/Success lớn. |
| **24–28 px** | **Headline** | Tiêu đề trang (Page title), Tên Season, Section lớn. |
| **18–20 px** | **Title** | Tiêu đề thẻ (Card title), Tên công việc (Chore name), Section title. |
| **14–16 px** | **Body** | Nội dung thường (Description), Form fields, Chữ trong Button. |
| **12–13 px** | **Caption** | Hạn chót (Deadline), Metadata, Timestamp, Thông tin phụ. |

---

## 📐 3. Spacing System (Hệ thống Khoảng cách)

Chỉ sử dụng các mốc cố định (hệ cơ số 4): `4 px`, `8 px`, `12 px`, `16 px`, `24 px`, `32 px`.

Quy ước chuẩn:
- **4 px**: Giữa các icon và text nhỏ.
- **8 px**: Khoảng cách nội bộ trong cùng một component.
- **12 px**: Giữa các element kề nhau.
- **16 px**: Padding mặc định của app, card, hoặc list.
- **24 px**: Khoảng cách giữa các sections lớn.
- **32 px**: Khoảng cách rất lớn trong một trang (vd: từ header tới body).

---

## 🧱 4. UI Hierarchy (Cấu trúc Thị giác)

Một màn hình (Screen) luôn ưu tiên theo thứ tự từ trên xuống:
```text
Page
│
├── AppBar / Header
│
├── Main Information (Thông tin chính)
│
├── Primary Action (Hành động chính)
│
├── Supporting Information (Thông tin phụ trợ)
│
└── Secondary Actions (Hành động phụ)
```

> **Quy tắc thiết kế Action:**
> - Không nhồi quá nhiều button ngang hàng nhau.
> - **Primary action** luôn dùng `#6C5CE7`.
> - **Destructive action** (Xóa, Hủy) luôn dùng `#D63031`.
> - **Success** (Hoàn thành) dùng `#00B894`.

---

## 🃏 5. Card Style (Phong cách Thẻ)

- **Background:** `#FFFFFF`
- **Border Radius:** `12–16 px`
- **Padding:** `16 px`
- **Nguyên tắc:** Không lạm dụng viền (border). Chỉ đổ bóng (Shadow) nhẹ nếu cần nhấn mạnh để tạo hierarchy nổi bật so với nền.

---

## 🔘 6. Button Style

| Loại Button | Màu nền (Background) | Màu chữ (Text) |
| :--- | :--- | :--- |
| **Primary** | `#6C5CE7` | `#FFFFFF` |
| **Secondary** | `#FDCB6E` | `#2D3436` |
| **Success** | `#00B894` | `#FFFFFF` |
| **Danger** | `#D63031` | `#FFFFFF` |

---

## 🏆 7. Gamification Visual (Thị giác Trò chơi hóa)

Các thành phần game hóa dùng màu cố định để user "nhìn phát biết ngay":
- **Karma**: `#FDCB6E`
- **Rank**: `#6C5CE7`
- **Completed**: `#00B894`
- **Warning**: `#E17055`
- **Penalty**: `#D63031`
- **Achievement**: `#FDCB6E`

*Ví dụ Layout Thẻ Gamification:*
```text
┌─────────────────────────┐
│       YOUR KARMA        │
│                         │
│          125            │  ← Màu: #FDCB6E
│                         │
│        Rank #2          │  ← Màu: #6C5CE7
└─────────────────────────┘
```

---

## 🧩 8. Core Reusable Widgets

Toàn bộ các Widget dùng chung phải được gom vào: `lib/core/widgets/`. Dưới đây là danh sách các Component tiêu chuẩn cần tạo:

- `AppButton`
- `AppTextField`
- `AppCard`
- `AppDialog`
- `AppBottomSheet`
- `LoadingWidget`
- `EmptyState`
- `ErrorState`
- `KarmaBadge`
- `StatusBadge`
- `ChoreCard`
- `MemberAvatar`
