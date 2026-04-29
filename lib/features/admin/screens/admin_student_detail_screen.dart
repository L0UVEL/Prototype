import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/models/user_model.dart';

class AdminStudentDetailScreen extends StatelessWidget {
  final String studentId;

  const AdminStudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthService>(
      builder: (context, healthService, child) {
        return StreamBuilder<User>(
          stream: healthService.getStudentStream(studentId),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError || !userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text('Student not found')),
              );
            }

            final student = userSnapshot.data!;

            return StreamBuilder<HealthProfile?>(
              stream: healthService.getHealthProfileStream(studentId),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;

                return StreamBuilder<List<HealthUpdate>>(
                  stream: healthService.getDailyLogsStream(studentId),
                  builder: (context, logsSnapshot) {
                    final logs = logsSnapshot.data ?? [];
                    final statusData = healthService.calculateStudentStatus(
                      logs,
                    );
                    final statusColor = Color(statusData['color'] as int);

                    return Scaffold(
                      backgroundColor: const Color(0xFFF8F5F2),
                      appBar: AppBar(
                        title: Text(student.name),
                      ),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Status Card
                            Container(
                              width: double.infinity,
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
                              child: Row(
                                children: [
                                  // Profile picture or avatar
                                  _buildProfileAvatar(profile, statusColor),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D2D2D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${student.program ?? "N/A"} • ${student.email}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: statusColor.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            statusData['status'],
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (statusData['description'] !=
                                            null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            statusData['description'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Health Profile Section
                            _buildSectionHeader('Health Profile', Icons.medical_information),
                            const SizedBox(height: 12),
                            if (profile != null)
                              _buildProfileCard(context, profile)
                            else
                              _buildEmptyCard('No health profile set.'),

                            const SizedBox(height: 24),

                            // Check-in History
                            _buildSectionHeader('Recent Check-ins', Icons.timeline),
                            const SizedBox(height: 12),
                            if (logs.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  final log = logs[index];
                                  return _buildLogCard(context, log);
                                },
                              )
                            else
                              _buildEmptyCard('No check-ins found.'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileAvatar(HealthProfile? profile, Color statusColor) {
    final imagePath = profile?.profileImagePath ?? '';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: imagePath.isNotEmpty
          ? CircleAvatar(
              radius: 30,
              backgroundImage: FileImage(File(imagePath)),
              onBackgroundImageError: (_, __) {},
              backgroundColor: statusColor.withValues(alpha: 0.15),
            )
          : CircleAvatar(
              radius: 30,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: 30, color: statusColor),
            ),
    );
  }

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

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, HealthProfile profile) {
    return Container(
      width: double.infinity,
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
          _buildInfoRow(Icons.info_outline, 'Health Information', profile.healthInformation),
          const Divider(height: 20),
          _buildInfoRow(Icons.bloodtype, 'Blood Type', profile.bloodType),
          if (profile.height.isNotEmpty || profile.weight.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.straighten,
              'Body',
              '${profile.height.isNotEmpty ? "${profile.height} cm" : "—"} / ${profile.weight.isNotEmpty ? "${profile.weight} kg" : "—"}',
            ),
          ],
          if (profile.allergies.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.warning_amber_rounded,
              'Allergies',
              profile.allergies.join(', '),
            ),
          ],
          if (profile.conditions.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.local_hospital,
              'Conditions',
              profile.conditions.join(', '),
            ),
          ],
          const Divider(height: 20),
          _buildInfoRow(
            Icons.contact_phone,
            'Emergency Contact',
            profile.emergencyContact.isEmpty
                ? 'None'
                : profile.emergencyContact,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF800000)),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D2D2D),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(BuildContext context, HealthUpdate log) {
    final isSick = log.status == 'At Risk';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSick
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF800000).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(log.checkinDate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Color(0xFF800000),
                ),
              ),
              Text(
                DateFormat('d').format(log.checkinDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF800000),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          '${log.status} ${isSick ? "⚠️" : ""}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.symptoms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Symptoms & Notes: ${log.symptoms}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
