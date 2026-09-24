import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  
  static const Color secondary = Color(0xFF06B6D4); // Cyan/Teal highlight
  static const Color accentViolet = Color(0xFF8B5CF6); // Purple accent

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkSurfaceSecondary = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF2A3547);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Semantic Status Colors
  static const Color statusPending = Color(0xFFF59E0B);     // Amber
  static const Color statusInProgress = Color(0xFF8B5CF6);  // Violet
  static const Color statusReady = Color(0xFF06B6D4);       // Cyan
  static const Color statusCompleted = Color(0xFF10B981);   // Emerald Green
  static const Color error = Color(0xFFEF4444);             // Rose Red

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF131B2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status Color Helpers
  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'in progress':
      case 'in_progress':
        return statusInProgress;
      case 'ready':
      case 'ready for delivery':
        return statusReady;
      case 'completed':
        return statusCompleted;
      default:
        return primary;
    }
  }

  static Color getStatusBg(String? status, bool isDark) {
    final baseColor = getStatusColor(status);
    return baseColor.withValues(alpha: isDark ? 0.18 : 0.12);
  }
}
