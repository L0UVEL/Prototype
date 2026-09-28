import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:convert';
import '../../../core/utils/platform_file_helper_stub.dart'
    if (dart.library.io) '../../../core/utils/platform_file_helper_io.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _programController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final tempPassword = authService.generatePassword();

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final error = await authService.registerUser(
        email: _emailController.text.trim(),
        password: tempPassword,
        studentId: _studentIdController.text.trim(),
        firstName: firstName,
        lastName: lastName,
        roleId: 'student',
        program: _programController.text.trim(),
      );

      if (mounted) {
        if (error == null) {
          // Show Success Dialog with Password
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Text(
                    'User Registered',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The user has been successfully registered.'),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.email_outlined, color: Color(0xFF4CAF50), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Login credentials have been sent to the student\'s email.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to dashboard
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF800000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Bulk registration state
  int _bulkTotal = 0;
  int _bulkProcessed = 0;
  bool _isBulkRegistering = false;

  Future<void> _bulkRegisterUsers() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result == null) return; // User canceled

      setState(() {
        _isLoading = true;
        _isBulkRegistering = false;
      });

      final pickedFile = result.files.single;
      final bytes = await getFileBytes(pickedFile);
      final extension = pickedFile.extension?.toLowerCase() ?? '';

      List<List<dynamic>> fields;

      if (extension == 'xlsx') {
        // Parse XLSX file
        final excel = Excel.decodeBytes(bytes);
        final firstSheet = excel.tables.keys.first;
        final sheet = excel.tables[firstSheet]!;
        fields = sheet.rows.map((row) {
          return row.map((cell) => cell?.value?.toString() ?? '').toList();
        }).toList();
      } else {
        // Parse CSV file
        String input;
        try {
          input = utf8.decode(bytes);
        } catch (_) {
          input = latin1.decode(bytes);
        }
        // Strip BOM if present
        if (input.startsWith('\uFEFF')) {
          input = input.substring(1);
        }
        fields = CsvCodec().decoder.convert(input);
      }

      if (fields.isEmpty || fields.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid or empty ${extension.toUpperCase()} file'),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // --- Pre-validation phase ---
      final dataRows = fields.sublist(1);
      final List<Map<String, dynamic>> validRows = [];
      final List<String> preErrors = [];
      final Set<String> seenEmails = {};
      int skippedDuplicates = 0;
      int skippedInvalid = 0;

      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNum = i + 2; // +2 because header is row 1, data starts row 2

        if (row.length < 5) {
          skippedInvalid++;
          preErrors.add('Row $rowNum: Not enough columns (need at least 5)');
          continue;
        }

        final email = row[4].toString().trim();
        if (email.isEmpty || !email.contains('@')) {
          skippedInvalid++;
          preErrors.add('Row $rowNum: Invalid email "$email"');
          continue;
        }

        final emailLower = email.toLowerCase();
        if (seenEmails.contains(emailLower)) {
          skippedDuplicates++;
          preErrors.add('Row $rowNum: Duplicate email "$email" (skipped)');
          continue;
        }
        seenEmails.add(emailLower);

        validRows.add({
          'rowNum': rowNum,
          'studentId': row[0].toString().trim(),
          'firstName': row[1].toString().trim(),
          'lastName': row[2].toString().trim(),
          'program': row[3].toString().trim(),
          'email': email,
        });
      }

      // Show pre-validation summary if there are issues
      if (preErrors.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF800000)),
                SizedBox(width: 8),
                Text(
                  'Pre-Check Results',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✓ ${validRows.length} students ready to register',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (skippedDuplicates > 0 || skippedInvalid > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (skippedDuplicates > 0)
                            Text('⚠ $skippedDuplicates duplicate emails skipped'),
                          if (skippedInvalid > 0)
                            Text('⚠ $skippedInvalid invalid rows skipped'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Do you want to proceed with registering ${validRows.length} students?',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          setState(() { _isLoading = false; });
          return;
        }
      }

      if (validRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid rows found to register'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() { _isLoading = false; });
        }
        return;
      }

      // --- Registration phase with progress + chunking ---
      if (!mounted) return;
      final authService = context.read<AuthService>();
      int successCount = 0;
      int failCount = 0;
      List<String> errors = List.from(preErrors);

      setState(() {
        _bulkTotal = validRows.length;
        _bulkProcessed = 0;
        _isBulkRegistering = true;
      });

      const int chunkSize = 10;
      const Duration delayBetweenChunks = Duration(seconds: 2);

      for (int i = 0; i < validRows.length; i++) {
        final rowData = validRows[i];

        final tempPassword = authService.generatePassword();

        final error = await authService.registerUser(
          email: rowData['email'],
          password: tempPassword,
          studentId: rowData['studentId'],
          firstName: rowData['firstName'],
          lastName: rowData['lastName'],
          roleId: 'student',
          program: rowData['program'],
        );

        if (error == null) {
          successCount++;
        } else {
          failCount++;
          errors.add('Row ${rowData['rowNum']} (${rowData['email']}): $error');
        }

        if (mounted) {
          setState(() {
            _bulkProcessed = i + 1;
          });
        }

        // Pause between chunks to avoid Firebase rate limits
        if ((i + 1) % chunkSize == 0 && i + 1 < validRows.length) {
          await Future.delayed(delayBetweenChunks);
        }
      }

      if (mounted) {
        setState(() {
          _isBulkRegistering = false;
        });

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.upload_file, color: Color(0xFF800000)),
                SizedBox(width: 8),
                Text(
                  'Bulk Registration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Successfully registered: $successCount',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (failCount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Failed: $failCount',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: errors.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                e,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBulkRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(title: const Text('Add New Student')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bulk Upload Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF800000,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            size: 20,
                            color: Color(0xFF800000),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bulk Upload',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _bulkRegisterUsers,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Upload Student List (CSV or Excel)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF800000),
                          side: const BorderSide(color: Color(0xFF800000)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CSV / XLSX Format: Student ID, First Name, Last Name, Program, Email (Header row required)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isBulkRegistering) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Registering students...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '$_bulkProcessed of $_bulkTotal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _bulkTotal > 0 ? _bulkProcessed / _bulkTotal : null,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF800000)),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _bulkTotal > 0 
                                  ? '${((_bulkProcessed / _bulkTotal) * 100).toStringAsFixed(0)}%' 
                                  : '0%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Divider with label
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 20),

              // Single Registration Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF800000,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            size: 20,
                            color: Color(0xFF800000),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Single Registration',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _studentIdController,
                      label: 'Student ID',
                      icon: Icons.badge,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Student ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _programController,
                      label: 'Program/Course',
                      hint: 'e.g. BSCS, BSIT',
                      icon: Icons.school,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter program/course';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _registerUser,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF800000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                          shadowColor: const Color(
                            0xFF800000,
                          ).withValues(alpha: 0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Register Student',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF800000)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF800000), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }
}
