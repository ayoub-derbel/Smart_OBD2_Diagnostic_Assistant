import 'package:flutter_test/flutter_test.dart';

import 'package:obd2_assistant/main.dart';

void main() {
  testWidgets('asks for ELM connection and can skip to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OBD2AssistantApp());

    expect(find.text('Connexion ELM327'), findsOneWidget);
    expect(find.text('Passer pour le moment'), findsOneWidget);

    await tester.tap(find.text('Passer pour le moment'));
    await tester.pumpAndSettle();

    expect(find.text('Telemetry Dashboard'), findsOneWidget);
    expect(find.text("Veuillez d'abord vous connecter"), findsOneWidget);
  });
}
