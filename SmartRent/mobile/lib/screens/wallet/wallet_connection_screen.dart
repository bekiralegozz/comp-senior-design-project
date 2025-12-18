import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wallet_provider.dart';

/// ==========================================================
/// WALLET CONNECTION SCREEN - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
/// 
/// Redirects to the SIWE wallet connect screen.
/// This is a legacy screen kept for route compatibility.

class WalletConnectionScreen extends ConsumerWidget {
  const WalletConnectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    // If already authenticated, go home
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Redirect to SIWE wallet connect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/auth/wallet');
    });
    
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
