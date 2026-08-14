import 'package:flutter/material.dart';

/// ISKSULARS TRACK Color Palette - SKSU Mint Green Theme
class AppColors {
  // Primary Colors - Mint Green (SKSU Theme)
  static const Color primary = Color(0xFF41B3A3); // Mint/Sage Green
  static const Color primaryLight = Color(0xFF85DCBA); // Light Mint Green
  static const Color primaryDark = Color(0xFF2E8B7A); // Dark Mint Green

  // Secondary/Accent Colors - Warm Coral
  static const Color accent = Color(0xFFE8A87C); // Peach/Coral
  static const Color accentLight = Color(0xFFF5C9A8); // Light Peach

  // Status Colors — each concept is now visually DISTINCT
  // (the previous palette reused coral red for error/busy/unavailable,
  //  making them indistinguishable; success was identical to brand color).
  static const Color statusAvailable = Color(
    0xFF41B3A3,
  ); // Mint Green — same as primary intentionally
  static const Color statusBusy = Color(
    0xFFE8A87C,
  ); // Peach (distinct from error)
  static const Color statusUnavailable = Color(0xFF8D8D8D); // Gray (distinct)
  static const Color statusAway = Color(0xFFB0B0B0); // Lighter gray
  static const Color statusInClass = Color(0xFF6EB5A0); // Teal Green
  static const Color statusInMeeting = Color(0xFFE8A87C); // Peach (accent)

  // Background Colors (light theme)
  static const Color background = Color(0xFFFDF8F5); // Warm white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFBF8); // Cream

  // Dark Theme Background Colors
  static const Color darkBackground = Color(0xFF121619);
  static const Color darkSurface = Color(0xFF1B2127);
  static const Color darkSurfaceLight = Color(0xFF252C33);

  // Text Colors
  static const Color textPrimary = Color(0xFF3D3D3D); // Dark gray
  static const Color textSecondary = Color(0xFF7A7A7A); // Medium gray
  static const Color textLight = Color(0xFFADB5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color darkTextPrimary = Color(0xFFECEFF1);
  static const Color darkTextSecondary = Color(0xFFB0BEC5);

  // Utility Colors — distinct semantic meaning
  static const Color divider = Color(0xFFE8DDD5); // Warm divider
  static const Color border = Color(0xFFD9CEC5); // Warm border
  static const Color shadow = Color(0x1A000000);
  static const Color error = Color(0xFFD32F2F); // Bright red (Material error)
  static const Color success = Color(
    0xFF2E7D32,
  ); // Deep green (distinct from mint brand)
  static const Color warning = Color(
    0xFFF57C00,
  ); // Amber/orange (distinct from peach accent)
  static const Color info = Color(
    0xFF1976D2,
  ); // Blue (distinct from teal status)

  // Map Colors
  static const Color mapMarkerOnline = Color(
    0xFF41B3A3,
  ); // Mint green (primary)
  static const Color mapMarkerBusy = Color(0xFFE8A87C); // Peach (accent)
  static const Color mapMarkerOffline = Color(0xFF8D8D8D); // Gray
  static const Color mapRoute = Color(0xFF41B3A3); // Mint green (primary)
  static const Color mapCampusBoundary = Color(
    0x3341B3A3,
  ); // Mint green with opacity

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  /// Get status color based on status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available for consultation':
      case 'available':
      case 'online':
        return statusAvailable;
      case 'in a class':
      case 'teaching':
        return statusInClass;
      case 'in a meeting':
      case 'in meeting':
      case 'meeting':
        return statusInMeeting;
      case 'busy':
      case 'do not disturb':
        return statusBusy;
      case 'away':
      case 'break time':
      case 'on break':
      case 'out of office':
      case 'office hours':
        return statusAway;
      case 'offline':
      case 'unavailable':
        return statusUnavailable;
      default:
        return statusAway;
    }
  }
}
