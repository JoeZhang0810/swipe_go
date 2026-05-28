import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_go/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SwipeGoApp());
    expect(find.text('划咯 SwipeGo'), findsOneWidget);
  });
}
