import 'package:flutter_test/flutter_test.dart';
import 'package:docflare/main.dart';

void main() {
  testWidgets('DocflareApp launches and renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DocflareApp());
    expect(find.text('Docflare'), findsOneWidget);
    expect(find.text('Secure Document Management'), findsOneWidget);
  });
}
