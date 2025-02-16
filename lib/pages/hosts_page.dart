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
          _hostsController.text = content.split('\n').map((line) {
            return line.replaceAll(RegExp(r'\s+'), ' ');
          }).join('\n');
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
      String content = _hostsController.text.split('\n').map((line) {
        return line.trim().replaceAll(RegExp(r'\s+'), ' ');
      }).join('\n');

      if (!content.endsWith('\n')) {
        content = '$content\n';
      }
      
      if (Platform.isWindows) {
        content = content.replaceAll('\n', '\r\n');
      }

      if (Platform.isWindows) {
        final file = File(_hostsPath);
        final backupFile = File('${_hostsPath}.bak');
        await file.copy(backupFile.path);
        
        try {
          await file.writeAsString(content);
          
          final newContent = await file.readAsString();
          if (newContent.replaceAll('\r\n', '\n').trim() != content.replaceAll('\r\n', '\n').trim()) {
            await backupFile.copy(_hostsPath);
            throw Exception('文件内容验证失败');
          }
        } finally {
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
        }
        
        await _loadHostsFile();
      } else {
        final tempFile = File('/tmp/hosts_temp');
        await tempFile.writeAsString(content);

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
      await _loadHostsFile();
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
        final testContent = await File(_hostsPath).readAsString();
        await File(_hostsPath).writeAsString(testContent);
        
        setState(() {
          _isAdmin = true;
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
          if (Platform.isWindows)
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

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool showProgress = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 36,
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
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13),
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
        Container(
          width: 100,
          padding: const EdgeInsets.all(12.0),
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
