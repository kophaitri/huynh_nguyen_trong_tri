import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../screens/auth/auth_gate.dart';
import '../services/auth_service.dart';

class TriWorkApp extends StatefulWidget {
  const TriWorkApp({super.key, this.authService});
  final AuthService? authService;

  @override
  State<TriWorkApp> createState() => _TriWorkAppState();
}

class _TriWorkAppState extends State<TriWorkApp> {
  late final AuthService _auth =
      widget.authService ??
      AuthService(client: ApiClient(), storage: SecureTokenStorage());

  @override
  void dispose() {
    if (widget.authService == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF132D50);
    return MaterialApp(
      title: 'TriWork',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE3EE)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: AuthGate(auth: _auth),
    );
  }
}
