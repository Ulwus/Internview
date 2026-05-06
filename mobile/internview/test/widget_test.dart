import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:internview/app/app.dart';

void main() {
  testWidgets('InternviewApp açılır (splash rotası)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: InternviewApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
