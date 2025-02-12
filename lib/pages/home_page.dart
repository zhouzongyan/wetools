import 'package:flutter/material.dart';
import 'package:wetools/pages/base64_page.dart';
import 'package:wetools/pages/hash_page.dart';
import 'package:wetools/pages/json_page.dart';
import 'package:wetools/pages/jwt_page.dart';
import 'package:wetools/pages/text_page.dart';
import 'package:wetools/pages/url_page.dart';
import 'time_page.dart';
import 'translate_page.dart';
import 'system_page.dart';
import 'http_page.dart';
import 'tcp_page.dart';
import 'ip_page.dart';
import 'email_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<NavigationRailDestination> _destinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.security),
      label: Text('JWT'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.link),
      label: Text('URL'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.code),
      label: Text('Base64'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.data_object),
      label: Text('JSON'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.key),
      label: Text('Hash'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.text_fields),
      label: Text('Text'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.access_time),
      label: Text('Time'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.translate),
      label: Text('Translate'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.http),
      label: Text('HTTP'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.lan),
      label: Text('TCP'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.email_outlined),
      label: Text('Email'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.public),
      label: Text('IP'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.computer),
      label: Text('System'),
    ),
  ];

  final List<({IconData icon, String title, String subtitle, Widget page})>
      _pages = [
    (
      icon: Icons.token_outlined,
      title: 'JWT工具',
      subtitle: 'JWT令牌的编码和解码',
      page: const JwtPage(),
    ),
    (
      icon: Icons.link_outlined,
      title: 'URL工具',
      subtitle: 'URL编码解码',
      page: const UrlPage(),
    ),
    (
      icon: Icons.code_outlined,
      title: 'Base64工具',
      subtitle: 'Base64编码解码',
      page: const Base64Page(),
    ),
    (
      icon: Icons.data_object_outlined,
      title: 'JSON工具',
      subtitle: 'JSON格式化和压缩',
      page: const JsonPage(),
    ),
    (
      icon: Icons.enhanced_encryption_outlined,
      title: '哈希/加密',
      subtitle: '常用哈希算法和加密解密',
      page: const HashPage(),
    ),
    (
      icon: Icons.text_fields_outlined,
      title: '文本工具',
      subtitle: '文本处理工具集合',
      page: const TextPage(),
    ),
    (
      icon: Icons.access_time_outlined,
      title: '时间工具',
      subtitle: '时间戳转换',
      page: const TimePage(),
    ),
    (
      icon: Icons.translate_outlined,
      title: '文本翻译',
      subtitle: '支持多语言互译',
      page: const TranslatePage(),
    ),
    (
      icon: Icons.http_outlined,
      title: 'HTTP工具',
      subtitle: 'HTTP请求测试',
      page: const HttpPage(),
    ),
    (
      icon: Icons.lan_outlined,
      title: 'TCP工具',
      subtitle: 'TCP连接测试',
      page: const TcpPage(),
    ),
    (
      icon: Icons.email_outlined,
      title: '邮件发送',
      subtitle: '支持SMTP邮件发送，可添加多个附件',
      page: const EmailPage(),
    ),
    (
      icon: Icons.public_outlined,
      title: 'IP工具',
      subtitle: 'IP地址查询',
      page: const IpPage(),
    ),
    (
      icon: Icons.computer_outlined,
      title: '系统信息',
      subtitle: '查看系统信息',
      page: const SystemPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations,
                  minWidth: 85, // 设置最小宽度，避免文字换行
                  useIndicator: true, // 使用指示器
                  groupAlignment: -1, // 将项目对齐到顶部
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex].page,
          ),
        ],
      ),
    );
  }
}
