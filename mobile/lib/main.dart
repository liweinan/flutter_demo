import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docker API Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
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
        title: const Text('API + PostgreSQL'),
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
