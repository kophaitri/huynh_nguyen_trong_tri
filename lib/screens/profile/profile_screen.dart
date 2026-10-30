import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_failure.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/cached_load_view.dart';
import '../settings/settings_screen.dart';
import '../shared/crud_route.dart';
import 'edit_profile_screen.dart';
import '../../services/local_profile_service.dart';
import '../../widgets/profile_avatar.dart';

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
  LocalProfileService? _ownedProfiles;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profiles =
        LocalProfileScope.maybeOf(context) ??
        (_ownedProfiles ??= LocalProfileService());
    final id = widget.auth.user?.id;
    if (id != null && !profiles.belongsTo(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || widget.auth.user?.id != id) return;
        await profiles.bindUser(id);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ownedProfiles?.dispose();
    super.dispose();
  }

  Future<void> _reload() => _loadKey.currentState?.refresh() ?? Future.value();
  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await widget.auth.logout();
    if (mounted) setState(() => _loggingOut = false);
  }

  Future<void> _edit(UserModel user, LocalProfileService profiles) async {
    if (widget.auth.user?.id != user.id) return;
    final restored = await openCrudPage<bool>(
      context,
      widget.auth,
      (_) =>
          EditProfileScreen(user: user, auth: widget.auth, profiles: profiles),
    );
    if (!mounted) return;
    setState(() {});
    if (restored == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final profiles =
        LocalProfileScope.maybeOf(context) ??
        (_ownedProfiles ??= LocalProfileService());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openCrudPage<void>(
              context,
              widget.auth,
              (_) => const SettingsScreen(),
            ),
          ),
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
                    load: (force) => widget.auth.client.get(
                      ApiConfig.me,
                      forceRefresh: force,
                    ),
                    builder: (context, snapshot) {
                      final verified = widget.auth.user;
                      if (verified == null) return const SizedBox.shrink();
                      final json = snapshot.data ?? <String, dynamic>{};
                      UserModel user = verified;
                      String? refreshError;
                      if (snapshot.hasData) {
                        try {
                          final fresh = UserModel.fromJson(json);
                          if (fresh.id == verified.id) user = fresh;
                        } on ApiFailure catch (error) {
                          refreshError = error.message;
                        }
                      }
                      if (snapshot.hasError) {
                        refreshError = snapshot.error is ApiFailure
                            ? (snapshot.error as ApiFailure).message
                            : 'Chưa làm mới được hồ sơ. Đang dùng thông tin tài khoản đã xác minh.';
                      }
                      final local = profiles.forUser(user.id);
                      final displayName = profiles.displayName(
                        user.id,
                        user.fullName,
                      );
                      return Column(
                        children: [
                          if (snapshot.connectionState != ConnectionState.done)
                            const LinearProgressIndicator(),
                          if (refreshError != null)
                            CrudErrorState(
                              message: refreshError,
                              onRetry: _reload,
                            ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  ProfileAvatar(
                                    name: displayName,
                                    path: profiles.avatarFor(user.id),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    displayName,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(user.email, textAlign: TextAlign.center),
                                  const SizedBox(height: 10),
                                  Chip(label: Text(user.roleName)),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Chỉnh sửa thông tin'),
                                    onPressed:
                                        _loggingOut ||
                                            widget.auth.user?.id != user.id
                                        ? null
                                        : () => _edit(user, profiles),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Thông tin cá nhân trên thiết bị'),
                                  if (profiles.loaded == false)
                                    const LinearProgressIndicator(),
                                  if (profiles.error != null) ...[
                                    Text(profiles.error!),
                                    TextButton(
                                      onPressed: () =>
                                          profiles.reloadFor(user.id),
                                      child: const Text('Thử đọc lại'),
                                    ),
                                  ],
                                  _row(
                                    'Số điện thoại',
                                    local?.phone.isNotEmpty == true
                                        ? local!.phone
                                        : 'Chưa bổ sung',
                                  ),
                                  _row(
                                    'Địa chỉ',
                                    local?.address.isNotEmpty == true
                                        ? local!.address
                                        : 'Chưa bổ sung',
                                  ),
                                  _row('Mã người dùng', user.id),
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
                          ),
                        ],
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
                  Text(
                    'Tên, số điện thoại, địa chỉ và ảnh có thể cá nhân hóa trên thiết bị. Email, mã người dùng và vai trò lấy từ máy chủ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
