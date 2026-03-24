import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _healthInfoController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _emergencyContactController = TextEditingController();
  }

  bool _isDataLoaded = false;

  @override
  void dispose() {
    _healthInfoController.dispose();
    _bloodTypeController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final healthService = Provider.of<HealthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final newProfile = HealthProfile(
          profileId: user.id, // Using the same doc Id
          studentId: user.studentId,
          userId: user.id,
          healthInformation: _healthInfoController.text,
          bloodType: _bloodTypeController.text,
          emergencyContact: _emergencyContactController.text,
          lastUpdated: DateTime.now(),
        );

        healthService.updateHealthProfile(newProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health profile updated successfully!')),
        );
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
      appBar: AppBar(title: const Text('My Health Profile')),
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
            _isDataLoaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.medical_information,
                            size: 48,
                            color: Color(0xFF800000),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Personal Health Record',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _healthInfoController,
                    decoration: const InputDecoration(
                      labelText: 'Health Information (Allergies, conditions, etc)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bloodTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Blood Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bloodtype),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emergencyContactController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact (Name: Number)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_phone),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
