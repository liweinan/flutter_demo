import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      home: const MainShell(),
    );
  }
}

/// 底部导航：原生请求 API + WebView 加载 React（Vite 构建）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _index == 0
          ? const NativeApiTab()
          : const ReactWebViewTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.api_outlined),
            selectedIcon: Icon(Icons.api),
            label: '原生 API',
          ),
          NavigationDestination(
            icon: Icon(Icons.web_outlined),
            selectedIcon: Icon(Icons.web),
            label: 'React',
          ),
        ],
      ),
    );
  }
}

class NativeApiTab extends StatefulWidget {
  const NativeApiTab({super.key});

  @override
  State<NativeApiTab> createState() => _NativeApiTabState();
}

class _NativeApiTabState extends State<NativeApiTab> {
  bool _loading = false;
  String? _errorMessage;
  String _healthBody = '—';
  String _dbVersionBody = '—';
  String _greetingBody = '—';

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final apiBaseUrl = resolvedApiBaseUrl();
    try {
      final health = await _getJson('$apiBaseUrl/health');
      final dbVersion = await _getJson('$apiBaseUrl/db-version');
      final greeting = await _getJson('$apiBaseUrl/greeting');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _healthBody = const JsonEncoder.withIndent('  ').convert(health);
        _dbVersionBody = const JsonEncoder.withIndent('  ').convert(dbVersion);
        _greetingBody = const JsonEncoder.withIndent('  ').convert(greeting);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: $decoded');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected JSON: $decoded');
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('原生 · API + PostgreSQL'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'API: ${resolvedApiBaseUrl()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(_errorMessage!),
              actions: [
                TextButton(
                  onPressed: _loadAll,
                  child: const Text('重试'),
                ),
              ],
            ),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          _SectionCard(title: '/health', body: _healthBody),
          _SectionCard(title: '/db-version', body: _dbVersionBody),
          _SectionCard(title: '/greeting', body: _greetingBody),
        ],
      ),
    );
  }
}

class ReactWebViewTab extends StatefulWidget {
  const ReactWebViewTab({super.key});

  @override
  State<ReactWebViewTab> createState() => _ReactWebViewTabState();
}

class _ReactWebViewTabState extends State<ReactWebViewTab> {
  late final WebViewController _controller;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
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
        appBar: AppBar(title: const Text('React（WebView）')),
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
        appBar: AppBar(title: const Text('React（WebView）')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('React（Vite + TS）'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: () {
              setState(() => _loaded = false);
              _controller.loadRequest(Uri.parse(resolvedReactUiUrl()));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_loaded)
            const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
