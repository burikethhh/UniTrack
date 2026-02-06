import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/widgets.dart';

/// Edit Profile Screen for Staff/Faculty
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String? _selectedDepartment;
  String? _photoUrl;
  File? _selectedPhoto;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  List<DepartmentModel> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDepartments();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _positionController.text = user.position ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _selectedDepartment = user.department;
      _photoUrl = user.photoUrl;
    }
  }

  Future<void> _loadDepartments() async {
    final databaseService = context.read<DatabaseService>();
    final departments = await databaseService.getAllDepartments();
    setState(() {
      _departments = departments;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPhoto = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _uploadPhoto(String userId) async {
    if (_selectedPhoto == null) return _photoUrl;

    setState(() => _isUploadingPhoto = true);

    try {
      final storage = FirebaseStorage.instance;
      final fileName = 'profile_$userId.jpg';
      final ref = storage.ref().child('profile_photos/$fileName');

      // Upload file
      final uploadTask = await ref.putFile(
        _selectedPhoto!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return _photoUrl; // Return existing URL on error
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload photo if changed
      String? newPhotoUrl = _photoUrl;
      if (_selectedPhoto != null) {
        newPhotoUrl = await _uploadPhoto(user.id);
      }

      // Create updated user model
      final updatedUser = UserModel(
        id: user.id,
        email: user.email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        role: user.role,
        department: _selectedDepartment,
        position: _positionController.text.trim().isEmpty 
            ? null 
            : _positionController.text.trim(),
        photoUrl: newPhotoUrl,
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        isActive: user.isActive,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        campusId: user.campusId,
        isTrackingEnabled: user.isTrackingEnabled,
        currentStatus: user.currentStatus,
        quickMessage: user.quickMessage,
        officeHours: user.officeHours,
        availabilityStatus: user.availabilityStatus,
        customStatusMessage: user.customStatusMessage,
        statusUpdatedAt: user.statusUpdatedAt,
      );

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update(updatedUser.toFirestore());

      // Update auth provider
      await authProvider.updateProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading || _isUploadingPhoto)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Photo Section
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3,
                          ),
                          image: _selectedPhoto != null
                              ? DecorationImage(
                                  image: FileImage(_selectedPhoto!),
                                  fit: BoxFit.cover,
                                )
                              : _photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: _selectedPhoto == null && _photoUrl == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.textSecondary,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_isUploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Change Photo'),
                ),
              ),

              const SizedBox(height: 24),

              // Personal Information Section
              _buildSectionHeader('Personal Information'),
              const SizedBox(height: 12),

              // First Name
              CustomTextField(
                controller: _firstNameController,
                label: 'First Name',
                hint: 'Enter your first name',
                prefixIcon: Icons.person_outline,
                validator: Validators.required,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Last Name
              CustomTextField(
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'Enter your last name',
                prefixIcon: Icons.person_outline,
                validator: Validators.required,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Work Information Section
              _buildSectionHeader('Work Information'),
              const SizedBox(height: 12),

              // Department Dropdown
              DropdownButtonFormField<String>( // ignore: deprecated_member_use
                value: _selectedDepartment,
                decoration: InputDecoration(
                  labelText: 'Department',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select Department'),
                  ),
                  ..._departments.map((dept) => DropdownMenuItem<String>(
                    value: dept.name,
                    child: Text(dept.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Position
              CustomTextField(
                controller: _positionController,
                label: 'Position',
                hint: 'e.g., Professor, Instructor, Dean',
                prefixIcon: Icons.work_outline,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Contact Information Section
              _buildSectionHeader('Contact Information'),
              const SizedBox(height: 12),

              // Phone Number
              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: '09XX XXX XXXX',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return null; // Optional
                  // Simple Philippine phone validation
                  if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(value.replaceAll(' ', ''))) {
                    return 'Enter a valid Philippine mobile number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Save Button
              PrimaryButton(
                text: 'Save Changes',
                onPressed: _saveProfile,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Cancel Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}
