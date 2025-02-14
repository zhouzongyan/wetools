import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/clipboard_util.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../utils/settings_util.dart';

class ClipboardPage extends StatefulWidget {
  const ClipboardPage({super.key});

  @override
  State<ClipboardPage> createState() => _ClipboardPageState();
}

class _ClipboardPageState extends State<ClipboardPage> {
  Timer? _cleanupTimer;
  int _maxHistoryItems = SettingsUtil.defaultMaxHistoryItems;
  int _maxFavoriteItems = SettingsUtil.defaultMaxFavoriteItems;
  int _maxTextLength = SettingsUtil.defaultMaxTextLength;
  int _cleanupInterval = SettingsUtil.defaultCleanupInterval;

  List<ClipboardItem> _clipboardHistory = [];
  List<ClipboardItem> _favorites = [];
  Set<String> _deletedItems = {};
  final _prefs = SharedPreferences.getInstance();

  // 添加搜索控制器和状态
  final _searchController = TextEditingController();
  String _searchText = '';

  void _initCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      Duration(hours: _cleanupInterval),
      (_) => _cleanupDeletedItems(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
    _loadFavorites();
    _loadDeletedItems();
    _startListeningClipboard();
    SettingsUtil.addListener(_loadSettings);
  }

  Future<void> _loadSettings() async {
    _maxHistoryItems = await SettingsUtil.getMaxHistoryItems();
    _maxFavoriteItems = await SettingsUtil.getMaxFavoriteItems();
    _maxTextLength = await SettingsUtil.getMaxTextLength();
    _cleanupInterval = await SettingsUtil.getCleanupInterval();

    _initCleanupTimer();

    // 重新加载历史记录和收藏夹
    await _loadHistory();
    await _loadFavorites();

    // 确保历史记录和收藏夹符合新的限制
    if (_clipboardHistory.length > _maxHistoryItems) {
      setState(() {
        _clipboardHistory = _clipboardHistory.sublist(0, _maxHistoryItems);
      });
      await _saveHistory();
    }

    if (_favorites.length > _maxFavoriteItems) {
      setState(() {
        _favorites = _favorites.sublist(0, _maxFavoriteItems);
      });
      await _saveFavorites();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await _prefs;
      final history = prefs.getStringList('clipboard_history') ?? [];
      setState(() {
        _clipboardHistory = history
            .where((e) => e.isNotEmpty) // 过滤空字符串
            .map((e) {
              try {
                return ClipboardItem.fromJson(json.decode(e));
              } catch (e) {
                return null;
              }
            })
            .where((e) => e != null) // 过滤解析失败的项
            .cast<ClipboardItem>()
            .toList();
      });
    } catch (e) {
      debugPrint('加载剪贴板历史失败: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await _prefs;
      final favorites = prefs.getStringList('clipboard_favorites') ?? [];
      setState(() {
        _favorites = favorites
            .where((e) => e.isNotEmpty)
            .map((e) {
              try {
                return ClipboardItem.fromJson(json.decode(e));
              } catch (e) {
                return null;
              }
            })
            .where((e) => e != null)
            .cast<ClipboardItem>()
            .toList();
      });
    } catch (e) {
      debugPrint('加载收藏夹失败: $e');
    }
  }

  Future<void> _loadDeletedItems() async {
    final prefs = await _prefs;
    _deletedItems = Set.from(prefs.getStringList('deleted_items') ?? []);
  }

  Future<void> _saveHistory() async {
    final prefs = await _prefs;
    await prefs.setStringList(
      'clipboard_history',
      _clipboardHistory.map((e) => json.encode(e.toJson())).toList(),
    );
  }

  Future<void> _saveFavorites() async {
    final prefs = await _prefs;
    await prefs.setStringList(
      'clipboard_favorites',
      _favorites.map((e) => json.encode(e.toJson())).toList(),
    );
  }

  Future<void> _saveDeletedItems() async {
    final prefs = await _prefs;
    await prefs.setStringList('deleted_items', _deletedItems.toList());
  }

  void _addToFavorites(ClipboardItem item) {
    if (!_favorites.contains(item)) {
      if (_favorites.length >= _maxFavoriteItems) {
        ClipboardUtil.showSnackBar(
          '收藏夹已达到最大数量限制 ($_maxFavoriteItems)',
          backgroundColor: Colors.orange,
        );
        return;
      }
      setState(() {
        _favorites.add(item);
      });
      _saveFavorites();
    }
  }

  void _removeFromFavorites(ClipboardItem item) {
    setState(() {
      _favorites.remove(item);
    });
    _saveFavorites();
  }

  void _removeFromHistory(ClipboardItem item) {
    setState(() {
      _clipboardHistory.remove(item);
      if (item.isImage && item.imageData != null) {
        _deletedItems.add(base64Encode(item.imageData!));
      } else if (item.text != null) {
        _deletedItems.add(item.text!);
      }
    });
    _saveHistory();
    _saveDeletedItems();
  }

  void _startListeningClipboard() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      // 先尝试获取图片
      final imageData = await Pasteboard.image;
      if (imageData != null) {
        if (_deletedItems.contains(base64Encode(imageData))) {
          return true;
        }

        final newItem = ClipboardItem(
          imageData: imageData,
          timestamp: DateTime.now(),
        );

        if (!_clipboardHistory.contains(newItem)) {
          setState(() {
            _clipboardHistory.insert(0, newItem);
            // 限制历史记录数量
            if (_clipboardHistory.length > _maxHistoryItems) {
              _clipboardHistory.removeRange(
                  _maxHistoryItems, _clipboardHistory.length);
            }
          });
          _saveHistory();
        }
        return true;
      }

      // 如果没有图片，尝试获取文本
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;

      if (text != null && text.isNotEmpty) {
        // 忽略过长的文本
        if (text.length > _maxTextLength) {
          return true;
        }

        if (_deletedItems.contains(text)) {
          return true;
        }

        final newItem = ClipboardItem(
          text: text,
          timestamp: DateTime.now(),
        );

        if (!_clipboardHistory.contains(newItem)) {
          setState(() {
            _clipboardHistory.insert(0, newItem);
            // 限制历史记录数量
            if (_clipboardHistory.length > _maxHistoryItems) {
              _clipboardHistory.removeRange(
                  _maxHistoryItems, _clipboardHistory.length);
            }
          });
          _saveHistory();
        }
      }

      return true;
    });
  }

  // 定期清理已删除项目列表
  Future<void> _cleanupDeletedItems() async {
    if (_deletedItems.length > 1000) {
      setState(() {
        _deletedItems = Set.from(_deletedItems.take(500));
      });
      _saveDeletedItems();
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _searchController.dispose(); // 添加搜索控制器的销毁
    _saveHistory();
    _saveFavorites();
    _saveDeletedItems();
    SettingsUtil.removeListener(_loadSettings);
    super.dispose();
  }

  // 添加过滤方法
  List<ClipboardItem> _filterItems(List<ClipboardItem> items) {
    if (_searchText.isEmpty) return items;
    return items.where((item) {
      if (item.isImage) return false;
      return item.text?.toLowerCase().contains(_searchText.toLowerCase()) ??
          false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '剪贴板历史',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  '自动记录系统剪贴板内容，支持收藏常用内容',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前设置：\n'
                  '• 历史记录最大数量：$_maxHistoryItems\n'
                  '• 收藏夹最大数量：$_maxFavoriteItems\n'
                  '• 文本最大长度：$_maxTextLength 字符\n'
                  '• 清理间隔：$_cleanupInterval 小时',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                // 添加搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索文本内容...',
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
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Material(
                    // 添加 Material widget
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: TabBar(
                      tabs: const [
                        Tab(text: '历史记录'),
                        Tab(text: '收藏夹'),
                      ],
                      labelColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildHistoryList(),
                        _buildFavoritesList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final filteredItems = _filterItems(_clipboardHistory);
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          '没有找到匹配的内容',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildClipboardItem(item, inFavorites: false);
      },
    );
  }

  Widget _buildFavoritesList() {
    final filteredItems = _filterItems(_favorites);
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          '没有找到匹配的内容',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildClipboardItem(item, inFavorites: true);
      },
    );
  }

  Widget _buildClipboardItem(ClipboardItem item, {required bool inFavorites}) {
    final isFavorited = _favorites.contains(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: item.isImage
            ? Image.memory(
                item.imageData!,
                height: 100,
                fit: BoxFit.contain,
              )
            : Text(
                item.text ?? '', // 添加空字符串作为默认值
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
        subtitle: Text(
          item.timestamp.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorited ? Icons.star : Icons.star_border,
                color: isFavorited ? Colors.amber : null,
              ),
              onPressed: () {
                if (isFavorited) {
                  _removeFromFavorites(item);
                } else {
                  _addToFavorites(item);
                }
                setState(() {});
              },
              tooltip: isFavorited ? '取消收藏' : '收藏',
            ),
            if (!item.isImage) // 只有文本才显示复制按钮
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  if (item.text != null) {
                    ClipboardUtil.copyToClipboard(item.text!, context);
                  }
                },
                tooltip: '复制',
              ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                if (item.isImage && item.imageData != null) {
                  _saveImage(item.imageData!);
                } else if (item.text != null) {
                  _saveText(item.text!);
                }
              },
              tooltip: item.isImage ? '保存图片' : '保存文本',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                if (inFavorites) {
                  _removeFromFavorites(item);
                } else {
                  _removeFromHistory(item);
                }
              },
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage(Uint8List imageData) async {
    try {
      final now = DateTime.now();
      final fileName = 'clipboard_image_${now.millisecondsSinceEpoch}.png';

      String? savePath;

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          savePath = '${directory.path}${Platform.pathSeparator}$fileName';
        }
      }

      if (savePath == null) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}${Platform.pathSeparator}$fileName';
      }

      final file = File(savePath);
      await file.writeAsBytes(imageData);

      if (mounted) {
        ClipboardUtil.showSnackBar(
          '图片已保存到: $savePath',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) {
        ClipboardUtil.showSnackBar(
          '保存图片失败: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _saveText(String text) async {
    try {
      final now = DateTime.now();
      final fileName = 'clipboard_text_${now.millisecondsSinceEpoch}.txt';

      String? savePath;

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          savePath = '${directory.path}${Platform.pathSeparator}$fileName';
        }
      }

      if (savePath == null) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}${Platform.pathSeparator}$fileName';
      }

      final file = File(savePath);
      await file.writeAsString(text);

      if (mounted) {
        ClipboardUtil.showSnackBar(
          '文本已保存到: $savePath',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) {
        ClipboardUtil.showSnackBar(
          '保存文本失败: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }
}

class ClipboardItem {
  final String? text;
  final Uint8List? imageData;
  final DateTime timestamp;

  ClipboardItem({
    this.text,
    this.imageData,
    required this.timestamp,
  }) : assert(text != null || imageData != null, '文本和图片不能同时为空');

  bool get isImage => imageData != null;

  Map<String, dynamic> toJson() => {
        'text': text,
        'imageData': imageData != null ? base64Encode(imageData!) : null,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
        text: json['text'] as String?,
        imageData: json['imageData'] != null
            ? base64Decode(json['imageData'] as String)
            : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          imageData?.length == other.imageData?.length;

  @override
  int get hashCode => text.hashCode ^ (imageData?.length ?? 0);
}
