# Báo cáo Bước 2 — TriWork

Sinh viên Huỳnh Nguyễn Trọng Trí — MSSV 2380614104 — Nhóm 9.
Project/package giữ nguyên `huynh_nguyen_trong_tri`.

## File tạo mới

- `lib/core/network/api_client.dart`
- `lib/core/network/api_failure.dart`
- `lib/core/storage/token_storage.dart`
- `lib/core/validation/auth_validators.dart`
- `lib/models/user_model.dart`
- `lib/models/otp_challenge.dart`
- `lib/services/auth_service.dart`
- `lib/screens/auth/auth_gate.dart`
- `lib/screens/auth/otp_screen.dart`
- `lib/screens/auth/register_screen.dart`
- `lib/screens/employee/employee_dashboard.dart`
- `lib/screens/manager/manager_dashboard.dart`
- `lib/screens/admin/admin_dashboard.dart`
- `lib/widgets/auth_frame.dart`
- `lib/widgets/password_field.dart`
- `lib/widgets/dashboard_shell.dart`
- `test/auth_service_test.dart`
- `test/support/auth_fakes.dart`
- `docs/auth_api_contract.md`
- `docs/step2_report.md`
- `ios/Runner/Runner.entitlements` — Keychain phục vụ lưu JWT.

## File chỉnh sửa

- `lib/main.dart` — chỉ khởi tạo binding và runApp.
- `lib/app/app.dart` — cung cấp AuthService, dùng AuthGate, giữ theme TriWork.
- `lib/core/config/api_config.dart` — endpoint đã đối chiếu source, timeout/cooldown.
- `lib/screens/auth/login_screen.dart` — xác thực thật qua service, loading/validation/lỗi.
- `test/widget_test.dart` — thay test Bước 1 bằng luồng auth mới.
- `pubspec.yaml`, `pubspec.lock` — thêm dio/flutter_secure_storage và phụ thuộc tương ứng.
- `README.md` — thông tin sinh viên, kiến trúc, chạy app, hướng dẫn thử, giới hạn.
- `android/app/src/main/AndroidManifest.xml` — INTERNET và allowBackup=false cho lưu JWT.
- `ios/Runner.xcodeproj/project.pbxproj` — liên kết entitlement ở 3 cấu hình Runner.
- `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` — cho phép kết nối mạng client.

Flutter tự cập nhật các file đăng ký plugin cần thiết khi pub get:

- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `ios/Runner/GeneratedPluginRegistrant.m` (file sinh tự động, bị ignore bởi template).

Không chỉnh sửa các màn hình frontend của backend repo hoặc chức năng ngoài Bước 2. Giữ các `.gitkeep` từ Bước 1. Workspace không có `.git`, nên danh sách này dựa trên các thao tác đã thực hiện, không phải git diff. File cache/build/plugin metadata sinh tự động không liệt kê từng file.

## Hợp đồng backend

Xem [auth_api_contract.md](auth_api_contract.md) để biết source tham chiếu và request/response đầy đủ đã ẩn credential:

| Method | Endpoint | Body request | Response thành công theo source |
| --- | --- | --- | --- |
| POST | `/api/auth/login` | userNameOrEmail, password | requiresOtp, message |
| POST | `/api/auth/register` | email, password, fullName | requiresEmailVerification, message |
| POST | `/api/auth/verify-otp` | userNameOrEmail, code; deviceId optional | token, role, userId, fullName, email |
| POST | `/api/auth/resend-otp` | userNameOrEmail | message |
| GET | `/api/auth/me` | không body, Bearer token | id, fullName, email, employeeCode, departmentId, role, hasFace, deviceBound |

Tất cả request trỏ đến `https://vupham309-001-site1.etempurl.com`. Chỉ `/me` cần Bearer trong Bước 2. Role dùng để mở dashboard lấy từ `/me`, không từ client.

## Kiểm chứng

- `flutter pub get`: thành công.
- `flutter analyze`: **No issues found!**
- `flutter test`: **38/38 tests passed**. Toàn bộ request đi qua MockHttpAdapter, không gửi OTP thật. Bao gồm đúng/sai/mất token, role server, lỗi mạng, cooldown, HTTP 429/401/403/5xx, lỗi kho token, logout lúc request đang chạy, giao diện đăng ký/OTP và màn hình 320×568 có bàn phím.
- API public: GET Swagger và `/me` không token đều timeout sau 45 giây, không có HTTP status. Chưa xác định nguyên nhân server/đường mạng, chưa đối chiếu được deployment với source.
- `flutter devices`: có Android emulator `emulator-5554`, Windows, Chrome, Edge.
- `flutter run -d emulator-5554 --no-resident`: build debug APK thành công tại `build/app/outputs/flutter-apk/app-debug.apk`; không cài/mở được vì ADB báo `Failure calling service package: Broken pipe (32)`. Đã thử lại và thử ADB `install --no-streaming -r`, vẫn cùng lỗi. Emulator online, boot completed, package service có tồn tại và còn dung lượng. Không xóa dữ liệu hay reset emulator. Vì vậy chưa xác nhận runtime và secure storage thực tế trên Android.

## Chạy và thử tài khoản thật

```sh
flutter pub get
flutter run -d emulator-5554
```

Chọn Đăng ký → nhập email bạn sở hữu, họ tên, mật khẩu đáp ứng validation → nhận OTP trong hộp thư/thư rác → xác minh trong 5 phút → `/me` hợp lệ mở EmployeeDashboard. Đăng xuất → đăng nhập bằng cùng email/mật khẩu → nhập OTP mới → dashboard theo role server. Gửi lại chỉ khi hết thời gian chờ, dùng mã mới nhất. Mở lại app để kiểm tra khôi phục phiên. Tài khoản Admin/Manager phải được nhóm backend cấp role, không chỉnh role trong client.

## Giới hạn

Chưa có tài khoản người dùng cung cấp và chưa kết nối được API public, nên chưa thử đăng ký/gửi mail/đăng nhập/OTP thật, token hết hạn thực tế hoặc tài khoản Admin/Manager live. Test mock không chứng minh backend hoạt động. iOS/macOS/Windows/Linux chưa được chạy kiểm chứng lưu token.

Cooldown chống gửi liên tục áp dụng trong phiên chạy app; source backend chưa enforce cho login/register/resend. Logout chỉ xóa JWT phía client vì backend không có revoke endpoint. Không triển khai CRUD, QR, GPS, khuôn mặt hay chấm công.
