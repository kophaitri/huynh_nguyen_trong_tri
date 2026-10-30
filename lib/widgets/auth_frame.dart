import 'package:flutter/material.dart';

import 'triwork_logo.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainer,
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerLow,
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: onBack,
                            tooltip: 'Quay lại',
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                      const TriWorkLogo(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C132D50),
                              blurRadius: 32,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            child,
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TRIWORK  •  CHẤM CÔNG NHÂN VIÊN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {super.key, this.isError = true});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          height: 1.4,
          color: isError
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    ),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? Semantics(
            label: 'Đang xử lý',
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Text(label),
  );
}
