import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_container.dart';
import '../home/home_screen.dart';

class ShopDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const ShopDetailsScreen({super.key, this.initialData});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationUrlController = TextEditingController();
  final _phoneController = TextEditingController();
  late final TextEditingController _emailController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _emailController = TextEditingController(text: widget.initialData?['email'] ?? user?.email ?? '');
    
    if (widget.initialData != null) {
      _shopNameController.text = widget.initialData!['shop_name'] ?? '';
      _locationController.text = widget.initialData!['location'] ?? '';
      _locationUrlController.text = widget.initialData!['location_url'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';
    }
  }

  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('No logged-in user session found.');
      }

      await supabase.from('shops').upsert({
        'id': user.id,
        'email': _emailController.text.trim(),
        'shop_name': _shopNameController.text.trim(),
        'location': _locationController.text.trim(),
        'location_url': _locationUrlController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop details saved successfully!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
          (route) => false,
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${error.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shop details: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _locationController.dispose();
    _locationUrlController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          if (Navigator.canPop(context))
            Positioned(
              top: 10,
              left: 10,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                  onPressed: () => Navigator.pop(context),
                  color: primaryText,
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: GlassContainer(
                  padding: const EdgeInsets.all(28.0),
                  borderRadius: BorderRadius.circular(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: AppShadows.glowPrimary,
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Workshop Profile',
                          style: AppTypography.displayMedium(primaryText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your shop details to complete setup',
                          style: AppTypography.bodyMedium(secondaryText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        CustomTextField(
                          controller: _emailController,
                          label: 'Account Email',
                          prefixIcon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          controller: _shopNameController,
                          label: 'Shop Name',
                          hint: 'e.g., Haris Auto Garage',
                          prefixIcon: Icons.business_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your shop name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          controller: _locationController,
                          label: 'Location / Address',
                          hint: 'e.g., 123 Main Street, Downtown',
                          prefixIcon: Icons.location_on_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your shop location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          controller: _locationUrlController,
                          label: 'Google Maps Location URL (Optional)',
                          hint: 'e.g., https://maps.app.goo.gl/...',
                          prefixIcon: Icons.map_outlined,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          controller: _phoneController,
                          label: 'Contact Phone Number (Optional)',
                          hint: 'e.g., +1 555 0199',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 28),

                        CustomButton(
                          label: 'Save & Continue',
                          isLoading: _isLoading,
                          onPressed: _saveShopDetails,
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
