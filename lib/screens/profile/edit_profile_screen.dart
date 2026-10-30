import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_failure.dart';
import '../../core/validation/profile_validators.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/local_profile_service.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.user,
    required this.auth,
    required this.profiles,
  });
  final UserModel user;
  final AuthService auth;
  final LocalProfileService profiles;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _picker = ImagePicker();
  String? _selectedImage;
  String? _savedAvatar;
  String? _error;
  bool _permissionError = false;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.auth.user?.id != widget.user.id) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Phiên tài khoản đã thay đổi. Vui lòng mở lại hồ sơ.';
        });
      }
      return;
    }
    await widget.profiles.bindUser(widget.user.id);
    if (!mounted) return;
    final local = widget.profiles.forUser(widget.user.id);
    setState(() {
      _name.text = local?.fullName ?? widget.user.fullName;
      _phone.text = local?.phone ?? '';
      _address.text = local?.address ?? '';
      _savedAvatar = widget.profiles.avatarFor(widget.user.id);
      _error = widget.profiles.error;
      _busy = false;
    });
  }

  Future<void> _retryLocal() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.profiles.reloadFor(widget.user.id);
    if (mounted) await _load();
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _permissionError = false;
    });
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo == null || !mounted) return;
      if (await photo.length() > 8 * 1024 * 1024) {
        throw const LocalProfileException('Vui lòng chọn ảnh nhỏ hơn 8 MB.');
      }
      final codec = await ui.instantiateImageCodec(
        await photo.readAsBytes(),
        targetWidth: 512,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _selectedImage = photo.path);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _permissionError =
              e.code.toLowerCase().contains('access') ||
              e.code.toLowerCase().contains('denied');
          _error = _permissionError
              ? 'Cho phép truy cập ảnh trong cài đặt để chọn ảnh đại diện.'
              : 'Chưa chọn được ảnh. Vui lòng thử lại.';
        });
      }
    } on LocalProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không đọc được ảnh. Hãy chọn ảnh JPG hoặc PNG khác.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.auth.user?.id != widget.user.id) {
        throw const LocalProfileException(
          'Phiên tài khoản đã thay đổi. Hãy mở lại hồ sơ.',
        );
      }
      await widget.profiles.save(
        userId: widget.user.id,
        fullName: _name.text,
        phone: _phone.text,
        address: _address.text,
        selectedImagePath: _selectedImage,
      );
      if (mounted && widget.auth.user?.id == widget.user.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin trên thiết bị')),
        );
        Navigator.pop(context, false);
      }
    } on LocalProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa lưu được thông tin. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final confirmed = await confirmCrudAction(
      context,
      title: 'Khôi phục thông tin từ máy chủ?',
      message: 'Tên sẽ trở về dữ liệu máy chủ. Số điện thoại, địa chỉ và ảnh cá nhân hóa trên thiết bị sẽ được xóa.',
      confirmLabel: 'Khôi phục',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await widget.auth.client.get(
        ApiConfig.me,
        forceRefresh: true,
      );
      final server = UserModel.fromJson(json);
      if (server.id != widget.user.id ||
          widget.auth.user?.id != widget.user.id) {
        throw const LocalProfileException(
          'Phiên tài khoản đã thay đổi. Hãy mở lại hồ sơ.',
        );
      }
      await widget.profiles.restore(server.id, serverName: server.fullName);
      if (mounted && widget.auth.user?.id == widget.user.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã khôi phục thông tin từ máy chủ')),
        );
        Navigator.pop(context, true);
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LocalProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa khôi phục được. Kiểm tra kết nối rồi thử lại; thông tin trên thiết bị vẫn được giữ.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    'Thông tin cá nhân trên thiết bị',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ProfileAvatar(
                      name: _name.text,
                      path: _selectedImage ?? _savedAvatar,
                      radius: 48,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh đại diện'),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (widget.profiles.error != null)
                    TextButton(
                      onPressed: _busy ? null : _retryLocal,
                      child: const Text('Thử đọc lại'),
                    ),
                  if (_permissionError)
                    TextButton(
                      onPressed: Geolocator.openAppSettings,
                      child: const Text('Mở cài đặt ảnh'),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('profile-name'),
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    validator: ProfileValidators.fullName,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-phone'),
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    maxLength: 30,
                    validator: ProfileValidators.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-address'),
                    controller: _address,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    validator: ProfileValidators.address,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _serverField('Email', widget.user.email),
                  const SizedBox(height: 16),
                  _serverField('Mã người dùng', widget.user.id),
                  const SizedBox(height: 16),
                  _serverField('Vai trò', widget.user.roleName),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu thay đổi'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Khôi phục thông tin từ máy chủ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _serverField(String label, String value) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Icon(Icons.lock_outline),
    ),
    child: SelectableText(value),
  );
}
