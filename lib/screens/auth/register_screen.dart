import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/connectivity_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/widgets.dart';

/// Registration Screen for UniTrack
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SnackBarMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  UserRole _selectedRole = UserRole.student;
  String? _selectedDepartment;
  String _selectedCampus = 'isulan'; // Default campus
  final _positionController = TextEditingController();
  int _passwordStrength = 0;
  
  // Campus options - All SKSU Campuses
  final List<Map<String, String>> _campuses = [
    {'id': 'isulan', 'name': 'Isulan Campus', 'shortName': 'Isulan'},
    {'id': 'tacurong', 'name': 'Tacurong Campus', 'shortName': 'Tacurong'},
    {'id': 'access', 'name': 'ACCESS Campus', 'shortName': 'ACCESS'},
    {'id': 'bagumbayan', 'name': 'Bagumbayan Campus', 'shortName': 'Bagumbayan'},
    {'id': 'palimbang', 'name': 'Palimbang Campus', 'shortName': 'Palimbang'},
    {'id': 'kalamansig', 'name': 'Kalamansig Campus', 'shortName': 'Kalamansig'},
    {'id': 'lutayan', 'name': 'Lutayan Campus', 'shortName': 'Lutayan'},
  ];
  
  final List<String> _departments = [
    'College of Teacher Education',
    'College of Arts and Sciences',
    'College of Engineering',
    'College of Agriculture',
    'College of Business Administration',
    'College of Criminal Justice Education',
    'College of Information and Computing Sciences',
    'Graduate School',
    'Administration',
  ];
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _positionController.dispose();
    super.dispose();
  }
  
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check connectivity first
    if (!ConnectivityService().isConnected) {
      showErrorSnackBar(context, 'No internet connection. Please check your network.');
      return;
    }
    
    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      department: _selectedDepartment,
      position: _selectedRole != UserRole.student 
          ? _positionController.text.trim() 
          : null,
      campusId: _selectedCampus,
    );
    
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Registration successful! Welcome to UniTrack.');
      } else {
        final errorMsg = ErrorMessages.registerError(authProvider.error);
        showErrorSnackBar(context, errorMsg);
      }
    }
  }
  
  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = Validators.passwordStrength(password);
    });
  }
  
  /// Campus colors for visual distinction
  static const Map<String, Color> _campusColors = {
    'isulan': AppColors.primary,
    'tacurong': Colors.orange,
    'access': Colors.purple,
    'bagumbayan': Colors.teal,
    'palimbang': Colors.indigo,
    'kalamansig': Colors.pink,
    'lutayan': Colors.brown,
  };
  
  /// Build campus selector - tappable card that opens bottom sheet
  Widget _buildCampusSelector() {
    final selectedCampus = _campuses.firstWhere(
      (c) => c['id'] == _selectedCampus,
      orElse: () => _campuses.first,
    );
    final color = _campusColors[_selectedCampus] ?? AppColors.primary;
    
    return InkWell(
      onTap: _showCampusBottomSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_city, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCampus['name']!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Tap to change campus',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more, color: color),
          ],
        ),
      ),
    );
  }
  
  /// Show campus selection bottom sheet
  void _showCampusBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Your Campus',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Choose your SKSU campus',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Campus list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _campuses.length,
                itemBuilder: (context, index) {
                  final campus = _campuses[index];
                  final isSelected = _selectedCampus == campus['id'];
                  final color = _campusColors[campus['id']] ?? AppColors.primary;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? color.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: isSelected ? color : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      campus['name']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      campus['shortName']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: color)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCampus = campus['id']!;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return LoadingOverlay(
            isLoading: authProvider.isLoading,
            message: 'Creating account...',
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      'Join ${AppConstants.appName}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account to start using the campus locator',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Role selection
                    Text(
                      'I am a:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            title: 'Student',
                            icon: Icons.school,
                            isSelected: _selectedRole == UserRole.student,
                            onTap: () {
                              setState(() {
                                _selectedRole = UserRole.student;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            title: 'Faculty/Staff',
                            icon: Icons.person_4,
                            isSelected: _selectedRole == UserRole.staff,
                            onTap: () {
                              setState(() {
                                _selectedRole = UserRole.staff;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Campus selection (tap to open selector)
                    Text(
                      'My Campus:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildCampusSelector(),
                    
                    const SizedBox(height: 24),
                    
                    // Name fields
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            prefixIcon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (value) => Validators.name(value, fieldName: 'first name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            textInputAction: TextInputAction.next,
                            validator: (value) => Validators.name(value, fieldName: 'last name'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      label: 'SKSU Email Address',
                      hint: 'your.name@sksu.edu.ph',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Department dropdown (for both roles)
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment, // ignore: deprecated_member_use
                      decoration: const InputDecoration(
                        labelText: 'Department/College',
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem(
                          value: dept,
                          child: Text(
                            dept,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a department';
                        }
                        return null;
                      },
                    ),
                    
                    // Position field (staff only)
                    if (_selectedRole == UserRole.staff) ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _positionController,
                        label: 'Position/Title',
                        hint: 'e.g., Professor, Instructor, Admin Staff',
                        prefixIcon: Icons.work_outline,
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Password fields with strength indicator
                    PasswordTextField(
                      controller: _passwordController,
                      label: 'Password',
                      textInputAction: TextInputAction.next,
                      onChanged: _updatePasswordStrength,
                      validator: (value) => Validators.password(value, checkStrength: false),
                    ),
                    
                    // Password strength indicator
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _passwordStrength / 4,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(Validators.passwordStrengthColor(_passwordStrength)),
                              ),
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Validators.passwordStrengthLabel(_passwordStrength),
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(Validators.passwordStrengthColor(_passwordStrength)),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    PasswordTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleRegister(),
                      validator: (value) => Validators.confirmPassword(value, _passwordController.text),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Privacy notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.privacy_tip_outlined,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedRole == UserRole.staff
                                  ? 'As faculty/staff, you can control when your location is visible. Location tracking is always opt-in.'
                                  : 'Your privacy is protected. You can only view faculty locations when they choose to share.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Register button
                    PrimaryButton(
                      text: 'Create Account',
                      onPressed: _handleRegister,
                      isLoading: authProvider.isLoading,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Back to login
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Already have an account? Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Role selection card widget
class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
