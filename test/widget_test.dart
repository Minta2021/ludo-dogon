import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_dogon/main.dart';

void main() {
  testWidgets('L\'accueil affiche le titre et le choix du masque', (tester) async {
    await tester.pumpWidget(const LudoDogonApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LUDO DOGON'), findsOneWidget);
    expect(find.text('CHOISIS TON MASQUE'), findsOneWidget);
    expect(find.text('Kanaga'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
