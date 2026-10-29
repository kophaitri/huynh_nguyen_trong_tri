import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/validation/auth_validators.dart';
import '../../models/otp_challenge.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_frame.dart';
import '../../widgets/password_field.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _openingOtp = false;
  String? _error;
  OtpChallenge? get _pendingChallenge =>
      widget.auth.pendingChallengeFor(_email.text);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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

  Future<void> _login() async {
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
      final challenge = await widget.auth.login(_email.text, _password.text);
      _password.clear();
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
  Widget build(BuildContext context) => AuthFrame(
    title: 'Chào mừng trở lại',
    subtitle: 'Đăng nhập để bắt đầu ngày làm việc của bạn.',
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthMessage(_error!),
          if (widget.auth.notice != null && _error == null)
            AuthMessage(widget.auth.notice!, isError: false),
          TextFormField(
            controller: _email,
            onChanged: (_) => setState(() => _error = null),
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: AuthValidators.email,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'ban@congty.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          PasswordField(
            controller: _password,
            validator: AuthValidators.password,
            enabled: !_busy,
            onSubmitted: _login,
          ),
          const SizedBox(height: 28),
          AuthButton(
            label: _pendingChallenge == null
                ? 'Đăng nhập'
                : 'Tiếp tục nhập OTP',
            busy: _busy,
            onPressed: _login,
          ),
          if (_pendingChallenge != null)
            TextButton(
              onPressed: _busy ? null : _login,
              child: const Text('Nhập mã OTP đã gửi'),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(auth: widget.auth),
                    ),
                  ),
            child: const Text('Chưa có tài khoản? Đăng ký'),
          ),
        ],
      ),
    ),
  );
}
