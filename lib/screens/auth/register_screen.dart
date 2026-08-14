import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/programs.dart';
import '../../core/constants/organizations.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/connectivity_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/widgets.dart';
import 'email_verification_screen.dart';

/// Registration Screen for ISKSULARS TRACK
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
  final _positionController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  String? _selectedDepartment;
  String _selectedCampus = 'isulan';
  OrgCategory _orgCategory = OrgCategory.academic;
  String? _selectedOrganization;
  int _passwordStrength = 0;

  final List<Map<String, String>> _campuses = [
    {'id': 'isulan', 'name': 'Isulan Campus', 'shortName': 'Isulan'},
    {'id': 'tacurong', 'name': 'Tacurong Campus', 'shortName': 'Tacurong'},
    {'id': 'access', 'name': 'ACCESS Campus', 'shortName': 'ACCESS'},
    {'id': 'bagumbayan', 'name': 'Bagumbayan Campus', 'shortName': 'Bagumbayan'},
    {'id': 'palimbang', 'name': 'Palimbang Campus', 'shortName': 'Palimbang'},
    {'id': 'kalamansig', 'name': 'Kalamansig Campus', 'shortName': 'Kalamansig'},
    {'id': 'lutayan', 'name': 'Lutayan Campus', 'shortName': 'Lutayan'},
  ];

  List<String> get _availablePrograms => getProgramsForCampus(_selectedCampus);

  /// Organizations per campus and category (from organizations.dart)
  static const Map<String, Map<OrgCategory, List<String>>> _organizations = organizationData;

  List<String> get _filteredOrganizations {
    final campusOrgs = _organizations[_selectedCampus];
    if (campusOrgs == null) return [];
    return campusOrgs[_orgCategory] ?? [];
  }

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

    if (!kIsWeb && !ConnectivityService().isConnected) {
      showErrorSnackBar(
        context,
        'No internet connection. Please check your network.',
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.register(
      email: email,
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      department: _selectedDepartment,
      position: (_selectedRole == UserRole.studentLeader ||
              _selectedRole == UserRole.organizationOfficer)
          ? _positionController.text.trim()
          : null,
      organization: (_selectedRole == UserRole.studentLeader ||
              _selectedRole == UserRole.organizationOfficer)
          ? _selectedOrganization
          : null,
      campusId: _selectedCampus,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        authProvider.resetLoading();
        return false;
      },
    );

    if (mounted) {
      if (success) {
        final isStaff = _selectedRole == UserRole.studentLeader ||
            _selectedRole == UserRole.organizationOfficer;

        // Navigate to email verification screen (keep AuthWrapper alive below)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmailVerificationScreen(),
          ),
        );

        showSuccessSnackBar(
          context,
          isStaff
              ? 'Registration submitted! An admin will review your account. Please verify your email.'
              : 'Registration successful! A verification email has been sent — please verify your email.',
        );
      } else {
        final errorMsg = ErrorMessages.registerError(authProvider.error);
        showErrorSnackBar(context, errorMsg);
      }
      // Notify after showing the snackbar so mounted stayed true
      authProvider.resetLoading();
    }
  }

  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = Validators.passwordStrength(password);
    });
  }

  static const Map<String, Color> _campusColors = {
    'isulan': AppColors.primary,
    'tacurong': Colors.orange,
    'access': Colors.purple,
    'bagumbayan': Colors.teal,
    'palimbang': Colors.indigo,
    'kalamansig': Colors.pink,
    'lutayan': Colors.brown,
  };

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
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _campuses.length,
                itemBuilder: (context, index) {
                  final campus = _campuses[index];
                  final isSelected = _selectedCampus == campus['id'];
                  final color =
                      _campusColors[campus['id']] ?? AppColors.primary;

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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      campus['shortName']!,
                      style: const TextStyle(
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
                        _selectedOrganization = null;
                        _selectedDepartment = null;
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            title: 'Student Leader',
                            subtitle: 'Elected officer',
                            icon: Icons.leaderboard,
                            isSelected: _selectedRole == UserRole.studentLeader,
                            onTap: () {
                              setState(() {
                                _selectedRole = UserRole.studentLeader;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RoleCard(
                            title: 'Org Officer',
                            subtitle: 'Organization officer',
                            icon: Icons.groups,
                            isSelected: _selectedRole == UserRole.organizationOfficer,
                            onTap: () {
                              setState(() {
                                _selectedRole = UserRole.organizationOfficer;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    if (_selectedRole == UserRole.studentLeader ||
                        _selectedRole == UserRole.organizationOfficer) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your registration will be reviewed by an admin before your account is activated.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Text(
                      'My Campus:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildCampusSelector(),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            prefixIcon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                Validators.name(value, fieldName: 'first name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                Validators.name(value, fieldName: 'last name'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _emailController,
                      label: 'SKSU Email Address',
                      hint: 'your.name@sksu.edu.ph',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.email(v, requireSksuDomain: true),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Course/Program',
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Select a program...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ..._availablePrograms.map((program) {
                        return DropdownMenuItem(
                          value: program,
                          child: Text(program, overflow: TextOverflow.ellipsis),
                        );
                      }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a course/program';
                        }
                        return null;
                      },
                    ),

                    // Staff fields (Student Leader / Org Officer)
                    if (_selectedRole == UserRole.studentLeader ||
                        _selectedRole == UserRole.organizationOfficer) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Organization Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Org category toggle
                            Text(
                              'Organization Category',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _OrgCategoryChip(
                                    label: 'Academic',
                                    isSelected:
                                        _orgCategory == OrgCategory.academic,
                                    onTap: () {
                                      setState(() {
                                        _orgCategory = OrgCategory.academic;
                                        _selectedOrganization = null;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _OrgCategoryChip(
                                    label: 'Non-Academic',
                                    isSelected: _orgCategory ==
                                        OrgCategory.nonAcademic,
                                    onTap: () {
                                      setState(() {
                                        _orgCategory =
                                            OrgCategory.nonAcademic;
                                        _selectedOrganization = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Organization dropdown
                            if (_filteredOrganizations.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'No organizations available for this campus',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedOrganization,
                                decoration: const InputDecoration(
                                  labelText: 'Select Organization',
                                  prefixIcon: Icon(Icons.groups),
                                ),
                                items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Select an organization...',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                    ..._filteredOrganizations.map((org) {
                                  return DropdownMenuItem(
                                    value: org,
                                    child: Text(org),
                                  );
                                }),
                                  ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedOrganization = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select an organization';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 16),

                            // Leadership position (text input)
                            CustomTextField(
                              controller: _positionController,
                              label: 'Leadership Position',
                              hint: 'Type your position',
                              prefixIcon: Icons.badge_outlined,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your leadership position';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    PasswordTextField(
                      controller: _passwordController,
                      label: 'Password',
                      textInputAction: TextInputAction.next,
                      onChanged: _updatePasswordStrength,
                      validator: (value) =>
                          Validators.password(value, checkStrength: false),
                    ),

                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _passwordStrength / 4,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(
                                  Validators.passwordStrengthColor(
                                    _passwordStrength,
                                  ),
                                ),
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
                              color: Color(
                                Validators.passwordStrengthColor(
                                  _passwordStrength,
                                ),
                              ),
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
                      validator: (value) => Validators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),

                    const SizedBox(height: 24),

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
                          const Icon(
                            Icons.privacy_tip_outlined,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedRole == UserRole.studentLeader
                                  ? 'As a student leader, your location will be shared when tracking is active. You control when to share.'
                                  : 'Your privacy is protected. Only admins and student leaders with tracking enabled are visible on the map.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    PrimaryButton(
                      text: 'Create Account',
                      onPressed: _handleRegister,
                      isLoading: authProvider.isLoading,
                    ),

                    const SizedBox(height: 16),

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

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Semantics: announce as a selectable role. WCAG 1.4.1 — selected state
    // is conveyed by the semantic toggle, not just color.
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title role${isSelected ? ' (selected)' : ''}',
      hint: 'Double tap to select',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // Minimum 48dp tap target for accessibility (WCAG 2.5.5)
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrgCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrgCategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Semantics: announce as a selectable chip. WCAG 1.4.1 — selected state
    // is conveyed by the semantic toggle, not just color.
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label${isSelected ? ' (selected)' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // Minimum 48dp tap target — the original chip had ~32dp padding-only size
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
