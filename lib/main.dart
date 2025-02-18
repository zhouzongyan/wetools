import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';
import 'pages/system_page.dart';
import 'utils/clipboard_util.dart';
import 'utils/logger_util.dart';
import 'package:provider/provider.dart';
import 'utils/theme_util.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'services/update_service.dart';
import 'dart:async';
import 'widgets/update_progress_dialog.dart';
import 'utils/settings_util.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await LoggerUtil.init();

  // 设置异常处理
  FlutterError.onError = (FlutterErrorDetails details) {
    // 忽略键盘事件相关的错误
    if (details.exception.toString().contains('KeyDownEvent')) {
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerUtil.error('未捕获的异步异常', error, stack);
    return true;
  };

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 配置窗口
  await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      ), () async {
    // 只禁用菜单栏的最大最小化，保留窗口标题栏按钮
    await windowManager.setPreventClose(false);
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化自启动功能
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    launchAtStartup.setup(
      appName: 'WeTools',
      appPath: Platform.resolvedExecutable,
    );
  }

  // 运行应用
  runApp(const MyApp());
  LoggerUtil.info('应用启动');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeUtil(),
      child: Consumer<ThemeUtil>(
        builder: (context, themeUtil, _) {
          return MaterialApp(
            scaffoldMessengerKey: ClipboardUtil.rootScaffoldMessengerKey,
            title: 'WeTools',
            themeMode: themeUtil.themeMode,
            theme: ThemeData(
              // 亮色主题
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.white,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'SourceHanSansSC',
              textTheme: const TextTheme(
                headlineMedium: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF444444),
                ),
                bodyLarge: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ),
            darkTheme: ThemeData(
              // 暗色主题
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.black,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'SourceHanSansSC',
            ),
            home: const AppFrame(),
          );
        },
      ),
    );
  }
}

class AppFrame extends StatefulWidget {
  const AppFrame({super.key});

  @override
  State<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<AppFrame> {
  Timer? _updateCheckTimer;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _initUpdateCheck();
    _loadVersion();
    SettingsUtil.addListener(_initUpdateCheck);
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    SettingsUtil.removeListener(_initUpdateCheck);
    super.dispose();
  }

  Future<void> _initUpdateCheck() async {
    _updateCheckTimer?.cancel();

    final autoCheck = await SettingsUtil.getAutoUpdateCheck();
    if (!autoCheck) return;

    final interval = await SettingsUtil.getUpdateCheckInterval();
    // 启动时检查更新
    _checkUpdateSilently();
    // 设置定时检查
    _updateCheckTimer = Timer.periodic(
      Duration(hours: interval),
      (_) => _checkUpdateSilently(),
    );
  }

  Future<void> _checkUpdateSilently() async {
    try {
      final result = await UpdateService.checkUpdate();
      if (!mounted) return;

      if (result.hasUpdate) {
        if (!mounted) return;
        final bool? shouldUpdate = await showDialog<bool>(
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
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后再说'),
              ),
              if (result.downloadUrl != null)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('立即更新'),
                ),
            ],
          ),
        );

        if (shouldUpdate == true && mounted) {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认更新'),
              content: const Text('更新将会覆盖当前版本并重启应用，是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('确认'),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UpdateProgressDialog(
                downloadUrl: result.downloadUrl!,
              ),
            );
          }
        }
      }
    } catch (e) {
      // 静默检查更新失败时不显示错误
      debugPrint('静默检查更新失败: $e');
    }
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _openGitHub() async {
    const url = 'https://github.com/ayuayue/wetools';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (Platform.isWindows) _buildMenuBar(context),
          const Expanded(child: MyHomePage(title: '开发者工具箱')),
        ],
      ),
    );
  }

  Widget _buildMenuBar(BuildContext context) {
    return Container(
      height: 30,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _buildMenuItem(
            context,
            '首选项',
            [
              PopupMenuItem(
                child: const Text('设置'),
                onTap: () => _showSettingsDialog(context),
              ),
              PopupMenuItem(
                child: const Text('系统信息'),
                onTap: () => _showSystemInfoDialog(context),
              ),
              PopupMenuItem(
                child: const Text('重启'),
                onTap: () async {
                  // 延迟执行以避免菜单关闭动画问题
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) {
                    _restartApp();
                  }
                },
              ),
              PopupMenuItem(
                child: const Text('退出'),
                onTap: () => windowManager.close(),
              ),
            ],
          ),
          _buildMenuItem(
            context,
            '帮助',
            [
              PopupMenuItem(
                child: const Text('关于'),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const Spacer(),
          // IconButton(
          //   icon: const Icon(Icons.remove, size: 18),
          //   onPressed: () => windowManager.minimize(),
          // ),
          // IconButton(
          //   icon: const Icon(Icons.crop_square, size: 18),
          //   onPressed: () async {
          //     if (await windowManager.isMaximized()) {
          //       windowManager.restore();
          //     } else {
          //       windowManager.maximize();
          //     }
          //   },
          // ),
          // IconButton(
          //   icon: const Icon(Icons.close, size: 18),
          //   onPressed: () => windowManager.close(),
          // ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    List<PopupMenuEntry> items,
  ) {
    return PopupMenuButton(
      tooltip: '',
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(title),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: const SettingsPage(),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: const AboutPage(),
          ),
        ),
      ),
    );
  }

  void _showSystemInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: const SystemPage(),
        ),
      ),
    );
  }

  Future<void> _restartApp() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重启'),
        content: const Text('确定要重启应用程序吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重启'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final executablePath = Platform.resolvedExecutable;
      await Process.start(executablePath, []);
      exit(0);
    }
  }
}
