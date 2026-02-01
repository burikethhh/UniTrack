import 'package:flutter/material.dart';

/// Utility class for user-friendly error messages
class ErrorMessages {
  /// Convert Firebase/technical errors to user-friendly messages
  static String fromException(dynamic error) {
    final message = error.toString().toLowerCase();
    
    // Network errors
    if (message.contains('network') || 
        message.contains('connection') ||
        message.contains('socket') ||
        message.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    // Firebase Auth errors
    if (message.contains('user-not-found') || 
        message.contains('no user found')) {
      return 'No account found with this email. Please check your email or create a new account.';
    }
    
    if (message.contains('wrong-password') || 
        message.contains('incorrect password')) {
      return 'Incorrect password. Please try again or reset your password.';
    }
    
    if (message.contains('email-already-in-use') ||
        message.contains('already registered')) {
      return 'This email is already registered. Try signing in instead.';
    }
    
    if (message.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters with a mix of letters and numbers.';
    }
    
    if (message.contains('invalid-email')) {
      return 'Invalid email address format. Please check and try again.';
    }
    
    if (message.contains('user-disabled') || 
        message.contains('account has been disabled')) {
      return 'This account has been disabled. Please contact support for assistance.';
    }
    
    if (message.contains('too-many-requests') ||
        message.contains('too many attempts')) {
      return 'Too many failed attempts. Please wait a few minutes before trying again.';
    }
    
    if (message.contains('invalid-credential') ||
        message.contains('credential')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    
    // Firebase/Firestore errors
    if (message.contains('permission-denied') ||
        message.contains('permission denied')) {
      return 'Access denied. You may not have permission to perform this action.';
    }
    
    if (message.contains('not-found') ||
        message.contains('document not found')) {
      return 'The requested data was not found.';
    }
    
    if (message.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    
    // Location errors
    if (message.contains('location') && message.contains('permission')) {
      return 'Location permission is required. Please enable it in your device settings.';
    }
    
    if (message.contains('location') && message.contains('service')) {
      return 'Location services are disabled. Please enable GPS in your device settings.';
    }
    
    // Generic errors - extract any readable message
    if (message.contains('exception:')) {
      final parts = message.split('exception:');
      if (parts.length > 1) {
        final extracted = parts.last.trim();
        if (extracted.isNotEmpty && extracted.length < 100) {
          return _capitalizeFirst(extracted);
        }
      }
    }
    
    // Default fallback
    return 'Something went wrong. Please try again.';
  }
  
  /// Get a user-friendly message for login failures
  static String loginError(String? error) {
    if (error == null || error.isEmpty) {
      return 'Login failed. Please check your credentials and try again.';
    }
    return fromException(error);
  }
  
  /// Get a user-friendly message for registration failures
  static String registerError(String? error) {
    if (error == null || error.isEmpty) {
      return 'Registration failed. Please try again.';
    }
    return fromException(error);
  }
  
  /// Get a user-friendly message for location tracking failures
  static String locationError(String? error) {
    if (error == null || error.isEmpty) {
      return 'Unable to get your location. Please ensure GPS is enabled.';
    }
    
    final message = error.toLowerCase();
    
    if (message.contains('permission')) {
      return 'Location permission denied. Please enable location access in settings.';
    }
    
    if (message.contains('service') || message.contains('gps')) {
      return 'GPS is turned off. Please enable location services.';
    }
    
    if (message.contains('timeout')) {
      return 'Location request timed out. Please try again in an open area.';
    }
    
    return fromException(error);
  }
  
  /// Capitalize first letter
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Mixin to show error/success snackbars
mixin SnackBarMixin {
  void showErrorSnackBar(dynamic context, String message) {
    _showSnackBar(context, message, isError: true);
  }
  
  void showSuccessSnackBar(dynamic context, String message) {
    _showSnackBar(context, message, isError: false);
  }
  
  void _showSnackBar(dynamic context, String message, {required bool isError}) {
    if (context == null) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE27D60) : const Color(0xFF41B3A3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
        action: isError ? SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ) : null,
      ),
    );
  }
}
