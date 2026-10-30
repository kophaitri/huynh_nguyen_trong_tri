import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/app_settings_service.dart';
import '../../widgets/auth_frame.dart';
import '../admin/admin_dashboard.dart';
import '../employee/employee_dashboard.dart';
import '../manager/manager_dashboard.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.auth.restoreSession());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      if (auth.restoring) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Đang kiểm tra phiên đăng nhập…'),
              ],
            ),
          ),
        );
      }
      if (auth.sessionError != null) {
        return AuthFrame(
          title: 'Chưa thể xác minh phiên',
          subtitle: 'Vui lòng thử lại để tiếp tục sử dụng TriWork.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthMessage(auth.sessionError!),
              FilledButton(
                onPressed: auth.retrySession,
                child: const Text('Thử lại'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: auth.logout,
                child: const Text('Xóa phiên và về đăng nhập'),
              ),
            ],
          ),
        );
      }
      final user = auth.user;
      if (user == null) return LoginScreen(auth: auth);
      final settings = AppSettingsScope.maybeOf(context);
      if (settings != null && !settings.readyFor(user.id)) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return switch (user.role) {
        UserRole.admin => AdminDashboard(user: user, auth: auth),
        UserRole.manager => ManagerDashboard(user: user, auth: auth),
        UserRole.employee => EmployeeDashboard(user: user, auth: auth),
      };
    },
  );
}
