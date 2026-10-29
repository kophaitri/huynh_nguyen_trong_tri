import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_failure.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/cached_load_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth, this.active = true});
  final AuthService auth;
  final bool active;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _loadKey = GlobalKey<CachedLoadViewState<Map<String, dynamic>>>();
  bool _loggingOut = false;
  Future<void> _reload() => _loadKey.currentState?.refresh() ?? Future.value();
  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await widget.auth.logout();
    if (mounted) setState(() => _loggingOut = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hồ sơ của tôi'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loggingOut ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CachedLoadView<Map<String, dynamic>>(
                  key: _loadKey,
                  active: widget.active,
                  cached: () {
                    final data = widget.auth.client.cached(ApiConfig.me);
                    return data is Map<String, dynamic> ? data : null;
                  },
                  load: (force) =>
                      widget.auth.client.get(ApiConfig.me, forceRefresh: force),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError && !snapshot.hasData) {
                      return CrudErrorState(
                        message: snapshot.error is ApiFailure
                            ? (snapshot.error as ApiFailure).message
                            : 'Không đọc được hồ sơ.',
                        onRetry: _reload,
                      );
                    }
                    final json = snapshot.data!;
                    UserModel user;
                    try {
                      user = UserModel.fromJson(json);
                    } on ApiFailure catch (error) {
                      return CrudErrorState(
                        message: error.message,
                        onRetry: _reload,
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: const Color(0xFF132D50),
                              child: Text(
                                user.fullName.trim().isEmpty
                                    ? '?'
                                    : user.fullName
                                          .trim()
                                          .characters
                                          .first
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              user.fullName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(user.email, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Chip(label: Text(user.roleName)),
                            const Divider(height: 32),
                            _row(
                              'Mã nhân viên',
                              json['employeeCode'] is String
                                  ? json['employeeCode'] as String
                                  : json.containsKey('employeeCode') &&
                                        json['employeeCode'] == null
                                  ? 'Chưa được cấp'
                                  : 'Chưa đủ dữ liệu',
                            ),
                            _row(
                              'Phòng ban',
                              json['departmentId'] is int
                                  ? 'Mã #${json['departmentId']}'
                                  : json.containsKey('departmentId') &&
                                        json['departmentId'] == null
                                  ? 'Chưa được phân công'
                                  : 'Chưa đủ dữ liệu',
                            ),
                            _row(
                              'Khuôn mặt đã đăng ký',
                              _boolean(json['hasFace']),
                            ),
                            _row(
                              'Thiết bị đã gắn',
                              _boolean(json['deviceBound']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(_loggingOut ? 'Đang đăng xuất…' : 'Đăng xuất'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thông tin hồ sơ được đọc từ máy chủ. Liên hệ quản lý nếu bạn cần cập nhật thông tin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF63738A)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  String _boolean(dynamic value) => value == true
      ? 'Có'
      : value == false
      ? 'Chưa'
      : 'Chưa đủ dữ liệu';
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('$label: $value'),
    ),
  );
}
