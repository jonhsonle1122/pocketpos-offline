import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'state/cart_provider.dart';
import 'state/catalog_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<CatalogProvider>(
          create: (_) => CatalogProvider(appState.products),
        ),
      ],
      child: const PocketPosApp(),
    ),
  );
}

class PocketPosApp extends StatelessWidget {
  const PocketPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConfig.primaryColor,
      secondary: AppConfig.accentColor,
    );
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      routes: {
        '/product-form': (_) => const ProductFormScreen(),
      },
      home: const _AppRoot(),
    );
  }
}

/// Routes between first-run setup and the main shell based on settings.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return appState.isFirstRun ? const WelcomeScreen() : const HomeScreen();
  }
}
