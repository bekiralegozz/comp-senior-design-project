import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/api_service.dart';
import 'providers/wallet_provider.dart';
import 'screens/wallet/wallet_connection_screen.dart';
import 'screens/nft/nft_gallery_screen.dart';
import 'screens/nft/nft_portfolio_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize API service
  await ApiService().initialize();
  
  runApp(
    const ProviderScope(
      child: SmartRentApp(),
    ),
  );
}

class SmartRentApp extends ConsumerWidget {
  const SmartRentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    
    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(
          create: (_) => WalletProvider()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'SmartRent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    );
  }
}








