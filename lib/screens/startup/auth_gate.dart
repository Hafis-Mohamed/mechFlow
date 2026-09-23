import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'shop_details_screen.dart';

/// Listens to Supabase Auth State changes and routes user based on session & onboarding status
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Check if the logged in user has completed their shop details setup
  Future<bool> _hasShopDetails(String userId) async {
    try {
      final response = await supabase
          .from('shops')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      // If table doesn't exist yet or query fails, default to false
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session ?? supabase.auth.currentSession;

        if (session != null) {
          return FutureBuilder<bool>(
            future: _hasShopDetails(session.user.id),
            builder: (context, shopSnapshot) {
              if (shopSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasShop = shopSnapshot.data ?? false;
              if (hasShop) {
                return const HomeScreen();
              } else {
                return const ShopDetailsScreen();
              }
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
