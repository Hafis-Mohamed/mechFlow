import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_button.dart';
import '../startup/shop_details_screen.dart';

class ProfileTab extends StatelessWidget {
  final Map<String, dynamic>? shopDetails;
  final VoidCallback onRefreshShopDetails;

  const ProfileTab({
    super.key,
    required this.shopDetails,
    required this.onRefreshShopDetails,
  });

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your MechFlow account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CustomButton(
            label: 'Sign Out',
            isFullWidth: false,
            backgroundColor: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final user = supabase.auth.currentUser;
    final shopName = shopDetails?['shop_name'] ?? 'My Workshop';
    final location = shopDetails?['location'] ?? 'Location not set';
    final phone = shopDetails?['phone'] ?? 'No phone added';
    final email = shopDetails?['email'] ?? user?.email ?? 'No email';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),

          // Shop Avatar Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.heroGradient,
              boxShadow: AppShadows.glowPrimary,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            shopName,
            style: AppTypography.displayMedium(primaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: AppTypography.bodyMedium(secondaryText),
          ),
          const SizedBox(height: 28),

          // Details List Card
          CustomCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.business_rounded,
                  title: 'Shop Name',
                  value: shopName,
                  isDark: isDark,
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location / Address',
                  value: location,
                  isDark: isDark,
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Contact Phone',
                  value: phone,
                  isDark: isDark,
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Account Email',
                  value: email,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preferences & Theme Switch Card
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme Mode', style: AppTypography.titleMedium(primaryText)),
                        Text(isDark ? 'Dark Theme Active' : 'Light Theme Active', style: AppTypography.bodySmall(secondaryText)),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: isDark,
                  activeColor: AppColors.primary,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          CustomButton(
            label: 'Edit Shop Profile',
            icon: Icons.edit_outlined,
            isOutline: true,
            onPressed: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => ShopDetailsScreen(initialData: shopDetails),
                  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                ),
              );
              onRefreshShopDetails();
            },
          ),
          const SizedBox(height: 14),

          CustomButton(
            label: 'Sign Out Account',
            icon: Icons.logout_rounded,
            backgroundColor: AppColors.error,
            onPressed: () => _signOut(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.caption(secondaryText)),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.titleSmall(primaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
