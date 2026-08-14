import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/connectivity_service.dart';
import '../../core/utils/web_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import 'register_screen.dart';

/// Login Screen for ISKSULARS TRACK
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SnackBarMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Local loading state

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Check connectivity first (skip on web — connectivity_plus is unreliable there)
    if (!kIsWeb && !ConnectivityService().isConnected) {
      showErrorSnackBar(
        context,
        'No internet connection. Please check your network.',
      );
      return;
    }

    final email = _emailController.text.trim();
    final authProvider = context.read<AuthProvider>();

    // Set local loading state
    setState(() => _isLoading = true);

    try {
      final success = await authProvider
          . signIn(email: email, password: _passwordController.text)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              authProvider.resetLoading();
              if (mounted) {
                setState(() => _isLoading = false);
                showErrorSnackBar(
                  context,
                  'Login timed out. Please check your internet connection and try again.',
                );
              }
              return false;
            },
          );

      // Always reset loading state
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (success && mounted) {
        if (kDebugMode) debugPrint('Login success — reloading web app for fresh state');
        // Force a full page reload on web to prevent stuck auth state
        if (kIsWeb) {
          reloadWebPage();
        }
        return;
      } else if (!success && mounted) {
        final errorMsg = ErrorMessages.loginError(authProvider.error);
        showErrorSnackBar(context, errorMsg);
      }
      // Now notify listeners so AuthWrapper can reflect the final state
      // (call this AFTER the snackbar so mounted check passes)
      authProvider.resetLoading();
      // AuthWrapper Consumer rebuilds and navigates to home screen
    } catch (e) {
      authProvider.resetLoading();
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'Login failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return LoadingOverlay(
              isLoading: _isLoading, // Use local loading state
              message: 'Signing in...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),

                      // Logo and Title
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/isksularstracklogo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppConstants.appName,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppConstants.appTagline,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppConstants.universityShortName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Welcome text
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your SKSU email to continue',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email field
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'your.email@sksu.edu.ph',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      PasswordTextField(
                        controller: _passwordController,
                        label: 'Password',
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        validator: Validators.loginPassword,
                      ),

                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _showForgotPasswordDialog();
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ),

                      // Resend email verification (for users who registered but haven't verified)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showResendVerificationDialog(),
                          icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                          label: const Text('Resend Verification Email'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.info,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login button
                      PrimaryButton(
                        text: 'Sign In',
                        onPressed: _isLoading ? null : _handleLogin,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'New to ISKSULARS TRACK?',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Register button
                      SecondaryButton(
                        text: 'Create Account',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Footer
                      Center(
                        child: Text(
                          '© ${DateTime.now().year} ${AppConstants.universityName}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    bool isSending = false;
    String? dialogError;
    bool emailSent = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Success state
          if (emailSent) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.mark_email_read,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Email Sent!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Password reset link sent to:\n${emailController.text.trim()}',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check your inbox and spam folder. The link expires in 1 hour.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          // Default / error state
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Reset Password'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: emailController,
                  label: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  enabled: !isSending,
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSending
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          setDialogState(
                            () =>
                                dialogError = 'Please enter your email address',
                          );
                          return;
                        }

                        final validationError = Validators.email(email);
                        if (validationError != null) {
                          setDialogState(() => dialogError = validationError);
                          return;
                        }

                        setDialogState(() {
                          isSending = true;
                          dialogError = null;
                        });

                        try {
                          final authProvider = context.read<AuthProvider>();
                          final success = await authProvider.sendPasswordReset(
                            email,
                          );

                          if (!dialogContext.mounted) return;

                          if (success) {
                            setDialogState(() {
                              emailSent = true;
                              isSending = false;
                            });
                          } else {
                            setDialogState(() {
                              isSending = false;
                              dialogError = ErrorMessages.fromException(
                                authProvider.error ??
                                    'Failed to send reset email',
                              );
                            });
                          }
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSending = false;
                            dialogError = ErrorMessages.fromException(e);
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResendVerificationDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSending = false;
    bool emailSent = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (emailSent) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.mark_email_read,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Verification Email Sent!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A verification link has been sent to:\n${emailController.text.trim()}',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check your inbox and spam folder. After clicking the link, return here to log in.',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Resend Verification Email')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your SKSU email and password. We\'ll sign you in briefly and send a new verification link.',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: emailController,
                  label: 'Email Address',
                  hint: 'your.email@sksu.edu.ph',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  enabled: !isSending,
                ),
                const SizedBox(height: 12),
                PasswordTextField(
                  controller: passwordController,
                  label: 'Password',
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSending
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isSending
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text;
                        if (email.isEmpty || password.isEmpty) {
                          setDialogState(() => dialogError =
                              'Please enter both your email and password.');
                          return;
                        }
                        final emailErr = Validators.email(email);
                        if (emailErr != null) {
                          setDialogState(() => dialogError = emailErr);
                          return;
                        }

                        setDialogState(() {
                          isSending = true;
                          dialogError = null;
                        });

                        try {
                          final authService = context.read<AuthService>();
                          await authService.resendVerificationEmail(
                            email: email,
                            password: password,
                          );
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            emailSent = true;
                            isSending = false;
                          });
                        } on FirebaseAuthException catch (e) {
                          if (!dialogContext.mounted) return;
                          String msg;
                          switch (e.code) {
                            case 'user-not-found':
                            case 'invalid-credential':
                            case 'wrong-password':
                              msg = 'Invalid email or password. Please check your credentials.';
                              break;
                            case 'user-disabled':
                              msg = 'This account has been disabled.';
                              break;
                            case 'too-many-requests':
                              msg = 'Too many attempts. Please try again later.';
                              break;
                            default:
                              msg = e.message ?? 'An error occurred. Please try again.';
                          }
                          setDialogState(() {
                            isSending = false;
                            dialogError = msg;
                          });
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSending = false;
                            dialogError = e.toString();
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                ),
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send Verification Link'),
              ),
            ],
          );
        },
      ),
    );
  }
}
