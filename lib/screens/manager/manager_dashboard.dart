import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/dashboard_shell.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key, required this.user, required this.auth});
  final UserModel user;
  final AuthService auth;

  @override
  Widget build(BuildContext context) => DashboardShell(
    title: 'Không gian quản lý',
    icon: Icons.groups_outlined,
    user: user,
    auth: auth,
  );
}
