import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('HomeScreen shows navigation buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const LabirintoDungeonicoApp());

    expect(find.text('Labirinto Dungeonico'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Combate'), findsOneWidget);
    expect(find.text('Inventário'), findsOneWidget);
    expect(find.text('Personagem'), findsOneWidget);
  });
}
