# Hợp đồng xác thực TriWork — Bước 2

Đối chiếu source GitHub ngày 29/10/2026. Các mẫu dưới đây mô tả source, **không phải phản hồi nhận được từ API public**.

- Backend: https://github.com/MinhVu309/23dthe1-pham-minh-vu
- Thư mục: `smartcheck/23DTHE1_pham_minh_vu 2/`.
- Đã đọc: `Controllers/AuthController.cs`, phần Auth trong `Dtos/Dtos.cs`, `Models/AppUser.cs`, `Services/OtpService.cs`, `Services/JwtService.cs` và các dòng cấu hình Identity/JWT/JSON trong `Program.cs`.
- Không đọc appsettings, dữ liệu seed, mật khẩu mẫu hay giá trị secret. Không lấy frontend từ repository này.
- Base URL cố định: `https://vupham309-001-site1.etempurl.com`.
- Request/response JSON dùng camelCase; tất cả ví dụ dưới đây đều dùng placeholder, không chứa credential thật.

## Endpoints đã đối chiếu

### POST /api/auth/login

```json
{"userNameOrEmail":"<email-cua-ban>","password":"<mat-khau-cua-ban>"}
```

HTTP 200:

```json
{"requiresOtp":true,"message":"Đã gửi mã OTP tới email"}
```

HTTP 401: `{"message":"Sai tài khoản hoặc mật khẩu"}`. HTTP 403: `{"message":"Tài khoản đã bị khoá"}`.

Login luôn yêu cầu OTP trong source hiện tại, không trả token trực tiếp. Frontend TriWork chỉ nhận email dù backend cũng hỗ trợ username.

### POST /api/auth/register

```json
{"email":"<email-cua-ban>","password":"<mat-khau-cua-ban>","fullName":"<ho-ten>"}
```

HTTP 200:

```json
{"requiresEmailVerification":true,"message":"Đã gửi mã xác minh tới email. Nhập mã để hoàn tất đăng ký."}
```

Server gán Employee, không có trường role trong RegisterDto. Không nhận JWT trước khi xác minh email. Email đã xác minh sẽ bị từ chối với HTTP 400 và `{"errors":["<Identity validation error>"]}`. Dữ liệu DTO sai có thể trả ValidationProblemDetails với trường `errors` là object.

DTO yêu cầu password tối thiểu 6 ký tự. Cấu hình Identity bỏ yêu cầu chữ hoa/ký tự đặc biệt, giữ yêu cầu mặc định có chữ thường và số. TriWork kiểm tra tương ứng, thêm xác nhận lại mật khẩu ở UI (không gửi trường xác nhận lên API).

Với email chưa xác minh, source cho đăng ký lại, cập nhật tên và mật khẩu trước khi gửi mã mới. Chỉ người sở hữu hộp thư xác minh mã mới hoàn tất tài khoản.

### POST /api/auth/verify-otp

```json
{"userNameOrEmail":"<email-cua-ban>","code":"<ma-6-chu-so>"}
```

`deviceId` là trường nullable của DTO, không bắt buộc và không được controller dùng trong luồng này; TriWork không gửi vì chưa triển khai gắn thiết bị/chấm công.

HTTP 200 (AuthResultDto):

```json
{"token":"<JWT-da-an>","role":"Employee","userId":"<id>","fullName":"<ho-ten>","email":"<email>"}
```

`role` có thể là Admin, Manager hoặc Employee. HTTP 401: `{"message":"OTP sai hoặc hết hạn"}`.

Endpoint này dùng chung cho OTP đăng nhập và xác minh email sau đăng ký. Thành công sẽ đánh dấu EmailConfirmed rồi phát JWT. TriWork lưu JWT qua flutter_secure_storage, gọi `/me` và chỉ mở dashboard sau khi `/me` chấp nhận. Role điều hướng lấy từ `/me`, không lấy từ dữ liệu người dùng tự nhập, không suy ra bằng cách tự giải mã JWT.

