# TriWork — Báo cáo Bước 3

- Sinh viên: **Huỳnh Nguyễn Trọng Trí** — MSSV **2380614104** — Nhóm **9**.
- Project/package giữ nguyên: `huynh_nguyen_trong_tri`; tên hiển thị **TriWork**.
- Frontend Flutter/Dart. Không tạo project mới, không lấy frontend từ repository backend.
- API duy nhất: `https://vupham309-001-site1.etempurl.com`.

## 1. File tạo/sửa

File tạo mới:

```text
lib/core/network/json_reader.dart
lib/core/validation/crud_validators.dart
lib/models/employee_model.dart
lib/models/department_model.dart
lib/models/shift_model.dart
lib/models/work_location_model.dart
lib/models/leave_request_model.dart
lib/models/paged_response.dart
lib/services/crud_service_base.dart
lib/services/employee_service.dart
lib/services/department_service.dart
lib/services/shift_service.dart
lib/services/location_service.dart
lib/services/leave_service.dart
lib/screens/shared/crud_route.dart
lib/screens/shared/crud_form_frame.dart
lib/screens/shared/record_list_screen.dart
lib/screens/employees/employee_screen.dart
lib/screens/departments/department_screen.dart
lib/screens/shifts/shift_screen.dart
lib/screens/locations/location_screen.dart
lib/screens/leaves/leave_screen.dart
lib/widgets/crud_widgets.dart
test/crud_service_test.dart
test/crud_widget_test.dart
test/support/crud_fixtures.dart
docs/step3_report.md
```

File sửa:

```text
lib/core/config/api_config.dart
lib/core/network/api_client.dart
lib/core/network/api_failure.dart
lib/widgets/dashboard_shell.dart
README.md
```

Không thêm dependency ở Bước 3. `flutter pub get` sử dụng pubspec hiện có. Không sửa native configuration hoặc logic login/OTP/token storage. Không xóa `.gitkeep`, dữ liệu hoặc file có sẵn. Workspace không có `.git`; danh sách dựa trên thao tác đã thực hiện, không phải git diff. Không liệt kê cache/build artifacts do Flutter sinh.

## 2. Endpoint, DTO và response thực tế

Đã đọc trực tiếp ngày 29/10/2026:

- [API.md](https://github.com/MinhVu309/23dthe1-pham-minh-vu/blob/main/smartcheck/API.md).
- Trong `smartcheck/23DTHE1_pham_minh_vu 2/`: `Controllers/EmployeesController.cs`, `Controllers/CrudController.cs`, `Controllers/LeavesController.cs`, `Dtos/Dtos.cs`, `Models/Entities.cs`.
- Không đọc file secret, appsettings, tài khoản mẫu hoặc frontend trong repository này.

Tất cả CRUD dùng Bearer JWT hiện có. Phần dưới mô tả **source**, không phải kết quả mutation trên deployment live. JSON camelCase; enum dạng chuỗi.

### Nhân viên — id string (ASP.NET Identity user id)

| Method | Route | Quyền | Request / response |
| --- | --- | --- | --- |
| GET | `/api/employees?q=&departmentId=&page=1&pageSize=20` | Admin/Manager | Page envelope; q tìm FullName/Email/EmployeeCode, departmentId nullable int |
| GET | `/api/employees/{id}` | Admin/Manager | 200 chi tiết, 404 nếu không có |
| POST | `/api/employees` | Admin | EmployeeCreateDto; 201 `{id,fullName,email}` |
| PUT | `/api/employees/{id}` | Admin | EmployeeUpdateDto; 204 không body |
| DELETE | `/api/employees/{id}` | Admin | 204 không body; 404 nếu không có |

Phân trang backend: page tối thiểu 1; pageSize mặc định 20, giới hạn 1–100. Sắp theo FullName. TriWork dùng 20 bản ghi/trang và tìm kiếm server có debounce. Service cũng hỗ trợ departmentId.

Page response:

```json
{
  "total": 1, "page": 1, "pageSize": 20,
  "items": [{"id":"<id>","fullName":"<ten>","email":"<email>","employeeCode":null,
    "departmentId":null,"department":null,"isActive":true,"hasFace":false}]
}
```

GET detail trả `{id,fullName,email,employeeCode,departmentId,isActive,role}`. **List không có role**; form sửa gọi GET detail để lấy role chính xác, không mặc định ghi đè role từ list. Không dùng hasFace để triển khai tính năng khuôn mặt.

EmployeeCreateDto:

```json
{"email":"<email-cua-ban>","password":"<mat-khau-da-an>","fullName":"<ten>",
 "employeeCode":"TRI-TEST-<ma-rieng>","departmentId":null,"role":"Employee"}
```

Email required/EmailAddress; password required/MinLength(6), Identity yêu cầu chữ thường và số; fullName required. employeeCode nullable string, departmentId nullable int. Role mặc định Employee trong DTO; chỉ Admin/Manager/Employee hợp lệ. Tạo nhân viên bởi Admin được backend đánh dấu EmailConfirmed=true; đây là endpoint quản trị, khác đăng ký email/OTP của người dùng.

EmployeeUpdateDto:

```json
{"fullName":"<ten>","employeeCode":null,"departmentId":null,"role":"Manager","isActive":true}
```

FullName required; role nullable string, isActive bool mặc định true. **Không có email/password** trong DTO update: form chỉ đọc email và không gửi lại password. Admin có thể chọn role của nhân viên đang quản lý; điều này không phải người đăng nhập tự chọn quyền. Nguồn quyền hiện tại của ứng dụng vẫn là `/me`. Sửa tài khoản chính mình sẽ xác minh lại `/me`; xóa chính mình sẽ logout.

### Phòng ban / ca làm / địa điểm — id int

Ba controller kế thừa `CrudController<T>` và bind entity, không có DTO riêng cho ba nhóm này.

| Method | Route | Quyền | Response |
| --- | --- | --- | --- |
| GET | `/api/departments`, `/api/shifts`, `/api/locations` | Mọi người đã đăng nhập | 200 `{total,page,pageSize,items}` |
| GET | Các route trên + `/{id:int}` | Mọi người đã đăng nhập | 200 entity / 404 |
| POST | Collection tương ứng | Admin | 201 entity; server đặt Id=0 trước khi insert |
| PUT | Collection + `/{id:int}` | Admin | 200 entity; id lấy từ route |
| DELETE | Collection + `/{id:int}` | Admin | 204; 404; 409 khi dữ liệu đang được tham chiếu |

GET list nhận page/pageSize, mặc định page=1/pageSize=50, pageSize giới hạn 1–200. UI dùng 20; dropdown phòng ban/ca làm đọc nối các trang với pageSize=200 để không bỏ sót lựa chọn sau trang đầu. Không có q/search server cho các nhóm này: ô tìm kiếm được ghi rõ **Tìm trong trang hiện tại**, không giả vờ đã tìm toàn bộ database.

Body POST/PUT phòng ban:

```json
{"name":"TRI-TEST-<phong-ban-rieng>","description":"<mo-ta-hoac-null>"}
```

Name string; description nullable string; id int ở response. Entity có navigation `employees`; frontend không gửi hoặc dùng navigation này.

Body POST/PUT ca làm:

```json
{"name":"TRI-TEST-<ca-rieng>","startTime":"08:00:00","endTime":"17:00:00","lateToleranceMinutes":10}
```

StartTime/EndTime là TimeSpan, truyền đúng HH:mm:ss; lateToleranceMinutes int. Frontend kiểm tra 00–23 giờ, 00–59 phút/giây, tolerance không âm. Không áp đặt end > start vì ca qua đêm có thể có giờ kết thúc nhỏ hơn giờ bắt đầu. Source chưa có quy tắc kiểm tra ca qua đêm/ngày cho CRUD này.

Body POST/PUT địa điểm:

```json
{"name":"TRI-TEST-<dia-diem-rieng>","address":"<dia-chi-hoac-null>",
 "latitude":10.8,"longitude":106.7,"radiusMeters":100,"shiftId":21}
```

Latitude/Longitude double; radiusMeters/shiftId int; address nullable string. Frontend kiểm tra tên không trống, latitude [-90,90], longitude [-180,180], số hữu hạn, bán kính nguyên dương, shiftId dương và chọn từ dữ liệu ca làm thực tế. Response entity có thêm id và navigation shift có thể null; frontend không gửi navigation shift. Không thêm bản đồ, GPS hoặc xin quyền vị trí trong Bước 3.

Các ràng buộc an toàn trên form được kiểm tra cả ở service; số nguyên nhập phải trong phạm vi Int32. Entity backend chưa có DataAnnotations cho toàn bộ các ràng buộc tọa độ/bán kính/tên nên không tuyên bố server cũng áp dụng tất cả kiểm tra frontend này.

### Đơn nghỉ phép — id int

| Method | Route | Quyền thực tế theo source | Response |
| --- | --- | --- | --- |
| GET | `/api/leaves?status=Pending` | Employee: của mình; Admin/Manager: tất cả | 200 mảng, **không phân trang** |
| POST | `/api/leaves` | Người đã đăng nhập; server gán UserId của token | 201 `{id}` |
| PUT | `/api/leaves/{id:int}` | Chủ đơn, chỉ Pending | 204; 404 nếu không có/không phải chủ; 409 nếu đã xử lý |
| DELETE | `/api/leaves/{id:int}` | Chủ đơn khi Pending; **Admin được xóa cả đơn người khác/đã xử lý** | 204 / 404 / 409 |
| POST | `/api/leaves/{id:int}/review` | Admin/Manager | 204; 404 |

**Không có GET `/api/leaves/{id}`**, không tự gọi route này dù POST trả Location trỏ tới đó. Thông tin đơn hiển thị từ array list. Không có status Cancelled; hủy là DELETE thực sự, không tạo endpoint cancel giả.

LeaveCreateDto dùng chung POST và PUT:

```json
{"fromDate":"2026-11-02","toDate":"2026-11-03","reason":"<ly-do>"}
```

Ngày là DateOnly (`yyyy-MM-dd`), reason required string. UserId, Status, ReviewedBy không được client tự gửi. UI/service kiểm tra ngày tồn tại, khoảng ngày đúng và lý do không trắng. Source chỉ kiểm tra khoảng ngày ở Create, chưa kiểm tra ở Update.

LeaveReviewDto:

```json
{"approve":true}
```

Approve=false để từ chối. UI yêu cầu xác nhận và chỉ hiện nút duyệt/từ chối cho đơn Pending. Backend hiện cho review lại đơn đã xử lý; UI giới hạn hơn để tránh thao tác nhầm.

GET array item:

```json
{"id":41,"userId":"<id>","userName":"<ten>","fromDate":"2026-11-02","toDate":"2026-11-03",
 "reason":"<ly-do>","status":"Pending","createdAt":"2026-10-29T01:00:00Z"}
```

Status là Pending/Approved/Rejected. CreatedAt UTC, hiển thị bằng giờ local của thiết bị; ngày nghỉ giữ nguyên DateOnly, không chuyển UTC làm lệch ngày. Employee được lọc thêm theo userId ở service, nhưng backend vẫn phải thực thi quyền. Admin/Manager có thể tạo đơn của chính mình vì POST cho phép mọi người đã đăng nhập; không thể tự gán người khác làm chủ đơn.

## 3. Các thao tác hoàn thành

- Nhân viên: list có tìm kiếm server/phân trang; GET detail; Admin thêm/sửa/xóa; Manager chỉ đọc. Form lấy phòng ban và role thực tế trước khi sửa. Không có nút ghi cho Manager/Employee.
- Phòng ban, ca làm, địa điểm: list/phân trang, tìm trên trang hiện tại; Admin thêm/sửa/xóa có xác nhận; các role khác chỉ đọc. Dữ liệu dropdown từ API, không dùng dữ liệu CRUD giả trong app.
- Nghỉ phép: list/lọc trạng thái/tìm trong array; tạo đơn của mình; chủ đơn sửa/hủy khi Pending; Admin có quyền xóa đặc biệt đúng source; Admin/Manager duyệt/từ chối sau xác nhận.
- Menu dashboard theo role lấy từ server; navy/trắng Material 3; Wrap cho nút để tránh tràn ngang; form cuộn khi có bàn phím.
- Dùng chung search bar, status badge, empty/error state, confirm dialog, text field, form frame và list/phân trang.
- Mở màn hình/form chỉ GET. POST/PUT/DELETE chỉ sau thao tác gửi form hoặc xác nhận của người dùng. Không có seed/mutation tự động, không tự retry mutation khi timeout.
- Dio tái sử dụng JWT; hỗ trợ map/array/204; xử lý lỗi parse, 401/403/404/409/422/500, timeout/mất mạng, retry GET do người dùng bấm.
- 401 xóa phiên và đóng toàn bộ route được bảo vệ; 403 CRUD thông báo thiếu quyền và giữ phiên. 403 `/me` vẫn xóa phiên như Bước 2. Phản hồi 401 cũ không được xóa token mới.
- Không dùng LogInterceptor hoặc in JWT/password/OTP. Không hiện thông báo thành công khi request thất bại; mutation timeout nhắc làm mới để tránh gửi trùng.

## 4. Kết quả kiểm tra

| Lệnh | Kết quả cuối cùng |
| --- | --- |
| `flutter pub get` | Thành công; không thêm dependency ở Bước 3 |
| `flutter analyze` | **No issues found!** |
| `flutter test` | **78/78 tests passed**: 38 test xác thực cũ + 27 test service CRUD + 13 widget test CRUD |
| `flutter build apk --debug` | Thành công, APK cuối tại `build/app/outputs/flutter-apk/app-debug.apk` |

Các test sử dụng MockHttpAdapter, không thể rơi xuống HTTP thật; dữ liệu giả chỉ nằm trong `test/support`. APK debug bao gồm nhiều kiến trúc, kích thước khoảng 176 MiB; đây chưa phải release build. Không chạy/cài lại trên emulator ở Bước 3; kiểm thử giao diện là widget test, không tuyên bố CRUD đã chạy trên thiết bị với server thật.

Các nhóm đã kiểm tra: CRUD từng service, DTO/kiểu dữ liệu, Bearer token, quyền service/UI, list vs detail employee, 204, phân trang/lookups nhiều trang, 401/403/404/409/422/500, timeout, parse sai, validation tọa độ/thời gian/ngày, xác nhận xóa/duyệt, form nhỏ 320×568 có bàn phím, phản hồi tìm kiếm đến sai thứ tự và hồi quy xác thực.

## 5. API public

Ngày 29/10/2026, timeout đặt 15 giây cho từng GET an toàn, không Bearer token:

- `GET https://vupham309-001-site1.etempurl.com/api/departments?page=1&pageSize=1` → **HTTP 401 Unauthorized**.
- `GET https://vupham309-001-site1.etempurl.com/api/auth/me` → **HTTP 401 Unauthorized**.

Host HTTPS đã phản hồi trong lần kiểm tra Bước 3, khác lần timeout Bước 2. 401 là kết quả đúng khi không có token, **không chứng minh đã đọc được dữ liệu hay CRUD thành công**. Không gọi POST/PUT/DELETE lên server thật.

## 6. Chưa kiểm thử live và nguyên nhân

Chưa có tài khoản/token Admin do người dùng cung cấp, nên chưa thử đọc dữ liệu sau đăng nhập, thêm/sửa/xóa nhân viên/phòng ban/ca/địa điểm, tạo/cập nhật/hủy/duyệt đơn trên deployment thật. Không dùng credential mẫu hoặc tài khoản của thành viên khác. Chưa xác nhận deployment và source GitHub đồng bộ hoàn toàn.

Không thể xác định chủ sở hữu dữ liệu phòng ban/ca/địa điểm từ API vì không có createdBy/owner. Vì vậy quá trình làm việc này không chỉnh sửa/xóa bất kỳ bản ghi live nào, đặc biệt dữ liệu DEMO. Test mock và build thành công không thay thế kiểm thử live.

## 7. Hướng dẫn kiểm tra thủ công bằng tài khoản Admin

```sh
flutter pub get
flutter run
```

1. Đăng nhập bằng email/mật khẩu tài khoản bạn sở hữu đã được nhóm backend cấp Admin; nhập OTP gửi về hộp thư của bạn. `/me` phải trả role Admin.
2. Mở từng menu, làm mới, thử tìm kiếm/phân trang. Chỉ đọc dữ liệu hiện hữu. Manager dùng cùng màn hình nhưng không có nút ghi cho danh mục/nhân viên.
3. Tạo **phòng ban riêng**, **ca riêng**, **địa điểm riêng** với tiền tố `TRI-TEST-2380614104-<thoi-diem>` để nhận diện. Chọn ca mới cho địa điểm mới; không sửa ca/địa điểm của người khác.
4. Với ca, nhập HH:mm:ss; tolerance nguyên không âm. Với địa điểm, nhập tọa độ hợp lệ/bán kính nguyên dương; đây chỉ là nhập dữ liệu, không gọi GPS.
5. Nếu được nhóm cho phép, tạo nhân viên thử bằng email bạn kiểm soát, mã riêng và phòng ban vừa tạo. Mở chi tiết, sửa tên/mã/phòng ban/role/isActive; email không sửa qua endpoint này. Không thử trên tài khoản mẫu DEMO hoặc tài khoản thành viên khác.
6. Tạo đơn nghỉ của chính mình với ngày yyyy-MM-dd và lý do nhận diện rõ. Khi Pending, sửa/hủy để kiểm tra. Tạo một đơn riêng khác để kiểm tra duyệt/từ chối bằng Admin/Manager. Không xử lý đơn của người khác khi chưa được họ cho phép.
7. Kiểm tra lỗi bằng validation trên form; không cố tạo FK sai hoặc làm tải server. Không đổi role/xóa tài khoản Admin đang dùng chỉ để thử lỗi. Token hết hạn sẽ về login; thiếu quyền CRUD hiện 403 mà không tự logout.
8. Nếu cần dọn dữ liệu, chỉ xóa đúng các bản ghi riêng đã tạo ở các bước trên, kiểm tra tên/id trong xác nhận. Gỡ phụ thuộc trước: địa điểm trước ca, nhân viên trước phòng ban. Nếu 409 đang dùng, dừng và kiểm tra liên kết; không xóa dữ liệu chung để né lỗi. Việc xóa nhân viên có lịch sử có thể bị backend từ chối; không xóa lịch sử chấm công để xử lý.

## 8. Giới hạn/chưa hỗ trợ phía backend

- Không có GET detail, phân trang hoặc tìm kiếm server cho leaves. Không có q cho departments/shifts/locations, nên chỉ tìm tại trang hiện tại. Không tự tạo endpoint để bù.
- EmployeeUpdateDto không hỗ trợ sửa email/password; form không gửi các trường này. Các endpoint khuôn mặt/reset thiết bị không dùng trong Bước 3.
- Hủy leave là hard DELETE, không có trạng thái Cancelled hay lịch sử hủy. Reviewer source chưa kiểm tra Pending trước khi review và chưa có optimistic concurrency; UI kiểm tra Pending không thay thế kiểm tra nguyên tử phía server khi hai người xử lý cùng lúc.
- Leaves Update thiếu kiểm tra khoảng ngày ở source; frontend kiểm tra nhưng cần backend bổ sung để bảo vệ mọi client.
- CRUD entity danh mục chưa có đủ validation/ownership metadata, không có soft delete/ETag. Generic list chưa có OrderBy rõ ràng, nên thứ tự/phân trang có thể thay đổi khi dữ liệu chung thay đổi. Frontend tải lại và lùi trang khi trang cuối bị rỗng.
- Employees Update/Delete không kiểm tra đầy đủ IdentityResult trước khi trả 204; lỗi ràng buộc có thể trả 500. Frontend xử lý phản hồi lỗi nhưng không thể bảo đảm backend đã ghi nếu server trả 204 sai; cần kiểm tra lại bằng GET live.
- JWT chứa role lúc phát hành; đổi role/isActive không có cơ chế revoke ngay trong source đã đối chiếu. TriWork không tự cấp quyền hoặc giải quyết được việc thu hồi JWT phía server. Không thay đổi luồng xác thực để né quyền.

Chưa triển khai QR, GPS, Face Detection hoặc chấm công.
