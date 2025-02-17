import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProcessPage extends StatefulWidget {
  const ProcessPage({super.key});

  @override
  State<ProcessPage> createState() => _ProcessPageState();
}

class _ProcessPageState extends State<ProcessPage> {
  final _searchController = TextEditingController();
  String _searchText = '';
  String _searchType = '进程名称';
  List<ProcessInfo> _processes = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  String _sortBy = '内存';
  bool _sortAscending = false;
  bool _hasAdminPrivilege = false;
  Timer? _refreshTimer;
  String _viewMode = '列表';
  String _groupBy = '无';
  Set<String> _selectedProcesses = {};
  Map<String, List<ProcessInfo>> _groupedProcesses = {};
  String? _scriptsPath;

  @override
  void initState() {
    super.initState();
    _initScripts().then((_) {
      _checkAdminPrivilege();
    });
  }

  Future<void> _initScripts() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _scriptsPath = path.join(tempDir.path, 'wetools_scripts');

      // 创建脚本目录
      final scriptDir = Directory(_scriptsPath!);
      if (!scriptDir.existsSync()) {
        scriptDir.createSync();
      }

      // 解压脚本文件
      await _extractScript('scripts/get_processes.ps1');
      await _extractScript('scripts/get_process_details.ps1');
      await _extractScript('scripts/get_process_tree.ps1');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化脚本文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _extractScript(String assetPath) async {
    try {
      final scriptContent = await rootBundle.loadString(assetPath);
      final scriptName = path.basename(assetPath);
      final scriptFile = File(path.join(_scriptsPath!, scriptName));
      await scriptFile.writeAsString(scriptContent);
    } catch (e) {
      throw Exception('提取脚本 $assetPath 失败: $e');
    }
  }

