import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demo_mobile/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    // 测试环境无 WebView 平台实现；非 Android 走占位界面，同样带标题。
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.text('API + PostgreSQL'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
