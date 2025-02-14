import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wetools/widgets/windows_text_field.dart';
import '../utils/theme_util.dart';
import '../services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/proxy_service.dart';
import '../utils/settings_util.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentVersion = '';
  bool _checkingUpdate = false;
  bool _useSystemProxy = true;
  String? _proxyHost;
  int? _proxyPort;
  final _proxyHostController = TextEditingController();
  final _proxyPortController = TextEditingController();

  // 添加临时状态变量
  int _tempMaxHistoryItems = SettingsUtil.defaultMaxHistoryItems;
  int _tempMaxFavoriteItems = SettingsUtil.defaultMaxFavoriteItems;
  int _tempMaxTextLength = SettingsUtil.defaultMaxTextLength;
  int _tempCleanupInterval = SettingsUtil.defaultCleanupInterval;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadProxySettings();
    _loadClipboardSettings();
  }

  @override
  void dispose() {
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> _loadProxySettings() async {
    final useSystemProxy = await ProxyService.getUseSystemProxy();
    final proxyHost = await ProxyService.getProxyHost();
    final proxyPort = await ProxyService.getProxyPort();

    setState(() {
      _useSystemProxy = useSystemProxy;
      _proxyHost = proxyHost;
      _proxyPort = proxyPort;
      _proxyHostController.text = proxyHost ?? '';
      _proxyPortController.text = proxyPort?.toString() ?? '';
    });
  }

  Future<void> _loadClipboardSettings() async {
    _tempMaxHistoryItems = await SettingsUtil.getMaxHistoryItems();
    _tempMaxFavoriteItems = await SettingsUtil.getMaxFavoriteItems();
    _tempMaxTextLength = await SettingsUtil.getMaxTextLength();
    _tempCleanupInterval = await SettingsUtil.getCleanupInterval();
    setState(() {});
  }

  Future<void> _saveClipboardSettings() async {
    await SettingsUtil.setMaxHistoryItems(_tempMaxHistoryItems);
    await SettingsUtil.setMaxFavoriteItems(_tempMaxFavoriteItems);
    await SettingsUtil.setMaxTextLength(_tempMaxTextLength);
    await SettingsUtil.setCleanupInterval(_tempCleanupInterval);

    setState(() {
      _hasUnsavedChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // 通知设置已更改
    SettingsUtil.notifySettingsChanged();
  }

  Future<void> _checkUpdate(BuildContext context) async {
    setState(() {
      _checkingUpdate = true;
    });

    try {
      final result = await UpdateService.checkUpdate();
      if (!mounted) return;

      if (result.hasUpdate) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发现新版本'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最新版本: ${result.latestVersion}'),
                const SizedBox(height: 8),
                if (result.releaseNotes != null) ...[
                  const Text('更新内容:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(result.releaseNotes!),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('稍后再说'),
              ),
              if (result.downloadUrl != null)
                FilledButton(
                  onPressed: () {
                    UpdateService.downloadUpdate(result.downloadUrl!);
                    Navigator.pop(context);
                  },
                  child: const Text('立即更新'),
                ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已是最新版本'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查更新失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  Widget _buildProxySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          '网络代理',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('使用系统代理'),
          subtitle: const Text('跟随系统代理设置'),
          value: _useSystemProxy,
          onChanged: (bool value) async {
            await ProxyService.setUseSystemProxy(value);
            setState(() {
              _useSystemProxy = value;
            });
          },
        ),
        if (!_useSystemProxy) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _proxyHostController,
                    decoration: const InputDecoration(
                      labelText: '代理主机',
                      hintText: '例如: 127.0.0.1',
                    ),
                    onChanged: (value) async {
                      await ProxyService.setProxyHost(
                          value.isEmpty ? null : value);
                      setState(() {
                        _proxyHost = value.isEmpty ? null : value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _proxyPortController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '例如: 7890',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) async {
                      final port = int.tryParse(value);
                      await ProxyService.setProxyPort(port);
                      setState(() {
                        _proxyPort = port;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
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
                    _buildProxySettings(),
                    const Divider(),
                    Text(
                      '剪贴板',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          _buildNumberField(
                            label: '历史记录最大数量',
                            initialValue: _tempMaxHistoryItems,
                            onChanged: (value) {
                              if (value != null && value > 0) {
                                setState(() {
                                  _tempMaxHistoryItems = value;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            label: '收藏夹最大数量',
                            initialValue: _tempMaxFavoriteItems,
                            onChanged: (value) {
                              if (value != null && value > 0) {
                                setState(() {
                                  _tempMaxFavoriteItems = value;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            label: '忽略超过多少字符的文本',
                            initialValue: _tempMaxTextLength,
                            onChanged: (value) {
                              if (value != null && value > 0) {
                                setState(() {
                                  _tempMaxTextLength = value;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            label: '清理间隔（小时）',
                            initialValue: _tempCleanupInterval,
                            onChanged: (value) {
                              if (value != null && value > 0) {
                                setState(() {
                                  _tempCleanupInterval = value;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton(
                                onPressed: _hasUnsavedChanges
                                    ? _saveClipboardSettings
                                    : null,
                                child: const Text('保存设置'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Text(
                      '关于',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('检查更新'),
                      subtitle: SelectableText('当前版本: $_currentVersion'),
                      trailing: _checkingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _checkUpdate(context),
                              child: const Text('检查更新'),
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

  Widget _buildNumberField({
    required String label,
    required int initialValue,
    required Function(int?) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: WindowsTextField(
            controller: TextEditingController(text: initialValue.toString()),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final intValue = int.tryParse(value);
              onChanged(intValue);
            },
          ),
        ),
      ],
    );
  }
}