  String _getScriptPath(String scriptName) {
    return path.join(_scriptsPath ?? '', scriptName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminPrivilege() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('net', ['session']);
        setState(() {
          _hasAdminPrivilege = result.exitCode == 0;
        });
        _refreshProcesses();
      }
    } catch (e) {
      setState(() {
        _hasAdminPrivilege = false;
      });
    }
  }

  Future<void> _refreshProcesses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_scriptsPath == null) {
        throw Exception('脚本路径未初始化');
      }

      if (_isFirstLoad && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('首次获取进程信息可能需要较长时间，请耐心等待...'),
            duration: Duration(seconds: 10),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final result = await Process.run(
        'powershell',
        ['-File', _getScriptPath('get_processes.ps1')],
        stdoutEncoding: const SystemEncoding(),
      );

      if (!mounted) return;

      if (result.exitCode != 0) {
        throw result.stderr;
      }

      final List<dynamic> processData = json.decode(result.stdout);
      setState(() {
        _processes = processData.map((data) {
          final memoryKB = double.tryParse(data['Memory'].toString()) ?? 0;
          return ProcessInfo(
            name: data['Name'] ?? '',
            pid: data['Id'].toString(),
            memory: _formatMemorySize(memoryKB),
            rawMemory: memoryKB.toString(),
            ports: data['Ports'] ?? 'None',
          );
        }).toList();
        _sortProcesses();
        _updateGroupedProcesses();
        _isFirstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取进程列表失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatMemorySize(double kb) {
    try {
      if (kb >= 1024 * 1024) {
        return '${(kb / (1024 * 1024)).toStringAsFixed(2)} GB';
      } else if (kb >= 1024) {
        return '${(kb / 1024).toStringAsFixed(2)} MB';
      } else {
        return '${kb.toStringAsFixed(2)} KB';
      }
    } catch (e) {
      return '0 KB';
    }
  }

  double _parseMemory(String memory) {
    try {
      if (memory.contains('GB')) {
        return double.parse(memory.replaceAll(' GB', '')) * 1024 * 1024;
      } else if (memory.contains('MB')) {
        return double.parse(memory.replaceAll(' MB', '')) * 1024;
      } else if (memory.contains('KB')) {
        return double.parse(memory.replaceAll(' KB', ''));
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  void _sortProcesses() {
    switch (_sortBy) {
      case '进程名称':
        _processes.sort((a, b) => _sortAscending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case 'PID':
        _processes.sort((a, b) => _sortAscending
            ? int.parse(a.pid).compareTo(int.parse(b.pid))
            : int.parse(b.pid).compareTo(int.parse(a.pid)));
        break;
      case '内存':
        _processes.sort((a, b) {
          final memoryA = _parseMemory(a.memory);
          final memoryB = _parseMemory(b.memory);
          return _sortAscending
              ? memoryA.compareTo(memoryB)
              : memoryB.compareTo(memoryA);
        });
        break;
    }
  }

  Future<void> _killProcess(String pid) async {
    try {
      if (Platform.isWindows) {
        final processInfo = _processes.firstWhere((p) => p.pid == pid);

        final result = await Process.run('taskkill', ['/F', '/PID', pid]);

        if (result.exitCode == 0) {
          await _refreshProcesses();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('进程已终止\n'
                    '进程名称: ${processInfo.name}\n'
                    'PID: ${processInfo.pid}\n'
                    '内存占用: ${processInfo.memory}'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(8),
              ),
            );
          }
        } else {
          throw Exception(result.stderr);
        }
      } else {
        await Process.run('kill', ['-9', pid]);
        await _refreshProcesses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('终止进程失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    }
  }

  Future<void> _showProcessDetails(ProcessInfo process) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          ProcessDetailsDialog(process: process, scriptsPath: _scriptsPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProcesses = _getFilteredProcesses();

    Widget? warningBanner;
    if (!_hasAdminPrivilege) {
      warningBanner = Container(
        padding: const EdgeInsets.all(8),
        color: Colors.orange.withOpacity(0.1),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '提示: 当前程序未以管理员权限运行,部分功能可能受限。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warningBanner != null) warningBanner,
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '进程管理',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '进程总数: ${filteredProcesses.length}${_searchText.isNotEmpty ? ' (已过滤)' : ''}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              if (_hasAdminPrivilege) ...[
                                const Icon(
                                  Icons.admin_panel_settings,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const Text(
                                  '管理员模式',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '查看和管理系统进程，支持按进程名称或PID或端口搜索',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: '列表',
                            icon: Icon(Icons.list),
                            tooltip: '列表视图'),
                        ButtonSegment(
                            value: '网格',
                            icon: Icon(Icons.grid_view),
                            tooltip: '网格视图'),
                        ButtonSegment(
                            value: '树形',
                            icon: Icon(Icons.account_tree),
                            tooltip: '树形视图'),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (values) {
                        setState(() {
                          _viewMode = values.first;
                        });
                      },
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: '无',
                            icon: Icon(Icons.clear_all),
                            tooltip: '不分组'),
                        ButtonSegment(
                            value: '类型',
                            icon: Icon(Icons.category),
                            tooltip: '按进程类型分组'),
                        ButtonSegment(
                            value: '状态',
                            icon: Icon(Icons.info),
                            tooltip: '按内存使用状态分组'),
                      ],
                      selected: {_groupBy},
                      onSelectionChanged: (values) {
                        setState(() {
                          _groupBy = values.first;
                          _updateGroupedProcesses();
                        });
                      },
                    ),
                    if (_selectedProcesses.isNotEmpty)
                      FilledButton.icon(
                        icon: const Icon(Icons.stop),
                        label: Text('终止选中(${_selectedProcesses.length})'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red[700],
                        ),
                        onPressed: _killSelectedProcesses,
                      ),
                    FilledButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('刷新'),
                      onPressed: _isLoading ? null : _refreshProcesses,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _searchType,
                      items: ['进程名称', 'PID', '端口号'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _searchType = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '搜索${_searchType}...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchText = '';
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchText = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: ['进程名称', 'PID', '内存'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text('按$value排序'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            if (_sortBy == newValue) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortBy = newValue;
                              _sortAscending = false;
                            }
                            _sortProcesses();
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward),
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                          _sortProcesses();
                        });
                      },
                      tooltip: _sortAscending ? '升序' : '降序',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    margin: const EdgeInsets.all(16),
                    child: _buildProcessList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<ProcessInfo> _getFilteredProcesses() {
    if (_searchText.isEmpty) return _processes;
    return _processes.where((process) {
      switch (_searchType) {
        case '进程名称':
          return process.name.toLowerCase().contains(_searchText.toLowerCase());
        case 'PID':
          return process.pid.contains(_searchText);
        case '端口号':
          return process.ports.contains(_searchText);
        default:
          return false;
      }
    }).toList();
  }

  Widget _buildProcessList() {
    if (_viewMode == '列表') {
      return _buildListView();
    } else if (_viewMode == '网格') {
      return _buildGridView();
    } else {
      return _buildTreeView();
    }
  }

  Widget _buildGridView() {
    final filteredProcesses = _getFilteredProcesses();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredProcesses.length,
      itemBuilder: (context, index) {
        final process = filteredProcesses[index];
        return Card(
          child: InkWell(
            onTap: () => _showProcessDetails(process),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    process.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('PID: ${process.pid}'),
                  Text(process.memory),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.stop_circle_outlined,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        onPressed: () => _killProcess(process.pid),
                        tooltip: '终止进程',
                      ),
                      Checkbox(
                        value: _selectedProcesses.contains(process.pid),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedProcesses.add(process.pid);
                            } else {
                              _selectedProcesses.remove(process.pid);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreeView() {
    final filteredProcesses = _getFilteredProcesses();
    _updateGroupedProcessesWithFiltered(filteredProcesses);
    return ListView.builder(
      itemCount: _groupedProcesses.length,
      itemBuilder: (context, index) {
        final group = _groupedProcesses.keys.elementAt(index);
        final processes = _groupedProcesses[group]!;
        return ExpansionTile(
          title: Text('$group (${processes.length})'),
          children: processes
              .map((process) => ListTile(
                    leading: Checkbox(
                      value: _selectedProcesses.contains(process.pid),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedProcesses.add(process.pid);
                          } else {
                            _selectedProcesses.remove(process.pid);
                          }
                        });
                      },
                    ),
                    title: Text(process.name),
                    subtitle:
                        Text('PID: ${process.pid}  内存: ${process.memory}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showProcessDetails(process),
                          tooltip: '查看详情',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.stop_circle_outlined,
                            color: Colors.red[700],
                          ),
                          onPressed: () => _killProcess(process.pid),
                          tooltip: '终止进程',
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildListView() {
    final filteredProcesses = _getFilteredProcesses();
    return ListView.builder(
      itemCount: filteredProcesses.length,
      itemBuilder: (context, index) {
        final process = filteredProcesses[index];
        return ListTile(
          leading: Checkbox(
            value: _selectedProcesses.contains(process.pid),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedProcesses.add(process.pid);
                } else {
                  _selectedProcesses.remove(process.pid);
                }
              });
            },
          ),
          title: Text(process.name),
          subtitle: Text(
              'PID: ${process.pid}  内存: ${process.memory}  端口: ${process.ports}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showProcessDetails(process),
                tooltip: '查看详情',
              ),
              IconButton(
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.red[700],
                ),
                onPressed: () => _killProcess(process.pid),
                tooltip: '终止进程',
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateGroupedProcesses() {
    if (_groupBy == '无') {
      _groupedProcesses = {'全部': _processes};
    } else if (_groupBy == '类型') {
      _groupedProcesses = {
        '系统进程': _processes
            .where((p) => p.name.toLowerCase().endsWith('.exe'))
            .toList(),
        '后台服务': _processes
            .where((p) => p.name.toLowerCase().endsWith('svc'))
            .toList(),
        '其他进程': _processes
            .where((p) =>
                !p.name.toLowerCase().endsWith('.exe') &&
                !p.name.toLowerCase().endsWith('svc'))
            .toList(),
      };
    } else if (_groupBy == '状态') {
      _groupedProcesses = {
        '高内存使用': _processes
            .where((p) => _parseMemory(p.memory) > 500 * 1024)
            .toList(), // 超过500MB
        '中等内存使用': _processes
            .where((p) =>
                _parseMemory(p.memory) > 100 * 1024 &&
                _parseMemory(p.memory) <= 500 * 1024)
            .toList(),
        '低内存使用': _processes
            .where((p) => _parseMemory(p.memory) <= 100 * 1024)
            .toList(),
      };
    }
  }

  void _updateGroupedProcessesWithFiltered(List<ProcessInfo> processes) {
    if (_groupBy == '无') {
      _groupedProcesses = {'全部': processes};
    } else if (_groupBy == '类型') {
      _groupedProcesses = {
        '系统进程': processes
            .where((p) => p.name.toLowerCase().endsWith('.exe'))
            .toList(),
        '后台服务': processes
            .where((p) => p.name.toLowerCase().endsWith('svc'))
            .toList(),
        '其他进程': processes
            .where((p) =>
                !p.name.toLowerCase().endsWith('.exe') &&
                !p.name.toLowerCase().endsWith('svc'))
            .toList(),
      };
    } else if (_groupBy == '状态') {
      _groupedProcesses = {
        '高内存使用': processes
            .where((p) => _parseMemory(p.memory) > 500 * 1024)
            .toList(), // 超过500MB
        '中等内存使用': processes
            .where((p) =>
                _parseMemory(p.memory) > 100 * 1024 &&
                _parseMemory(p.memory) <= 500 * 1024)
            .toList(),
        '低内存使用': processes
            .where((p) => _parseMemory(p.memory) <= 100 * 1024)
            .toList(),
      };
    }
  }

  Future<void> _killSelectedProcesses() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('确认终止进程'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确定要终止以下 ${_selectedProcesses.length} 个进程吗？'),
                const SizedBox(height: 8),
                const Text('警告：强制终止进程可能导致数据丢失！',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red[700],
                ),
                child: const Text('终止进程'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      for (final pid in _selectedProcesses) {
        await _killProcess(pid);
      }
      setState(() {
        _selectedProcesses.clear();
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshProcesses();
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
  }
}

class ProcessInfo {
  final String name;
  final String pid;
  final String memory;
  final String rawMemory;
  final String ports;

  ProcessInfo({
    required this.name,
    required this.pid,
    required this.memory,
    required this.rawMemory,
    this.ports = 'None',
  });
}

class ProcessDetailsDialog extends StatefulWidget {
  final ProcessInfo process;
  final String? scriptsPath;

  const ProcessDetailsDialog({
    super.key,
    required this.process,
    this.scriptsPath,
  });

  @override
  State<ProcessDetailsDialog> createState() => _ProcessDetailsDialogState();
}

class _ProcessDetailsDialogState extends State<ProcessDetailsDialog> {
  String? _details;
  String? _treeInfo;
  bool _isLoading = true;
  String? _error;

  String _getScriptPath(String scriptName) {
    return path.join(widget.scriptsPath ?? '', scriptName);
  }

  @override
  void initState() {
    super.initState();
    _loadProcessDetails();
  }

  Future<void> _loadProcessDetails() async {
    try {
      final results = await Future.wait([
        _getProcessDetails(),
        _getProcessTree(),
      ]);

      if (!mounted) return;

      setState(() {
        _details = results[0] as String;
        _treeInfo = results[1] as String;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _getProcessDetails() async {
    try {
      if (widget.scriptsPath == null) {
        throw Exception('脚本路径未初始化');
      }

      final processResult = await Process.run(
        'powershell',
        [
          '-File',
          _getScriptPath('get_process_details.ps1'),
          '-ProcessId',
          widget.process.pid
        ],
        stdoutEncoding: const SystemEncoding(),
      );

      if (processResult.exitCode != 0) {
        throw processResult.stderr;
      }

      final json = jsonDecode(processResult.stdout.toString());
      return '''
CPU使用率: ${json['CPU']}%
线程数: ${json['ThreadCount']}
句柄数: ${json['HandleCount']}
工作集: ${json['WorkingSet']} MB
虚拟内存: ${json['VirtualMemory']} MB
优先级: ${json['Priority']}
启动时间: ${json['StartTime']}
路径: ${json['Path']}
端口: ${widget.process.ports}
''';
    } catch (e) {
      return '获取进程详情失败: $e';
    }
  }

  Future<String> _getProcessTree() async {
    try {
      if (widget.scriptsPath == null) {
        throw Exception('脚本路径未初始化');
      }

      final result = await Process.run(
        'powershell',
        [
          '-File',
          _getScriptPath('get_process_tree.ps1'),
          '-ProcessId',
          widget.process.pid
        ],
        stdoutEncoding: const SystemEncoding(),
      );

      if (result.exitCode != 0) {
        throw result.stderr;
      }

      final json = jsonDecode(result.stdout.toString());
      return '''
进程ID: ${json['ProcessId']}
父进程ID: ${json['ParentProcessId']}
父进程名称: ${json['ParentName']}
命令行: ${json['CommandLine']}
''';
    } catch (e) {
      return '获取进程树信息失败: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text('进程详情: ${widget.process.name}'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载进程详情...'),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '基本信息'),
                            Tab(text: '高级信息'),
                          ],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailItem(
                                        '进程名称', widget.process.name),
                                    _buildDetailItem('PID', widget.process.pid),
                                    _buildDetailItem(
                                        '内存使用', widget.process.memory),
                                    const Divider(),
                                    SelectableText(_details ?? ''),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('进程树信息:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    SelectableText(_treeInfo ?? ''),
                                    const Divider(),
                                    const Text('进程操作:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.speed),
                                          label: const Text('优先级'),
                                          onPressed: () =>
                                              _showPriorityDialog(context),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.pause),
                                          label: const Text('暂停'),
                                          onPressed: () =>
                                              _suspendProcess(context),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text('恢复'),
                                          onPressed: () =>
                                              _resumeProcess(context),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  void _showPriorityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置进程优先级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('实时'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('256');
              },
            ),
            ListTile(
              title: const Text('高'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('128');
              },
            ),
            ListTile(
              title: const Text('高于标准'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('32768');
              },
            ),
            ListTile(
              title: const Text('标准'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('32');
              },
            ),
            ListTile(
              title: const Text('低于标准'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('16384');
              },
            ),
            ListTile(
              title: const Text('低'),
              onTap: () {
                Navigator.pop(context);
                _setPriority('64');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPriority(String priority) async {
    try {
      await Process.run('wmic', [
        'process',
        'where',
        'ProcessId=${widget.process.pid}',
        'CALL',
        'setpriority',
        priority
      ]);
      _loadProcessDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置优先级失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suspendProcess(BuildContext context) async {
    try {
      await Process.run('powershell', [
        '-Command',
        'Get-Process -Id ${widget.process.pid} | ForEach-Object { \$_.Suspend() }'
      ]);
      _loadProcessDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('暂停进程失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resumeProcess(BuildContext context) async {
    try {
      await Process.run('powershell', [
        '-Command',
        'Get-Process -Id ${widget.process.pid} | ForEach-Object { \$_.Resume() }'
      ]);
      _loadProcessDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复进程失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
