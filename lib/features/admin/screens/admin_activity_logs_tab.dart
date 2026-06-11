import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/services/activity_log_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/activity_log_model.dart';
import '../../../core/models/user_model.dart';

class AdminActivityLogsTab extends StatelessWidget {
  const AdminActivityLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: context.read<HealthService>().getStudentsStream(),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = studentsSnapshot.data ?? [];
        final studentMap = {for (var s in students) s.id: s};

        return StreamBuilder<List<ActivityLogModel>>(
          stream: context.read<ActivityLogService>().getAllLogs(),
          builder: (context, logsSnapshot) {
            if (logsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final logs = logsSnapshot.data ?? [];

            if (logs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF800000).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_activity_outlined,
                        size: 56,
                        color: Color(0xFF800000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No activity recorded yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final student = studentMap[log.studentId];
                final studentName = student?.name ?? 'Unknown Student';

                return _buildActivityCard(context, log, studentName);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityLogModel log, String studentName) {
    IconData getIconForModule(String module) {
      switch (module) {
        case 'AI Chat':
          return Icons.smart_toy;
        case 'Daily Check-in':
          return Icons.fact_check;
        case 'Appointment':
          return Icons.calendar_month;
        case 'Announcement':
          return Icons.campaign;
        default:
          return Icons.local_activity;
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
          '$studentName - ${log.moduleName}',
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
