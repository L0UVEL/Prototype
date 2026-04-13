import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/models/user_model.dart';

class AdminAppointmentsScreen extends StatelessWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthService = Provider.of<HealthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: StreamBuilder<List<Appointment>>(
        stream: healthService.getAppointmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data ?? [];

          if (appointments.isEmpty) {
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
                      Icons.calendar_today_outlined,
                      size: 56,
                      color: Color(0xFF800000),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No appointments scheduled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Appointments will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appt = appointments[index];

              return StreamBuilder<User>(
                stream: healthService.getStudentStream(appt.studentId),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data;
                  final displayName = user?.name ?? appt.studentId;

                  return StreamBuilder<HealthProfile?>(
                    stream: healthService.getHealthProfileStream(appt.studentId),
                    builder: (context, profileSnapshot) {
                      final healthProfile = profileSnapshot.data;

                      // Status badge color
                      Color statusColor;
                      IconData statusIcon;
                      switch (appt.status) {
                        case 'approved':
                          statusColor = const Color(0xFF4CAF50);
                          statusIcon = Icons.check_circle;
                          break;
                        case 'cancelled':
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel;
                          break;
                        case 'completed':
                          statusColor = const Color(0xFF1565C0);
                          statusIcon = Icons.task_alt;
                          break;
                        default:
                          statusColor = const Color(0xFFFFA000);
                          statusIcon = Icons.pending;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF800000).withValues(alpha: 0.12),
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFF800000),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, y - h:mm a').format(appt.appointmentDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 14, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        appt.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                Icons.medical_services_outlined,
                                'Reason',
                                appt.reasonForVisit,
                              ),
                              const SizedBox(height: 12),
                              if (healthProfile != null) ...[
                                _buildDetailRow(
                                  Icons.bloodtype,
                                  'Blood Type',
                                  healthProfile.bloodType.isEmpty
                                      ? 'Not set'
                                      : healthProfile.bloodType,
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.contact_phone,
                                  'Emergency Contact',
                                  healthProfile.emergencyContact.isEmpty
                                      ? 'Not set'
                                      : healthProfile.emergencyContact,
                                ),
                                if (healthProfile.healthInformation.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.info_outline,
                                    'Health Info',
                                    healthProfile.healthInformation,
                                  ),
                                ],
                              ] else
                                Text(
                                  'No health profile available',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (appt.status == 'pending') ...[
                                    OutlinedButton(
                                      onPressed: () {
                                        healthService.updateAppointmentStatus(
                                          appt.appointmentId,
                                          'cancelled',
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () {
                                        healthService.updateAppointmentStatus(
                                          appt.appointmentId,
                                          'approved',
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF800000),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ] else if (appt.status == 'approved') ...[
                                    FilledButton.icon(
                                      onPressed: () {
                                        healthService.updateAppointmentStatus(
                                          appt.appointmentId,
                                          'completed',
                                        );
                                      },
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Mark Completed'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF800000)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
