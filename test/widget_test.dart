import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:team_period/main.dart';

void main() {
  testWidgets('smoke test — app renders without crashing', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
