import 'package:flutter/material.dart';

import '../../models/app_settings_model.dart';
import '../../services/app_settings_service.dart';
import '../../widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = AppSettingsScope.of(context);
    final value = service.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!service.loaded || service.saving)
                  const LinearProgressIndicator(),
                if (service.error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      service.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SettingsSection(
                  title: 'Cỡ chữ toàn ứng dụng',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final size in AppTextSize.values)
                        ChoiceChip(
                          label: Text(size.label),
                          selected: value.textSize == size,
                          onSelected: service.canEdit
                              ? (_) => service.update(
                                  service.value.copyWith(textSize: size),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                SettingsSection(
                  title: 'Màu chủ đạo và màu nền',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final accent in AppAccent.values)
                        ChoiceChip(
                          label: Text(accent.label),
                          avatar: CircleAvatar(
                            backgroundColor: accent.color,
                            radius: 10,
                          ),
                          selected: value.accent == accent,
                          onSelected: service.canEdit
                              ? (_) => service.update(
                                  service.value.copyWith(accent: accent),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                SettingsSection(
                  title: 'Chế độ hiển thị',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in ThemeMode.values)
                        ChoiceChip(
                          label: Text(switch (mode) {
                            ThemeMode.light => 'Sáng',
                            ThemeMode.dark => 'Tối',
                            ThemeMode.system => 'Theo hệ thống',
                          }),
                          selected: value.themeMode == mode,
                          onSelected: service.canEdit
                              ? (_) => service.update(
                                  service.value.copyWith(themeMode: mode),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                const SettingsPreview(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: service.canEdit ? service.reset : null,
                  icon: const Icon(Icons.restore),
                  label: const Text('Khôi phục cài đặt mặc định'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chỉ lưu tùy chọn giao diện trên thiết bị. Cài đặt vẫn giữ khi đăng xuất; không lưu thông tin tài khoản ở đây.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
