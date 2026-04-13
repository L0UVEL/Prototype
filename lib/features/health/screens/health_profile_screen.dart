import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/health_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/health_service.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _healthInfoController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String? _profileImagePath;
  final List<String> _selectedAllergies = [];
  final List<String> _selectedConditions = [];

  bool _isDataLoaded = false;
  bool _isSaving = false;

  // Allergy options
  final List<String> _allergyOptions = [
    'Peanuts',
    'Shellfish',
    'Dairy',
    'Gluten',
    'Pollen',
    'Dust',
    'Latex',
    'Pet Dander',
    'Eggs',
    'Soy',
    'Medication',
    'Insect Stings',
  ];

  // Condition options
  final List<String> _conditionOptions = [
    'Asthma',
    'Diabetes',
    'Hypertension',
    'Heart Disease',
    'Epilepsy',
    'Anemia',
    'Migraine',
    'Scoliosis',
    'ADHD',
    'Thyroid Disorder',
    'Anxiety Disorder',
    'Depression',
  ];

  // Blood type options
  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _healthInfoController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _emergencyContactController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _healthInfoController.dispose();
    _bloodTypeController.dispose();
    _emergencyContactController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF800000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFF800000),
                ),
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF800000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF800000),
                ),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImagePath = pickedFile.path;
        });
      }
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final healthService = Provider.of<HealthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final newProfile = HealthProfile(
          profileId: user.id,
          studentId: user.studentId,
          userId: user.id,
          healthInformation: _healthInfoController.text,
          bloodType: _bloodTypeController.text,
          emergencyContact: _emergencyContactController.text,
          height: _heightController.text,
          weight: _weightController.text,
          allergies: List<String>.from(_selectedAllergies),
          conditions: List<String>.from(_selectedConditions),
          profileImagePath: _profileImagePath ?? '',
          lastUpdated: DateTime.now(),
        );

        await healthService.updateHealthProfile(newProfile);

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Health profile updated successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final healthService = Provider.of<HealthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
        title: const Text('Health Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<HealthProfile?>(
        stream: healthService.getHealthProfileStream(user.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;

          // Only populate if not already loaded to avoid overwriting user input while typing
          if (!_isDataLoaded && profile != null) {
            _healthInfoController.text = profile.healthInformation;
            _bloodTypeController.text = profile.bloodType;
            _emergencyContactController.text = profile.emergencyContact;
            _heightController.text = profile.height;
            _weightController.text = profile.weight;
            _profileImagePath = profile.profileImagePath.isNotEmpty
                ? profile.profileImagePath
                : null;
            _selectedAllergies.clear();
            _selectedAllergies.addAll(profile.allergies);
            _selectedConditions.clear();
            _selectedConditions.addAll(profile.conditions);
            _isDataLoaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Profile Picture ---
                  _buildProfilePictureSection(),
                  const SizedBox(height: 28),

                  // --- Height & Weight ---
                  _buildSectionHeader('Body Measurements', Icons.straighten),
                  const SizedBox(height: 12),
                  _buildHeightWeightRow(),
                  const SizedBox(height: 28),

                  // --- Blood Type ---
                  _buildSectionHeader('Blood Type', Icons.bloodtype),
                  const SizedBox(height: 12),
                  _buildBloodTypeSelector(),
                  const SizedBox(height: 28),

                  // --- Allergies ---
                  _buildSectionHeader('Allergies', Icons.warning_amber_rounded),
                  const SizedBox(height: 8),
                  Text(
                    'Select all that apply',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildChipSelector(
                    options: _allergyOptions,
                    selectedItems: _selectedAllergies,
                  ),
                  const SizedBox(height: 28),

                  // --- Conditions ---
                  _buildSectionHeader('Medical Conditions', Icons.local_hospital),
                  const SizedBox(height: 8),
                  Text(
                    'Select all that apply',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildChipSelector(
                    options: _conditionOptions,
                    selectedItems: _selectedConditions,
                  ),
                  const SizedBox(height: 28),

                  // --- Emergency Contact ---
                  _buildSectionHeader('Emergency Contact', Icons.contact_phone),
                  const SizedBox(height: 12),
                  _buildStyledTextField(
                    controller: _emergencyContactController,
                    hintText: 'Name: Phone Number',
                    icon: Icons.phone,
                  ),
                  const SizedBox(height: 28),

                  // --- Additional Notes ---
                  _buildSectionHeader(
                    'Additional Health Info',
                    Icons.note_alt_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildStyledTextField(
                    controller: _healthInfoController,
                    hintText: 'Any other health information...',
                    icon: Icons.description,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  // --- Save Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF800000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF800000).withValues(
                          alpha: 0.4,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Profile Picture Section
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF800000).withValues(alpha: 0.2),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: _profileImagePath != null
                      ? FileImage(File(_profileImagePath!))
                      : null,
                  child: _profileImagePath == null
                      ? const Icon(
                          Icons.person,
                          size: 56,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF800000),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF800000).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap camera to update photo',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Height & Weight Row
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeightWeightRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
                suffixStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.height,
                  color: Color(0xFF800000),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                suffixStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.monitor_weight_outlined,
                  color: Color(0xFF800000),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Blood Type Selector
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBloodTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _bloodTypes.map((type) {
        final isSelected = _bloodTypeController.text == type;
        return GestureDetector(
          onTap: () {
            setState(() {
              _bloodTypeController.text = type;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF800000)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF800000)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF800000).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FilterChip Selector (for allergies and conditions)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildChipSelector({
    required List<String> options,
    required List<String> selectedItems,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selectedItems.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          selectedColor: const Color(0xFF800000).withValues(alpha: 0.1),
          checkmarkColor: const Color(0xFF800000),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF800000) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF800000)
                  : Colors.grey.shade300,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: isSelected ? 2 : 0,
          shadowColor: const Color(0xFF800000).withValues(alpha: 0.2),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedItems.add(option);
              } else {
                selectedItems.remove(option);
              }
            });
          },
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Section Header
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF800000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF800000)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Styled Text Field
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(icon, color: const Color(0xFF800000)),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
