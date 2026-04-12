import 'package:flutter_test/flutter_test.dart';

import 'package:dice_games/main.dart';

void main() {
  testWidgets('Home screen renders core controls', (WidgetTester tester) async {
    await tester.pumpWidget(const DiceGamesApp());

    expect(find.text('DiceGames Universal'), findsOneWidget);
    expect(find.text('Roll Dice'), findsOneWidget);
    expect(find.text('Sign In to Save Games'), findsOneWidget);
  });
}
