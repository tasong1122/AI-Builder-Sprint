import 'package:flutter_test/flutter_test.dart';
import 'package:yaksok/main.dart';

void main() {
  testWidgets('시작하기 버튼을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const YaksokApp());

    expect(find.text('시작하기'), findsOneWidget);
  });
}
