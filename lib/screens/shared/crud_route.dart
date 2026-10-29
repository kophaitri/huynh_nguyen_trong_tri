import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

Future<T?> openCrudPage<T>(
  BuildContext context,
  AuthService auth,
  WidgetBuilder builder,
) => Navigator.of(context).push<T>(
  MaterialPageRoute(
    builder: (context) => _SessionGuard(auth: auth, child: builder(context)),
  ),
);

class _SessionGuard extends StatelessWidget {
  const _SessionGuard({required this.auth, required this.child});
  final AuthService auth;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      if (auth.user != null) return child;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
  );
}
