import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_games/main.dart';

void main() {
  testWidgets('App renders login screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const DiceGamesApp());

    expect(find.byType(FilledButton), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
