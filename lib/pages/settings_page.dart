import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_util.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '自定义应用的外观和行为',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '外观',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('主题模式'),
                      subtitle: const Text('选择应用的主题模式'),
                      trailing: Consumer<ThemeUtil>(
                        builder: (context, themeUtil, child) {
                          return DropdownButton<ThemeMode>(
                            value: themeUtil.themeMode,
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('跟随系统'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('浅色'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('深色'),
                              ),
                            ],
                            onChanged: (ThemeMode? newMode) {
                              if (newMode != null) {
                                themeUtil.setThemeMode(newMode);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('开机自启'),
                      subtitle: const Text('应用随系统启动'),
                      trailing: Consumer<ThemeUtil>(
                        builder: (context, themeUtil, child) {
                          return Switch(
                            value: themeUtil.autoStart,
                            onChanged: (bool value) {
                              themeUtil.setAutoStart(value);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 