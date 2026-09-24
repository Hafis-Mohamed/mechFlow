import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'shop_details_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasShopDetails(String userId) async {
    try {
      final response = await supabase
          .from('shops')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Widget _buildSplashLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: AppShadows.glowPrimary,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MechFlow',
              style: AppTypography.displayMedium(textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Garage Management, Reimagined',
              style: AppTypography.bodyMedium(
                isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSplashLoader(context);
        }

        final session = snapshot.data?.session ?? supabase.auth.currentSession;

        if (session != null) {
          return FutureBuilder<bool>(
            future: _hasShopDetails(session.user.id),
            builder: (context, shopSnapshot) {
              if (shopSnapshot.connectionState == ConnectionState.waiting) {
                return _buildSplashLoader(context);
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
