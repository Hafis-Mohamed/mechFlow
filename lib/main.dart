import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_constants.dart';
import 'screens/startup/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

/// Convenient global accessor for Supabase client
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (Replace values in lib/supabase_constants.dart)
  if (SupabaseConstants.supabaseUrl != 'YOUR_SUPABASE_URL') {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      publishableKey: SupabaseConstants.supabasePublishableKey,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'MechFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}
