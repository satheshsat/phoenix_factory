import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/conversion_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConversionProvider()),
      ],
      child: const PhoenixFactoryApp(),
    ),
  );
}

class PhoenixFactoryApp extends StatelessWidget {
  const PhoenixFactoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Phornix Factory - Universal Media Converter',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const HomeScreen(),
    );
  }
}
