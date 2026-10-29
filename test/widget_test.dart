import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/app.dart';

void main() {
  testWidgets('App starts with HRM splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HRMApp());
    expect(find.text('HRM Enterprise'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
