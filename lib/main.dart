import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'pages/home_page.dart';
import 'utils/clipboard_util.dart';
import 'utils/logger_util.dart';

void main() {
  // 先设置 debugZoneErrorsAreFatal
  BindingBase.debugZoneErrorsAreFatal = true;

  runZonedGuarded(() async {
    // 在 Zone 内部初始化绑定
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化日志系统
    await LoggerUtil.init();

    // 捕获 Flutter 框架异常
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

    // 捕获异步异常
    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerUtil.error('未捕获的异步异常', error, stack);
      return true;
    };

    runApp(const MyApp());
    LoggerUtil.info('应用启动');
  }, (error, stackTrace) async {
    await LoggerUtil.error('未捕获的Zone异常', error, stackTrace);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: ClipboardUtil.rootScaffoldMessengerKey,
      title: 'WeTools',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
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
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const MyHomePage(title: '开发者工具箱'),
    );
  }
}
