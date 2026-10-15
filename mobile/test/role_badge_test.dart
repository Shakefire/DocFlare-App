import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docflare/shared/widgets/role_badge.dart';

void main() {
  testWidgets('RoleBadge displays appropriate uppercase role text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleBadge(role: 'admin'),
        ),
      ),
    );

    expect(find.text('ADMIN'), findsOneWidget);
  });
}
