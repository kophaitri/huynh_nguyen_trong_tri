# TriWork

Ứng dụng chấm công nhân viên bằng Flutter/Dart.

- Sinh viên: **Huỳnh Nguyễn Trọng Trí**
- MSSV: **2380614104** — Nhóm **9**
- Tên project: **huynh_nguyen_trong_tri**

## Chức năng chính

- Đăng ký, đăng nhập email/mật khẩu, xác minh OTP, lưu JWT an toàn và phân quyền Admin/Manager/Employee.
- Quản lý nhân viên, phòng ban, ca làm, địa điểm và đơn nghỉ phép theo quyền backend.
- Chấm công vào/ra bằng quy trình QR, GPS; xem trạng thái và lịch sử chấm công.
- Ba chức năng nâng cao thuyết trình: **chia sẻ GPS, đo chuyển động, nhận dạng và dịch văn bản từ ảnh**.
- OCR chữ Latin, dịch Anh ↔ Việt trên thiết bị; cần Internet tải mô hình dịch lần đầu. Dịch tự động bằng Google Translate thông qua ML Kit: https://developers.google.com/ml-kit/language/translation.
- Smart Insights: thống kê lịch sử thật, đúng giờ/đi muộn khi đủ dữ liệu và gợi ý giờ chuẩn bị tham khảo.
- Face Liveness: kiểm tra chớp mắt/quay đầu tại thiết bị; không phải đăng nhập khuôn mặt hoặc xác minh danh tính.
- Hồ sơ người dùng, dashboard theo vai trò, trạng thái tải/lỗi, làm mới và thử lại.

Danh sách chức năng: [huynhnguyentrongtri.txt](huynhnguyentrongtri.txt).

## Công nghệ

Flutter, Dart, Material 3, Dio, flutter_secure_storage, mobile_scanner, geolocator, sensors_plus, camera, image_picker và Google ML Kit.

## Chạy ứng dụng

Cài Flutter tương thích Dart `^3.13.3`, kết nối điện thoại Android đã bật USB Debugging rồi chạy:

```sh
flutter pub get
flutter run
```

Cấp quyền camera/vị trí khi dùng chức năng liên quan. Dùng tài khoản hợp lệ của bản thân để thử đăng nhập/OTP; dữ liệu và quyền thao tác do backend xác định. OCR/dịch và cảm biến cần thiết bị hỗ trợ Android/iOS.

## Backend

- API public: https://vupham309-001-site1.etempurl.com
- Backend ASP.NET Core dùng chung: https://github.com/MinhVu309/23dthe1-pham-minh-vu

Repository này chỉ chứa frontend Flutter và tài liệu liên quan. Không dùng localhost; không kèm backend, tài khoản hay khóa bí mật. Không sửa/xóa dữ liệu của thành viên khác khi thử ứng dụng.
