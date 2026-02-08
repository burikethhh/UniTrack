/// Utility class for form validation
class Validators {
  /// Validate email with SKSU domain preference
  static String? email(String? value, {bool requireSksuDomain = false}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    
    value = value.trim().toLowerCase();
    
    // Basic email format check
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    // Check for SKSU domain if required
    if (requireSksuDomain && !value.endsWith('@sksu.edu.ph')) {
      return 'Please use your SKSU email (@sksu.edu.ph)';
    }
    
    return null;
  }
  
  /// Validate password with strength requirements
  static String? password(String? value, {bool checkStrength = true}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    if (checkStrength) {
      if (value.length < 8) {
        return 'Password should be at least 8 characters for better security';
      }
      
      // Check for at least one uppercase, lowercase, and number
      final hasUpper = value.contains(RegExp(r'[A-Z]'));
      final hasLower = value.contains(RegExp(r'[a-z]'));
      final hasDigit = value.contains(RegExp(r'[0-9]'));
      
      if (!hasUpper || !hasLower || !hasDigit) {
        return 'Include uppercase, lowercase, and numbers';
      }
    }
    
    return null;
  }
  
  /// Simple password validation (login)
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
  
  /// Validate confirm password
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
  
  /// Validate name field
  static String? name(String? value, {String fieldName = 'name'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    // Check for valid name characters
    final nameRegex = RegExp(r"^[a-zA-Z\s\-'\.]+$");
    if (!nameRegex.hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    return null;
  }
  
  /// Validate required field
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  /// Validate phone number (Philippine format)
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    
    // Remove spaces and dashes
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    
    // Philippine mobile: 09xxxxxxxxx or +639xxxxxxxxx
    final phRegex = RegExp(r'^(\+63|0)9\d{9}$');
    if (!phRegex.hasMatch(cleaned)) {
      return 'Enter a valid Philippine mobile number';
    }
    
    return null;
  }
  
  /// Calculate password strength (0-4)
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int strength = 0;
    
    if (password.length >= 6) { strength++; }
    if (password.length >= 8) { strength++; }
    if (password.contains(RegExp(r'[A-Z]')) && 
        password.contains(RegExp(r'[a-z]'))) { strength++; }
    if (password.contains(RegExp(r'[0-9]'))) { strength++; }
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) { strength++; }
    
    return strength.clamp(0, 4);
  }
  
  /// Get password strength label
  static String passwordStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Strong';
      case 4:
        return 'Very Strong';
      default:
        return '';
    }
  }
  
  /// Get password strength color
  static int passwordStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return 0xFFE53935; // Red
      case 1:
        return 0xFFFF9800; // Orange
      case 2:
        return 0xFFFFC107; // Amber
      case 3:
        return 0xFF4CAF50; // Green
      case 4:
        return 0xFF2E7D32; // Dark Green
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