### POST /api/auth/resend-otp

```json
{"userNameOrEmail":"<email-cua-ban>"}
```

HTTP 200:

```json
{"message":"Nếu tài khoản tồn tại, mã OTP mới đã được gửi"}
```

Không thể dùng phản hồi này để kết luận tài khoản tồn tại hay mail đã đến hộp thư. Mã mới thay thế mã cũ. OTP sống 5 phút, tối đa 5 lần thử trên backend.

**Phân biệt quy định thực tế:** source `SentRecentlyAsync` có ngưỡng 1 phút nhưng chỉ được gọi ở luồng quên mật khẩu. `login`, `register`, `resend-otp` gọi `SendAsync` trực tiếp, chưa enforce cooldown. TriWork áp dụng chờ 60 giây cho mỗi email trong phiên chạy app, kể cả quay lại màn hình trước, chặn yêu cầu đồng thời và giữ thời gian chờ khi request timeout vì mail có thể đã được gửi. Có xử lý HTTP 429 và Retry-After dạng số giây nếu server bổ sung. Cooldown client không thay thế rate limiting phía backend và không tồn tại qua việc tắt app.

### GET /api/auth/me

Không có request body. Header: `Authorization: Bearer <JWT-da-an>`.

HTTP 200:

```json
{
  "id":"<id>",
  "fullName":"<ho-ten>",
  "email":"<email>",
  "employeeCode":null,
  "departmentId":null,
  "role":"Employee",
  "hasFace":false,
  "deviceBound":false
}
```

EmployeeCode có thể là string, DepartmentId có thể là số; role có thể là Admin/Manager/Employee (hoặc null nếu tài khoản không có role). TriWork từ chối truy cập với role thiếu/không được hỗ trợ, không mặc định nâng/cấp quyền. User model của Bước 2 chỉ dùng id, fullName, email, role.

Không token/token sai hoặc hết hạn: middleware có thể trả 401 không có JSON body. TriWork xử lý cả 401 và 403, xóa phiên và về login. Mất kết nối/timeout/5xx: không mở dashboard, giữ token đã lưu để thử `/me` lại hoặc người dùng chọn xóa phiên.

## JWT và đăng xuất

Source ký HMAC SHA-256, chứa id, họ tên, email và role. Server xác minh issuer, audience, signing key và lifetime, ClockSkew 1 phút. JwtService có thời hạn mặc định 720 phút nếu không có cấu hình, **không xác định thời hạn thực tế của deployment**. Frontend không đọc signing key hoặc tự xác minh chữ ký; `/me` là kiểm chứng phía server.

Source không có endpoint logout/revoke cho luồng này. Đăng xuất TriWork xóa token an toàn trên thiết bị và bỏ header trong bộ nhớ; không tuyên bố thu hồi JWT trên server. Không log request body, password, OTP hoặc JWT.

Giới hạn từ source: `Login` kiểm tra IsActive, nhưng `VerifyOtp` và `Me` chưa kiểm tra lại IsActive. TriWork không thể thay thế việc kiểm soát này ở backend; nhóm backend cần đánh giá nếu muốn khóa tài khoản có hiệu lực ngay cho phiên đã cấp.

## Kiểm tra API public

Ngày 29/10/2026, đã gọi HTTPS GET:

- `/swagger/v1/swagger.json`: timeout sau 45 giây, không nhận được mã HTTP.
- `/api/auth/me` (không token): timeout sau 45 giây, không nhận được mã HTTP.

Công cụ web cũng không truy cập được hai URL. Chưa kết luận nguyên nhân là server hay đường mạng của môi trường kiểm tra. Không tắt kiểm tra TLS, không dùng URL backend khác. Không gửi POST đăng ký/OTP, không dùng tài khoản mẫu hay credential trong repo.

Do đó, hợp đồng được xác minh bằng source, **chưa đối chiếu với Swagger/phản hồi live**, chưa xác nhận deployment đồng bộ source và chưa kiểm thử đăng nhập thật.
