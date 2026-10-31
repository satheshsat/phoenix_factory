import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:phoenix_factory/main.dart';
import 'package:phoenix_factory/providers/conversion_provider.dart';
import 'package:phoenix_factory/providers/theme_provider.dart';

void main() {
  testWidgets('Phoenix Factory app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ConversionProvider()),
        ],
        child: const PhoenixFactoryApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Phornix Factory branding is present
    expect(find.text('Phornix Factory'), findsWidgets);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
  });
}
