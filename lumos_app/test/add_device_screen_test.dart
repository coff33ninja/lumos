import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumos_app/screens/add_device_screen.dart';

void main() {
  testWidgets('add device screen shows token scope picker',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddDeviceScreen(),
      ),
    );

    expect(find.text('Token Scope'), findsOneWidget);
    expect(find.textContaining('power-admin'), findsOneWidget);
  });
}
