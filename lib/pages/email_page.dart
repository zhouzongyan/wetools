import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../utils/clipboard_util.dart';
import 'package:image_picker/image_picker.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({super.key});

  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _smtpController = TextEditingController();
  final _portController = TextEditingController(text: '465');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _attachments = [];
  bool _isSending = false;
  bool _useSSL = true;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _smtpController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final file = await _picker.pickMedia();
      if (file != null) {
        setState(() {
          _attachments.add(file);
        });
      }
    } catch (e) {
      if (mounted) {
        ClipboardUtil.showSnackBar(
          '选择文件失败: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      final smtpServer = SmtpServer(
        _smtpController.text,
        port: int.parse(_portController.text),
        ssl: _useSSL,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      final message = Message()
        ..from = Address(_fromController.text)
        ..recipients.addAll(_toController.text.split(',').map((e) => e.trim()))
        ..subject = _subjectController.text
        ..text = _contentController.text;

      // 添加附件
      for (var file in _attachments) {
        message.attachments.add(
          FileAttachment(File(file.path))
            ..fileName = file.name
            ..contentType = 'application/octet-stream'
            ..location = Location.attachment,
        );
      }


      if (mounted) {
        ClipboardUtil.showSnackBar(
          '邮件发送成功！',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        ClipboardUtil.showSnackBar(
          '发送失败: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _smtpController.clear();
      _portController.text = '465';
      _usernameController.clear();
      _passwordController.clear();
      _fromController.clear();
      _toController.clear();
      _subjectController.clear();
      _contentController.clear();
      _attachments.clear();
      _useSSL = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '邮件发送',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '支持SMTP邮件发送，可添加多个附件',
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
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _smtpController,
                              decoration: const InputDecoration(
                                labelText: 'SMTP服务器',
                                hintText: '例如: smtp.gmail.com',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入SMTP服务器地址';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: '端口',
                                hintText: '465',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入端口';
                                }
                                if (int.tryParse(value!) == null) {
                                  return '请输入有效的端口号';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: '用户名',
                                hintText: '邮箱账号',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入用户名';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: '密码',
                                hintText: '邮箱密码或授权码',
                              ),
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: true,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入密码';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fromController,
                              decoration: const InputDecoration(
                                labelText: '发件人',
                                hintText: '发件人邮箱地址',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入发件人地址';
                                }
                                if (!value!.contains('@')) {
                                  return '请输入有效的邮箱地址';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _toController,
                              decoration: const InputDecoration(
                                labelText: '收件人',
                                hintText: '多个收件人用逗号分隔',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return '请输入收件人地址';
                                }
                                if (!value!.contains('@')) {
                                  return '请输入有效的邮箱地址';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: '主题',
                          hintText: '邮件主题',
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return '请输入邮件主题';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: '内容',
                          hintText: '邮件正文',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return '请输入邮件内容';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('添加附件'),
                          ),
                          const SizedBox(width: 16),
                          Checkbox(
                            value: _useSSL,
                            onChanged: (value) {
                              setState(() {
                                _useSSL = value ?? true;
                              });
                            },
                          ),
                          const Text('使用SSL'),
                        ],
                      ),
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.map((file) {
                            return Chip(
                              label: Text(file.name),
                              onDeleted: () {
                                setState(() {
                                  _attachments.remove(file);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSending ? null : _sendEmail,
                              child: _isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('发送邮件'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: _resetForm,
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
