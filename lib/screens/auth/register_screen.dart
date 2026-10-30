import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/validation/auth_validators.dart';
import '../../models/otp_challenge.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_frame.dart';
import '../../widgets/password_field.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _openingOtp = false;
  String? _error;
  OtpChallenge? get _pendingChallenge =>
      widget.auth.pendingChallengeFor(_email.text);

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _openOtp(OtpChallenge challenge) async {
    if (_openingOtp || !mounted) return;
    _openingOtp = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OtpScreen(auth: widget.auth, challenge: challenge),
        ),
      );
    } finally {
      _openingOtp = false;
    }
  }

  Future<void> _register() async {
    if (_busy) return;
    final pending = _pendingChallenge;
    if (pending != null) {
      await _openOtp(pending);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await widget.auth.register(
        _fullName.text,
        _email.text,
        _password.text,
      );
      _password.clear();
      _confirmation.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      await _openOtp(challenge);
    } on ApiFailure catch (error) {
      if (error.code == 'OTP_PENDING' && mounted && _pendingChallenge != null) {
        setState(() => _busy = false);
        await _openOtp(_pendingChallenge!);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AuthFrame(
      title: 'Tạo tài khoản',
      subtitle: 'Sử dụng email của bạn. Xác minh email để hoàn tất đăng ký.',
      onBack: _busy ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthMessage(_error!),
            TextFormField(
              controller: _fullName,
              enabled: !_busy,
              validator: AuthValidators.fullName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              onChanged: (_) => setState(() => _error = null),
              enabled: !_busy,
              validator: AuthValidators.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _password,
              validator: AuthValidators.newPassword,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            Text(
              'Ít nhất 6 ký tự, có chữ thường và số.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _confirmation,
              enabled: !_busy,
              label: 'Xác nhận mật khẩu',
              validator: (value) =>
                  value == null || value.isEmpty || value != _password.text
                  ? 'Mật khẩu xác nhận chưa khớp.'
                  : null,
              onSubmitted: _register,
            ),
            const SizedBox(height: 24),
            AuthButton(
              label: _pendingChallenge == null
                  ? 'Đăng ký và nhận mã'
                  : 'Tiếp tục nhập OTP đã yêu cầu',
              busy: _busy,
              onPressed: _register,
            ),
            if (_pendingChallenge != null)
              TextButton(
                onPressed: _busy ? null : _register,
                child: const Text('Tiếp tục xác minh email đã đăng ký'),
              ),
          ],
        ),
      ),
    ),
  );
}
