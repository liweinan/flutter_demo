import 'package:flutter_test/flutter_test.dart';

import 'package:demo_mobile/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    expect(find.text('API + PostgreSQL'), findsOneWidget);
  });
}
