import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/models/daily_log.dart';

class AdminStudentDetailScreen extends StatelessWidget {
  final String studentId;

  const AdminStudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthService>(
      builder: (context, healthService, child) {
        final student = healthService.allStudents.firstWhere(
          (s) => s.id == studentId,
          orElse: () => throw Exception('Student not found'),
        );
        final profile = healthService.getHealthProfile(studentId);
        final logs = healthService.getDailyLogs(studentId);
        final statusData = healthService.getStudentStatus(studentId);
        final statusColor = Color(statusData['color'] as int);

        return Scaffold(
          appBar: AppBar(
            title: Text(student.name),
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: statusColor.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              Text(
                                '${student.program ?? "N/A"} • ${student.email}',
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  statusData['status'],
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (statusData['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  statusData['description'],
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.grey[700],
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
                ),
                const SizedBox(height: 24),

                // Health Profile Section
                Text(
                  'Health Profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF800000),
                  ),
                ),
                const SizedBox(height: 12),
                if (profile != null)
                  _buildProfileCard(context, profile)
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No health profile set."),
                    ),
                  ),

                const SizedBox(height: 24),

                // Check-in History
                Text(
                  'Recent Check-ins',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF800000),
                  ),
                ),
                const SizedBox(height: 12),
                if (logs.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      // Sorting is handled in service for status but list might be unsorted
                      return _buildLogCard(context, log);
                    },
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No check-ins found."),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, HealthInfo profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Height', '${profile.height} cm'),
            const Divider(),
            _buildInfoRow('Weight', '${profile.weight} kg'),
            const Divider(),
            _buildInfoRow('Blood Type', profile.bloodType),
            const Divider(),
            _buildInfoRow(
              'Allergies',
              profile.allergies.isEmpty ? 'None' : profile.allergies.join(', '),
            ),
            const Divider(),
            _buildInfoRow(
              'Conditions',
              profile.conditions.isEmpty
                  ? 'None'
                  : profile.conditions.join(', '),
              isWarning: profile.conditions.isNotEmpty,
            ),
            const Divider(),
            _buildInfoRow(
              'Emergency Contact',
              profile.emergencyContactPath.isEmpty
                  ? 'None'
                  : profile.emergencyContactPath,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isWarning ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, DailyLog log) {
    final isSick = log.mood == 'Sick' || log.symptoms.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSick
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('MMM').format(log.date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('d').format(log.date),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        title: Text('${log.mood} ${isSick ? "⚠️" : ""}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.symptoms.isNotEmpty)
              Text(
                'Symptoms: ${log.symptoms.join(", ")}',
                style: const TextStyle(color: Colors.red),
              ),
            if (log.notes.isNotEmpty) Text('Note: ${log.notes}'),
          ],
        ),
        trailing: Text('Sleep: ${log.sleepHours}h'),
      ),
    );
  }
}
