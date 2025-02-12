import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/clipboard_util.dart';

class IpPage extends StatefulWidget {
  const IpPage({super.key});

  @override
  State<IpPage> createState() => _IpPageState();
}

class _IpPageState extends State<IpPage> {
  String _localIps = '';
  String _foreignPublicIp = '';
  String _foreignIpInfo = '';
  String _chinaPublicIp = '';
  String _chinaIpInfo = '';
  bool _isLoadingLocal = false;
  bool _isLoadingForeign = false;
  bool _isLoadingChina = false;

  @override
  void initState() {
    super.initState();
    _loadAllIpInfo();
  }

  Future<void> _loadAllIpInfo() async {
    await Future.wait([
      _loadLocalIpInfo(),
      _loadForeignIpInfo(),
      _loadChinaIpInfo(),
    ]);
  }

  Future<void> _loadLocalIpInfo() async {
    setState(() {
      _isLoadingLocal = true;
    });

    try {
      final interfaces = await NetworkInterface.list();
      final localIps = StringBuffer();
      for (var interface in interfaces) {
        localIps.writeln('网卡: ${interface.name}');
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            localIps.writeln('IPv4: ${addr.address}');
          } else if (addr.type == InternetAddressType.IPv6) {
            localIps.writeln('IPv6: ${addr.address}');
          }
        }
        localIps.writeln('');
      }

      setState(() {
        _localIps = localIps.toString();
      });
    } catch (e) {
      if (mounted) {
        ClipboardUtil.showSnackBar(
          '获取本地网络信息失败',
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocal = false;
      });
    }
  }

  Future<void> _loadForeignIpInfo() async {
    setState(() {
      _isLoadingForeign = true;
    });

    try {
      final foreignResponse =
          await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (foreignResponse.statusCode == 200) {
        final data = json.decode(foreignResponse.body);
        _foreignPublicIp = data['ip'];

        final foreignIpInfoResponse = await http.get(
            Uri.parse('http://ip-api.com/json/$_foreignPublicIp?lang=zh-CN'));

        if (foreignIpInfoResponse.statusCode == 200) {
          final ipData =
              json.decode(utf8.decode(foreignIpInfoResponse.bodyBytes));
          _foreignIpInfo = '''
国家: ${ipData['country']}
地区: ${ipData['regionName']}
城市: ${ipData['city']}
ISP: ${ipData['isp']}
经度: ${ipData['lon']}
纬度: ${ipData['lat']}
时区: ${ipData['timezone']}
''';
        }
      }
    } catch (e) {
      _foreignPublicIp = '获取失败';
      _foreignIpInfo = '无法获取国外IP信息';
    } finally {
      setState(() {
        _isLoadingForeign = false;
      });
    }
  }

  Future<void> _loadChinaIpInfo() async {
    setState(() {
      _isLoadingChina = true;
    });

    try {
      final chinaResponse = await http.get(
        Uri.parse('https://myip.ipip.net/json'),
        headers: {'User-Agent': 'curl/7.74.0'},
      );

      if (chinaResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(chinaResponse.bodyBytes));
        if (data['ret'] == 'ok') {
          _chinaPublicIp = data['data']['ip'];
          _chinaIpInfo = '''
国家: ${data['data']['location'][0]}
省份: ${data['data']['location'][1]}
城市: ${data['data']['location'][2]}
运营商: ${data['data']['location'][3]}
''';
        }
      }
    } catch (e) {
      _chinaPublicIp = '获取失败';
      _chinaIpInfo = '无法获取国内IP信息';
    } finally {
      setState(() {
        _isLoadingChina = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP 信息',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '显示本地和公网IP信息',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              title: '本地网络',
              content: _localIps,
              isLoading: _isLoadingLocal,
              onRefresh: _loadLocalIpInfo,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: '国外公网IP (api.ipify.org)',
              content: '''
IP: $_foreignPublicIp

$_foreignIpInfo''',
              isLoading: _isLoadingForeign,
              onRefresh: _loadForeignIpInfo,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: '国内公网IP (myip.ipip.net)',
              content: '''
IP: $_chinaPublicIp

$_chinaIpInfo''',
              isLoading: _isLoadingChina,
              onRefresh: _loadChinaIpInfo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required bool isLoading,
    required VoidCallback onRefresh,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '刷新',
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () =>
                      ClipboardUtil.copyToClipboard(content, context),
                  tooltip: '复制',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                content.isEmpty ? '无数据' : content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
