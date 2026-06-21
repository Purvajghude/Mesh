import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh/features/auth/presentation/landing_screen.dart';

void main() {
  testWidgets('Landing screen shows the Mesh wordmark and tagline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LandingScreen()),
    );

    expect(find.text('mesh'), findsOneWidget);
    expect(find.textContaining('Continue with GitHub'), findsOneWidget);
    expect(find.textContaining('Continue with LinkedIn'), findsOneWidget);
  });
}
