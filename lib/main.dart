import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';
import 'utils/clipboard_util.dart';
import 'utils/logger_util.dart';
import 'package:provider/provider.dart';
import 'utils/theme_util.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await LoggerUtil.init();

  // 设置异常处理
  FlutterError.onError = (FlutterErrorDetails details) async {
    await LoggerUtil.error(
      '未捕获的Flutter异常',
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerUtil.error('未捕获的异步异常', error, stack);
    return true;
  };

  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 配置窗口
  await windowManager.waitUntilReadyToShow(null, () async {
    // 设置窗口大小和其他属性
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.center();
    
    // 只禁用菜单栏的最大最小化，保留窗口标题栏按钮
    await windowManager.setPreventClose(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    
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

  // 禁用辅助功能检查
  if (Platform.isWindows) {
    SemanticsService.announce('', TextDirection.ltr);
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
                seedColor: Colors.deepPurple,
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
                seedColor: Colors.deepPurple,
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

class AppFrame extends StatelessWidget {
  const AppFrame({super.key});

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
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: const AboutPage(),
        ),
      ),
    );
  }
}
