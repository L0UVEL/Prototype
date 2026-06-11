import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/activity_log_model.dart';
import '../../../core/services/activity_log_service.dart';

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

                            const SizedBox(height: 24),

                            // Activity Logs
                            _buildSectionHeader('Recent Activity', Icons.local_activity),
                            const SizedBox(height: 12),
                            StreamBuilder<List<ActivityLogModel>>(
                              stream: context.read<ActivityLogService>().getLogsForStudent(studentId),
                              builder: (context, activitySnapshot) {
                                if (activitySnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final activities = activitySnapshot.data ?? [];
                                if (activities.isEmpty) {
                                  return _buildEmptyCard('No recent activity recorded.');
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: activities.length,
                                  itemBuilder: (context, index) {
                                    return _buildActivityCard(context, activities[index]);
                                  },
                                );
                              },
                            ),
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
              backgroundImage: resolveProfileImage(imagePath),
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
    
    final statusColor = isSick ? const Color(0xFFD32F2F) : const Color(0xFF388E3C);
    final bgColor = isSick ? statusColor.withValues(alpha: 0.04) : Colors.white;
    final borderColor = isSick ? statusColor.withValues(alpha: 0.3) : Colors.grey.shade200;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (isSick)
            BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM').format(log.checkinDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(log.checkinDate),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        log.status,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSick ? statusColor : const Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isSick ? Icons.warning_rounded : Icons.check_circle_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (log.symptoms.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSick ? Colors.white : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSick ? statusColor.withValues(alpha: 0.2) : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 14,
                                color: isSick ? statusColor : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Symptoms & Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSick ? statusColor : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.symptoms,
                            style: TextStyle(
                              color: isSick ? statusColor.withValues(alpha: 0.9) : Colors.grey.shade800,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityLogModel log) {
    IconData getIconForModule(String module) {
      switch (module) {
        case 'AI Chat': return Icons.smart_toy;
        case 'Daily Check-in': return Icons.fact_check;
        case 'Appointment': return Icons.calendar_month;
        case 'Announcement': return Icons.campaign;
        default: return Icons.local_activity;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF800000).withValues(alpha: 0.1),
          child: Icon(
            getIconForModule(log.moduleName),
            color: const Color(0xFF800000),
          ),
        ),
        title: Text(
          log.moduleName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(log.action, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, y • h:mm a').format(log.timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

