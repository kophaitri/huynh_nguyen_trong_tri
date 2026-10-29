import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_failure.dart';
import '../core/storage/token_storage.dart';
import '../models/otp_challenge.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    required this.client,
    required this.storage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    client.onUnauthorized = () => _clearSession(
      notice: 'Phiên đã hết hạn hoặc bị từ chối. Vui lòng đăng nhập lại.',
    );
  }

  final ApiClient client;
  final TokenStorage storage;
  final DateTime Function() _now;
  final Map<String, DateTime> _resendAt = {};
  final Map<String, DateTime> _serverRetryAt = {};
  final Set<String> _codeRequestsInFlight = {};
  final Map<String, ({OtpChallenge challenge, DateTime expiresAt})>
  _pendingChallenges = {};
  UserModel? _user;
  UserModel? get user => _user;
  bool restoring = true;
  String? sessionError;
  String? notice;
  bool _mustClearStorage = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _restoreOperation;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  int resendSeconds(String identity) {
    final remaining =
        _resendAt[identity.trim().toLowerCase()]
            ?.difference(_now())
            .inMilliseconds ??
        0;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  OtpChallenge? pendingChallengeFor(String identity) {
    final key = identity.trim().toLowerCase();
    final pending = _pendingChallenges[key];
    if (pending == null) return null;
    if (!pending.expiresAt.isAfter(_now())) {
      _pendingChallenges.remove(key);
      return null; // Expiring a flow must not reset resend/server cooldowns.
    }
    return pending.challenge;
  }

  OtpChallenge _rememberChallenge(String identity, OtpPurpose purpose) {
    final challenge = OtpChallenge(identity: identity, purpose: purpose);
    _pendingChallenges[identity.trim().toLowerCase()] = (
      challenge: challenge,
      expiresAt: _now().add(const Duration(minutes: 5)),
    );
    return challenge;
  }

  void _checkCooldown(String identity) {
    final seconds = resendSeconds(identity);
    if (seconds > 0) {
      throw ApiFailure('Vui lòng chờ $seconds giây trước khi yêu cầu mã mới.');
    }
  }

  Future<Map<String, dynamic>> _sendCode(
    String identity,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final key = identity.trim().toLowerCase();
    if (_codeRequestsInFlight.contains(key)) {
      throw const ApiFailure(
        'Yêu cầu mã đang được xử lý. Vui lòng đợi kết quả.',
        code: 'OTP_IN_FLIGHT',
      );
    }
    final serverUntil = _serverRetryAt[key];
    if (serverUntil != null && serverUntil.isAfter(_now())) {
      final seconds = (serverUntil.difference(_now()).inMilliseconds / 1000)
          .ceil();
      throw ApiFailure(
        'Máy chủ yêu cầu chờ $seconds giây trước khi gửi yêu cầu mới.',
        statusCode: 429,
      );
    }
    final isResend = path == ApiConfig.resendOtp;
    if (isResend) {
      _checkCooldown(identity);
    } else if (pendingChallengeFor(identity) != null) {
      // A confirmed OTP flow is resumed by the UI, never replayed as a new POST.
      throw const ApiFailure(
        'Đã có yêu cầu OTP. Hãy tiếp tục nhập mã đã gửi.',
        code: 'OTP_PENDING',
      );
    }
    final previousUntil = _resendAt[key];
    _codeRequestsInFlight.add(key);
    // Also covers an uncertain timeout: the server might already have sent mail.
    final nextUntil = _now().add(ApiConfig.resendCooldown);
    _resendAt[key] = previousUntil != null && previousUntil.isAfter(nextUntil)
        ? previousUntil
        : nextUntil;
    try {
      return await client.post(path, payload);
    } on ApiFailure catch (error) {
      if (error.statusCode == 429 || error.retryAfter != null) {
        final retryAfter = error.retryAfter ?? ApiConfig.resendCooldown;
        final wait = retryAfter > ApiConfig.resendCooldown
            ? retryAfter
            : ApiConfig.resendCooldown;
        final until = _now().add(wait);
        _serverRetryAt[key] = until;
        _resendAt[key] = _resendAt[key]!.isAfter(until)
            ? _resendAt[key]!
            : until;
      } else if (error.statusCode == 400 ||
          error.statusCode == 401 ||
          error.statusCode == 403) {
        if (previousUntil == null) {
          _resendAt.remove(key);
        } else {
          _resendAt[key] = previousUntil;
        }
      }
      rethrow;
    } finally {
      _codeRequestsInFlight.remove(key);
    }
  }

  Future<OtpChallenge> login(String email, String password) async {
    final identity = email.trim();
    final result = await _sendCode(identity, ApiConfig.login, {
      'userNameOrEmail': identity,
      'password': password,
    });
    if (result['requiresOtp'] != true) {
      throw const ApiFailure(
        'Máy chủ không xác nhận bước OTP. Chưa thể đăng nhập.',
      );
    }
    return _rememberChallenge(identity, OtpPurpose.login);
  }

  Future<OtpChallenge> register(
    String fullName,
    String email,
    String password,
  ) async {
    final identity = email.trim();
    final result = await _sendCode(identity, ApiConfig.register, {
      'email': identity,
      'password': password,
      'fullName': fullName.trim(),
    });
    if (result['requiresEmailVerification'] != true) {
      throw const ApiFailure('Máy chủ không xác nhận bước xác minh email.');
    }
    return _rememberChallenge(identity, OtpPurpose.registration);
  }

  Future<void> resendOtp(OtpChallenge challenge) async {
    await _sendCode(challenge.identity, ApiConfig.resendOtp, {
      'userNameOrEmail': challenge.identity,
    });
    _rememberChallenge(challenge.identity, challenge.purpose);
  }

  Future<void> verifyOtp(OtpChallenge challenge, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiFailure('Vui lòng nhập đủ 6 chữ số.');
    }
    final generation = _generation;
    final result = await client.post(ApiConfig.verifyOtp, {
      'userNameOrEmail': challenge.identity,
      'code': code,
    });
    final token = result['token'];
    if (token is! String || token.trim().isEmpty) {
      throw const ApiFailure(
        'Máy chủ không trả về token hợp lệ. Chưa thể đăng nhập.',
      );
    }
    if (generation != _generation || _disposed) return;
    _pendingChallenges.remove(challenge.identity.trim().toLowerCase());
    try {
      await storage.write(token).timeout(ApiConfig.storageDeadline);
    } catch (_) {
      // A platform write can fail after partially persisting the item.
      await _clearSession();
      throw const ApiFailure(
        'Không thể lưu phiên an toàn trên thiết bị. Vui lòng đăng nhập lại.',
      );
    }
    if (generation != _generation || _disposed) {
      await _clearSession();
      return;
    }
    // OTP was accepted, but a dashboard still requires /me validation.
    await restoreSession();
  }

  Future<void> restoreSession() {
    final pending = _restoreOperation;
    if (pending != null) return pending;
    final operation = _restoreSession();
    _restoreOperation = operation;
    return operation.whenComplete(() {
      if (identical(_restoreOperation, operation)) _restoreOperation = null;
    });
  }

  Future<void> _restoreSession() async {
    if (_mustClearStorage) {
      await logout();
      return;
    }
    final generation = _generation;
    restoring = true;
    sessionError = null;
    _user = null;
    client.token = null;
    _changed();
    String? token;
    try {
      token = await storage.read().timeout(ApiConfig.storageDeadline);
    } catch (_) {
      sessionError =
          'Không thể đọc phiên an toàn trên thiết bị. Vui lòng thử lại.';
    }
    if (generation != _generation || _disposed) return;
    if (token != null && token.isNotEmpty) {
      client.token = token;
      try {
        // Cache is for display only. A session always needs a live server check.
        final data = await client.get(ApiConfig.me, forceRefresh: true);
        if (generation != _generation || _disposed) return;
        _user = UserModel.fromJson(data);
        notice = null;
      } on ApiFailure catch (error) {
        if (generation != _generation || _disposed) return;
        if (error.isUnauthorized) {
          await _clearSession(notice: error.message);
        } else {
          // Keep a valid-looking token on transient errors, but grant no access.
          client.token = null;
          sessionError = error.message;
        }
      }
    }
    restoring = false;
    _changed();
  }

  Future<void> retrySession() async {
    if (_mustClearStorage) {
      await logout();
    } else {
      await restoreSession();
    }
  }

  Future<void> _clearSession({String? notice}) async {
    _generation++;
    _restoreOperation = null;
    _user = null;
    client.token = null;
    this.notice = notice;
    sessionError = null;
    _mustClearStorage = true;
    restoring = true;
    _changed();
    try {
      await storage.delete().timeout(ApiConfig.storageDeadline);
      _mustClearStorage = false;
    } catch (_) {
      sessionError =
          'Không thể xóa phiên đã lưu. Vui lòng thử lại để hoàn tất đăng xuất.';
    }
    restoring = false;
    _changed();
  }

  Future<void> logout() => _clearSession();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    client.close();
    super.dispose();
  }
}
