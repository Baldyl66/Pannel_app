
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:panel_app/main.dart';

void main() {
  testWidgets('PanelApp smoke test', (WidgetTester tester) async {
    // Load dotenv for the test
    dotenv.loadFromString(envString: 'TEST_VAR=test');

    // Build our app and trigger a frame.
    await tester.pumpWidget(const PanelApp());

    // Verify that our app starts and shows the DashboardPage.
    expect(find.text('Bienvenue'), findsOneWidget);
  });
}
