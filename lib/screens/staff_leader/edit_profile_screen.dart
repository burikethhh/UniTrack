import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/widgets.dart';

/// Edit Profile Screen for Student Leaders and Organization Officers
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
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  List<DepartmentModel> _departments = [];
  List<String> _officeHours = [];

  @override
  void initState() {
    super.initState();
    // Load departments first, then user data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _loadDepartments();
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading departments: $e');
      }
      _loadUserData();
    });
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null && mounted) {
      setState(() {
        _firstNameController.text = user.firstName;
        _lastNameController.text = user.lastName;
        _positionController.text = user.position ?? '';
        _phoneController.text = user.phoneNumber ?? '';
        _selectedDepartment = user.department;
        _photoUrl = user.photoUrl;
        _officeHours = List<String>.from(user.officeHours ?? []);
      });
    }
  }

  Future<void> _loadDepartments() async {
    final databaseService = context.read<DatabaseService>();
    final departments = await databaseService.getAllDepartments();
    if (mounted) {
      setState(() {
        _departments = departments;
      });
    }
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
        withData: true, // Get bytes for cross-platform support
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        // Reject images larger than 2 MB
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Image is too large. Please select a photo under 2 MB.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoName = fileName;
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
    if (_selectedPhotoBytes == null) return _photoUrl;

    setState(() => _isUploadingPhoto = true);

    try {
      final storage = FirebaseStorage.instance;
      // Detect content type from file extension
      final ext = (_selectedPhotoName ?? '').split('.').last.toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      final fileExt = ext == 'png'
          ? 'png'
          : ext == 'webp'
          ? 'webp'
          : 'jpg';
      final fileName = 'profile_$userId.$fileExt';
      final ref = storage.ref().child('users/$userId/$fileName');

      // Upload bytes (works on both web and mobile)
      final TaskSnapshot uploadTask = await ref.putData(
        _selectedPhotoBytes!,
        SettableMetadata(contentType: contentType),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('Error uploading photo: $e');
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
      if (_selectedPhotoBytes != null) {
        newPhotoUrl = await _uploadPhoto(user.id);
      }

      // Create updated user using copyWith to preserve all fields
      final updatedUser = user.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        department: _selectedDepartment,
        position: _positionController.text.trim().isEmpty
            ? null
            : _positionController.text.trim(),
        photoUrl: newPhotoUrl,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        officeHours: _officeHours.isEmpty ? null : _officeHours,
      );

      // Update via auth provider (handles both Firestore and local state)
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

  Future<void> _addOfficeHour() async {
    final result = await showDialog<_OfficeHourEntry>(
      context: context,
      builder: (_) => const _OfficeHourDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        _officeHours.add('${result.day} ${result.start.format(context)} - ${result.end.format(context)}');
      });
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
        child: Builder(
          builder: (context) {
            final user = context.read<AuthProvider>().user;
            return SingleChildScrollView(
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
                              image: _selectedPhotoBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_selectedPhotoBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : _photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedPhotoBytes == null && _photoUrl == null
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
                                border: Border.all(color: Colors.white, width: 2),
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
                  DropdownButtonFormField<String>(
                    // Only use _selectedDepartment if it exists in the department list
                    initialValue:
                        _departments.any(
                          (d) => d.name == _selectedDepartment,
                        ) // ignore: deprecated_member_use
                        ? _selectedDepartment
                        : null,
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
                      ..._departments.map(
                        (dept) => DropdownMenuItem<String>(
                          value: dept.name,
                          child: Text(dept.name),
                        ),
                      ),
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

                  if (user != null && user.isStaff) ...[
                    const SizedBox(height: 24),

                    // Office Hours Section
                    _buildSectionHeader('Office Hours'),
                    const SizedBox(height: 4),
                    Text(
                      'Add your available hours so students know when to find you.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._officeHours.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final slot = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                slot,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: AppColors.error,
                              onPressed: () {
                                setState(() {
                                  _officeHours.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _addOfficeHour,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Office Hour'),
                      ),
                    ),
                  ],

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
                      if (!RegExp(
                        r'^(09|\+639)\d{9}$',
                      ).hasMatch(value.replaceAll(' ', ''))) {
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
            );
          },
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

/// Dialog result for office hour entry.
class _OfficeHourEntry {
  final String day;
  final TimeOfDay start;
  final TimeOfDay end;
  const _OfficeHourEntry(this.day, this.start, this.end);
}

class _OfficeHourDialog extends StatefulWidget {
  const _OfficeHourDialog();

  @override
  State<_OfficeHourDialog> createState() => _OfficeHourDialogState();
}

class _OfficeHourDialogState extends State<_OfficeHourDialog> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _selectedDay = 'Mon';
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return AlertDialog(
      title: const Text('Add Office Hour'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Day', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
            items: _days
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDay = v!),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: now,
                    );
                    if (t != null) setState(() => _start = t);
                  },
                  child: Text(
                    _start == null
                        ? 'Start'
                        : _start!.format(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _end ?? now,
                    );
                    if (t != null) setState(() => _end = t);
                  },
                  child: Text(
                    _end == null
                        ? 'End'
                        : _end!.format(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_start != null && _end != null)
              ? () => Navigator.pop(
                    context,
                    _OfficeHourEntry(_selectedDay, _start!, _end!),
                  )
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
