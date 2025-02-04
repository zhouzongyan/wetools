import 'package:flutter/material.dart';
import 'package:system_info2/system_info2.dart';
import 'dart:io';
import '../utils/clipboard_util.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  late String _systemInfo = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadSystemInfo();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadSystemInfo() {
    compute<void, String>((message) async {
      final info = StringBuffer();

      // 操作系统信息
      info.writeln('操作系统信息:');
      info.writeln('系统名称: ${Platform.operatingSystem}');
      info.writeln('系统版本: ${Platform.operatingSystemVersion}');
      info.writeln('本地语言: ${Platform.localeName}');
      info.writeln('主机名: ${Platform.localHostname}');
      info.writeln('处理器架构: ${Platform.operatingSystemVersion}');
      info.writeln('是否64位系统: ${Platform.version.contains('64')}');

      // CPU 信息
      info.writeln('\nCPU信息:');
      info.writeln('处理器数量: ${SysInfo.cores}');
      info.writeln('处理器架构: ${SysInfo.kernelArchitecture}');
      info.writeln('处理器位数: ${SysInfo.kernelBitness}位');

      // 内存信息
      final totalPhysMem =
          SysInfo.getTotalPhysicalMemory() / (1024 * 1024 * 1024);
      final freePhysMem =
          SysInfo.getFreePhysicalMemory() / (1024 * 1024 * 1024);
      final usedPhysMem = totalPhysMem - freePhysMem;
      final totalVirtMem =
          SysInfo.getTotalVirtualMemory() / (1024 * 1024 * 1024);
      final freeVirtMem = SysInfo.getFreeVirtualMemory() / (1024 * 1024 * 1024);
      final usedVirtMem = totalVirtMem - freeVirtMem;

      info.writeln('\n内存信息:');
      info.writeln('物理内存总量: ${totalPhysMem.toStringAsFixed(2)} GB');
      info.writeln('已用物理内存: ${usedPhysMem.toStringAsFixed(2)} GB');
      info.writeln('可用物理内存: ${freePhysMem.toStringAsFixed(2)} GB');
      info.writeln(
          '内存使用率: ${(usedPhysMem / totalPhysMem * 100).toStringAsFixed(1)}%');
      info.writeln('\n虚拟内存总量: ${totalVirtMem.toStringAsFixed(2)} GB');
      info.writeln('已用虚拟内存: ${usedVirtMem.toStringAsFixed(2)} GB');
      info.writeln('可用虚拟内存: ${freeVirtMem.toStringAsFixed(2)} GB');
      info.writeln(
          '虚拟内存使用率: ${(usedVirtMem / totalVirtMem * 100).toStringAsFixed(1)}%');

      // 内核信息
      info.writeln('\n内核信息:');
      info.writeln('内核名称: ${SysInfo.kernelName}');
      info.writeln('内核版本: ${SysInfo.kernelVersion}');
      info.writeln('操作系统名称: ${SysInfo.operatingSystemName}');
      info.writeln('操作系统版本: ${SysInfo.operatingSystemVersion}');

      // 时区信息
      info.writeln('\n时区信息:');
      info.writeln('当前时区: ${DateTime.now().timeZoneName}');
      info.writeln('时区偏移: ${DateTime.now().timeZoneOffset.inHours}小时');

      // 网络信息
      info.writeln('\n网络信息:');
      try {
        final interfaces = await NetworkInterface.list();
        for (var interface in interfaces) {
          info.writeln('网卡名称: ${interface.name}');
          for (var addr in interface.addresses) {
            info.writeln('IP地址: ${addr.address}');
          }
        }
      } catch (e) {
        info.writeln('无法获取网络信息');
      }

      return info.toString();
    }, null)
        .then((result) {
      if (mounted) {
        setState(() {
          _systemInfo = result;
        });
      }
    });
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
              '系统信息',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '显示当前系统的硬件和软件信息',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('系统详情:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadSystemInfo,
                          tooltip: '刷新',
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => ClipboardUtil.copyToClipboard(
                              _systemInfo, context),
                          tooltip: '复制全部',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _systemInfo,
                      style: Theme.of(context).textTheme.bodyMedium,
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
