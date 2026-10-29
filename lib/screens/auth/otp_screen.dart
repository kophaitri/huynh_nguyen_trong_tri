import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_failure.dart';
import '../../core/validation/auth_validators.dart';
import '../../models/otp_challenge.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_frame.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.auth, required this.challenge});
  final AuthService auth;
  final OtpChallenge challenge;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.auth.verifyOtp(widget.challenge, _code.text);
      _code.clear();
      if (mounted) {
        setState(() => _busy = false);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || widget.auth.resendSeconds(widget.challenge.identity) > 0) {
      return;
    }
    setState(() {
      _busy = true;
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.auth.resendOtp(widget.challenge);
      _code.clear();
      if (mounted) {
        setState(
          () => _info =
              'Đã yêu cầu mã mới. Vui lòng kiểm tra hộp thư và thư rác.',
        );
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.auth.resendSeconds(widget.challenge.identity);
    return PopScope(
      canPop: !_busy,
      child: AuthFrame(
        title: widget.challenge.purpose == OtpPurpose.registration
            ? 'Xác minh email'
            : 'Xác thực đăng nhập',
        subtitle:
            'Nhập mã 6 số được gửi đến ${widget.challenge.identity}. Mã có hiệu lực 5 phút, tối đa 5 lần thử.',
        onBack: _busy ? null : () => Navigator.of(context).pop(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) AuthMessage(_error!),
              if (_info != null) AuthMessage(_info!, isError: false),
              TextFormField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: AuthValidators.otp,
                onFieldSubmitted: (_) => _verify(),
                decoration: const InputDecoration(
                  labelText: 'Mã OTP',
                  hintText: '6 chữ số',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 24),
              AuthButton(label: 'Xác nhận', busy: _busy, onPressed: _verify),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy || seconds > 0 ? null : _resend,
                child: Text(
                  _resending
                      ? 'Đang gửi mã…'
                      : seconds > 0
                      ? 'Gửi lại mã sau ${seconds}s'
                      : 'Gửi lại mã OTP',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
