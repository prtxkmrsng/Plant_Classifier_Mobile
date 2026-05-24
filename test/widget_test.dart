import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plant_classifier_mobile/main.dart';

void main() {
  testWidgets('App root widget builds without error',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PlantIdentifierApp());
    // Verify the app title is present in the widget tree
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
