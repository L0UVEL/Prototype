import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';

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
  final _nameController = TextEditingController();
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

      final fullName = _nameController.text.trim();
      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

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
              title: const Text('User Registered'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The user has been successfully registered.'),
                  const SizedBox(height: 16),
                  const Text(
                    'Login Credentials:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText('Email: ${_emailController.text.trim()}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Password: '),
                      SelectableText(
                        tempPassword,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'An email with these credentials has been sent to the student.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
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

  Future<void> _bulkRegisterUsers() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return; // User canceled

      setState(() {
        _isLoading = true;
      });

      final file = File(result.files.single.path!);
      final input = await file.readAsString();
      final fields = CsvCodec().decode(input);

      if (fields.isEmpty || fields.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or empty CSV file')),
          );
        }
        return;
      }

      if (!mounted) return;

      final authService = context.read<AuthService>();
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Assume row 0 is header. Start from row 1.
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length >= 4) {
          final studentId = row[0].toString();
          final name = row[1].toString();
          final program = row[2].toString();
          final email = row[3].toString();

          // Basic validation
          if (email.isEmpty || !email.contains('@')) {
            failCount++;
            errors.add('Row $i: Invalid email $email');
            continue;
          }

          final tempPassword = authService.generatePassword();

          final fullName = name.trim();
          final nameParts = fullName.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts.first : '';
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

          final error = await authService.registerUser(
            email: email.trim(),
            password: tempPassword,
            studentId: studentId.trim(),
            firstName: firstName,
            lastName: lastName,
            roleId: 'student',
            program: program.trim(),
          );

          if (error == null) {
            successCount++;
          } else {
            failCount++;
            errors.add('Row $i ($email): $error');
          }
        } else {
          failCount++;
          errors.add('Row $i: Insufficient columns');
        }
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Registration Results'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Successfully registered: $successCount'),
                  Text('Failed: $failCount'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Errors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...errors.map(
                      (e) => Text(
                        e,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
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
            content: Text('Error processing CSV: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register Student Account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _bulkRegisterUsers,
                icon: const Icon(Icons.upload_file),
                label: const Text('Bulk Upload CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'CSV Format: Student ID, Name, Program, Email (Header row required)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Single Registration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Student ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _programController,
                decoration: const InputDecoration(
                  labelText: 'Program/Course',
                  hintText: 'e.g. BSCS, BSIT',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter program/course';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _registerUser,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
