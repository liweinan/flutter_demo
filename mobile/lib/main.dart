import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 默认 API 基址：`dart-define=API_BASE_URL` 优先；否则 Web/macOS 用本机，
/// Android 模拟器用 `10.0.2.2`（见 README）。
String resolvedApiBaseUrl() {
  const String fromEnvironment = String.fromEnvironment('API_BASE_URL');
  if (fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  if (kIsWeb) {
    return 'http://localhost:8080';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8080';
    default:
      return 'http://127.0.0.1:8080';
  }
}

/// 与 Vite `base: '/ui/'` 一致，由 Rust 提供 `/ui` 静态资源
String resolvedReactUiUrl() {
  const String fromEnvironment = String.fromEnvironment('REACT_UI_URL');
  if (fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  final base = resolvedApiBaseUrl();
  if (base.endsWith('/')) {
    return '${base}ui/';
  }
  return '$base/ui/';
}

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ReactWebShell(),
    );
  }
}

/// 全屏 WebView：主界面由 React（`/ui/`）渲染
class ReactWebShell extends StatefulWidget {
  const ReactWebShell({super.key});

  @override
  State<ReactWebShell> createState() => _ReactWebShellState();
}

class _ReactWebShellState extends State<ReactWebShell> {
  WebViewController? _controller;
  var _loaded = false;

  void _ensureWebController() {
    if (_controller != null) {
      return;
    }
    final uri = Uri.parse(resolvedReactUiUrl());
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loaded = true);
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('API + PostgreSQL')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Flutter Web 不支持内嵌 WebView。\n'
              '请在浏览器打开：${resolvedReactUiUrl()}\n'
              '或使用 Android 模拟器运行本应用。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return Scaffold(
        appBar: AppBar(title: const Text('API + PostgreSQL')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'WebView 套壳当前针对 Android 优化。\n'
              '可在浏览器访问：${resolvedReactUiUrl()}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _ensureWebController();
    final controller = _controller!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API + PostgreSQL'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: () {
              setState(() => _loaded = false);
              controller.loadRequest(Uri.parse(resolvedReactUiUrl()));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (!_loaded)
            const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
