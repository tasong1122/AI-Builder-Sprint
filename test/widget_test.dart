import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaksok/screens/auth/login_screen.dart';
import 'package:yaksok/screens/main/main_screen.dart';

void main() {
  testWidgets('로그인 화면을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('lOV'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('홈과 돈 약속 탭에서 하단 네비게이션을 유지한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));

    expect(find.text('홈'), findsNWidgets(2));
    expect(find.text('돈 약속'), findsOneWidget);
    expect(find.byTooltip('로그아웃'), findsOneWidget);
    expect(find.text('돈 약속 링크 등록'), findsOneWidget);
    expect(find.text('돈 약속 링크 열기'), findsOneWidget);

    await tester.tap(find.text('돈 약속'));
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('돈 약속'), findsNWidgets(2));
    expect(find.byTooltip('새 돈 약속 만들기'), findsOneWidget);
  });

  testWidgets('돈 약속 추가 버튼을 누르면 작성 화면으로 이동한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainScreen(initialTabIndex: 1)),
    );

    await tester.tap(find.byTooltip('새 돈 약속 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('새 돈 약속 만들기'), findsOneWidget);
  });
}
