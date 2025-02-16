import 'dart:io';
import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/all.dart' as highlight;
import '../utils/logger_util.dart';

class HostsPage extends StatefulWidget {
  const HostsPage({super.key});

  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  late CodeController _hostsController;
  String? _errorText;
  bool _isDarkMode = false;
  String _hostsPath = '';
  bool _isSaving = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _hostsController = CodeController(
      text: '',
      language: highlight.allLanguages['hosts'],
    );
    _loadHostsFile();
    _checkAdminPrivileges();
  }

  @override
  void dispose() {
    _hostsController.dispose();
    super.dispose();
  }

  Future<void> _loadHostsFile() async {
    try {
      if (Platform.isWindows) {
        _hostsPath = 'C:\\Windows\\System32\\drivers\\etc\\hosts';
      } else if (Platform.isMacOS || Platform.isLinux) {
        _hostsPath = '/etc/hosts';
      } else {
        setState(() {
          _errorText = '不支持的操作系统';
        });
        return;
      }

      final file = File(_hostsPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          _hostsController.text = content;
        });
      } else {
        setState(() {
          _errorText = 'hosts文件不存在';
        });
      }
    } catch (e, stack) {
      LoggerUtil.error('读取hosts文件失败', e, stack);
      setState(() {
        _errorText = '读取hosts文件失败: $e';
      });
    }
  }

  Future<void> _saveHostsFile() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      if (Platform.isWindows) {
        // 创建临时文件
        final tempFile = File('${Directory.systemTemp.path}\\hosts_temp');
        await tempFile.writeAsString(_hostsController.text);

        // 创建 PowerShell 脚本
        final psContent = '''
\$ErrorActionPreference = "Stop"
try {
    # 检查管理员权限
    \$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not \$isAdmin) {
        throw "需要管理员权限"
    }

    # 备份原文件
    Copy-Item -Path "$_hostsPath" -Destination "${_hostsPath}.bak" -Force
    
    # 写入新内容
    \$content = Get-Content -Path "${tempFile.path}" -Raw
    Set-Content -Path "$_hostsPath" -Value \$content -Force
    
    # 清理文件
    Remove-Item -Path "${tempFile.path}" -Force
    Remove-Item -Path "${_hostsPath}.bak" -Force
} catch {
    if (Test-Path "${_hostsPath}.bak") {
        Copy-Item -Path "${_hostsPath}.bak" -Destination "$_hostsPath" -Force
        Remove-Item -Path "${_hostsPath}.bak" -Force
    }
    throw \$_.Exception.Message
}
''';

        final psFile = File('${Directory.systemTemp.path}\\update_hosts.ps1');
        await psFile.writeAsString(psContent);

        // 执行 PowerShell 脚本
        final process = await Process.run('powershell', [
          '-Command',
          'Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File \'${psFile.path}\'"',
        ]);

        // 清理临时文件
        await psFile.delete();

        if (process.exitCode != 0) {
          LoggerUtil.error('保存hosts文件失败', process.stderr, StackTrace.current);
          throw Exception('保存失败: ${process.stderr}');
        }

        // 验证文件内容
        final newContent = await File(_hostsPath).readAsString();
        if (newContent.trim() != _hostsController.text.trim()) {
          throw Exception('文件内容验证失败，请重试');
        }
      } else {
        final tempFile = File('/tmp/hosts_temp');
        await tempFile.writeAsString(_hostsController.text);

        final process = await Process.run('pkexec', [
          'sh',
          '-c',
          'mv "${tempFile.path}" "$_hostsPath" && chmod 644 "$_hostsPath"'
        ]);

        if (process.exitCode != 0) {
          throw Exception('需要管理员权限，请在弹出的窗口中输入密码');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存成功'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stack) {
      LoggerUtil.error('保存hosts文件失败', e, stack);
      setState(() {
        _errorText = '保存失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _checkAdminPrivileges() async {
    if (Platform.isWindows) {
      try {
        final psContent = '''
# 检查 hosts 文件的写入权限
try {
    \$stream = [System.IO.File]::Open("$_hostsPath", [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
    \$stream.Close()
    exit 0
} catch {
    exit 1
}
''';
        final psFile =
            File('${Directory.systemTemp.path}\\check_hosts_permission.ps1');
        await psFile.writeAsString(psContent);

        final process = await Process.run(
            'powershell', ['-ExecutionPolicy', 'Bypass', '-File', psFile.path]);

        await psFile.delete();

        setState(() {
          _isAdmin = process.exitCode == 0;
        });
      } catch (e) {
        setState(() {
          _isAdmin = false;
        });
        LoggerUtil.error('检查 hosts 文件权限失败', e, StackTrace.current);
      }
    }
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hosts 文件编辑器',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (Platform.isWindows) // 移除 !_isAdmin 条件，始终显示权限状态
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _isAdmin ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: _isAdmin ? Colors.green[300]! : Colors.red[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: _isAdmin ? Colors.green[700] : Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  SelectableText(
                    _isAdmin ? '已获取管理员权限' : '需要管理员权限',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isAdmin ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SelectableText(
            '文件路径: $_hostsPath',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).hintColor,
            ),
          ),
          if (!_isAdmin && Platform.isWindows) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '如何获取管理员权限：',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. 关闭当前程序\n'
                    '2. 右键点击程序图标\n'
                    '3. 选择"以管理员身份运行"\n'
                    '4. 在弹出的权限请求窗口中点击"是"',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 修改按钮样式的方法
  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool showProgress = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 36, // 固定高度
      child: ElevatedButton.icon(
        icon: showProgress
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 16), // 统一图标大小
        label: Text(
          label,
          style: const TextStyle(fontSize: 13), // 统一字体大小
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 定义编辑器颜色方案
    final editorTheme = {
      'background': _isDarkMode ? Colors.grey[900]! : Colors.grey[50]!,
      'text': _isDarkMode ? Colors.grey[100]! : Colors.grey[900]!,
      'border': _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
    };

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleSection(),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SelectableText(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: editorTheme['border']!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CodeField(
                      controller: _hostsController,
                      textStyle: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 14,
                        color: editorTheme['text'],
                      ),
                      lineNumberStyle: LineNumberStyle(
                        textStyle: TextStyle(
                          color: _isDarkMode ? Colors.grey[600] : Colors.grey[500],
                        ),
                        width: 48,
                      ),
                      background: editorTheme['background'],
                      expands: true,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 右侧按钮区域
        Container(
          width: 100, // 减小宽度
          padding: const EdgeInsets.all(12.0), // 减小内边距
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildButton(
                icon: Icons.refresh,
                label: '刷新',
                onPressed: _isSaving ? null : _loadHostsFile,
              ),
              const SizedBox(height: 8),
              _buildButton(
                icon: Icons.save,
                label: '保存',
                onPressed: (!_isAdmin && Platform.isWindows) || _isSaving
                    ? null
                    : _saveHostsFile,
                showProgress: _isSaving,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
