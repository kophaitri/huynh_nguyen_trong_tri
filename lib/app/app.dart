import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../screens/auth/auth_gate.dart';
import '../services/auth_service.dart';
import '../services/app_settings_service.dart';
import '../services/local_profile_service.dart';
import 'app_theme.dart';

class TriWorkApp extends StatefulWidget {
  const TriWorkApp({
    super.key,
    this.authService,
    this.settingsService,
    this.localProfileService,
  });
  final AuthService? authService;
  final AppSettingsService? settingsService;
  final LocalProfileService? localProfileService;

  @override
  State<TriWorkApp> createState() => _TriWorkAppState();
}

class _TriWorkAppState extends State<TriWorkApp> {
  late final AuthService _auth =
      widget.authService ??
      AuthService(client: ApiClient(), storage: SecureTokenStorage());

  late final _settings = widget.settingsService ?? AppSettingsService();
  late final _profiles = widget.localProfileService ?? LocalProfileService();
  void _bindProfile() {
    unawaited(_profiles.bindUser(_auth.user?.id));
    unawaited(_settings.bindUser(_auth.user?.id));
  }

  @override
  void initState() {
    super.initState();
    _auth.addListener(_bindProfile);
    _bindProfile();
  }

  @override
  void dispose() {
    if (widget.settingsService == null) _settings.dispose();
    _auth.removeListener(_bindProfile);
    if (widget.localProfileService == null) _profiles.dispose();
    if (widget.authService == null) _auth.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Reconnect bindings after hot reload as well as a normal cold start.
    _auth.removeListener(_bindProfile);
    _auth.addListener(_bindProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindProfile();
    });
  }

  @override
  Widget build(BuildContext context) => LocalProfileScope(
    service: _profiles,
    child: AppSettingsScope(
      service: _settings,
      child: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) => MaterialApp(
          title: 'TriWork',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          theme: AppTheme.create(_settings.value.accent, Brightness.light),
          darkTheme: AppTheme.create(_settings.value.accent, Brightness.dark),
          themeMode: _settings.effectiveThemeMode,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  media.textScaler.scale(1) * _settings.value.textSize.scale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AuthGate(auth: _auth),
        ),
      ),
    ),
  );
}
