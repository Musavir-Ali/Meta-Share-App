import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shows Instagram and Facebook share actions', (tester) async {
    await tester.pumpWidget(const MetaShareApp());
    await tester.pump();

    expect(find.text('Share to Meta'), findsOneWidget);
    expect(find.text('Instagram Story'), findsOneWidget);
    expect(find.text('Instagram Feed'), findsOneWidget);
    expect(find.text('Facebook Story'), findsOneWidget);
    expect(find.text('Facebook Feed'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Instagram Story'),
      findsOneWidget,
    );

    final storyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Instagram Story'),
    );
    expect(storyButton.onPressed, isNull);
  });
}
