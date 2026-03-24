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
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: StreamBuilder<List<Appointment>>(
        stream: healthService.getAppointmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data ?? [];

          if (appointments.isEmpty) {
            return const Center(child: Text('No appointments scheduled'));
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF800000),
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName.substring(0, 1).toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('User: $displayName'),
                          subtitle: Text(
                            DateFormat(
                              'MMM d, y - h:mm a',
                            ).format(appt.appointmentDate),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason: ${appt.reasonForVisit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Status: ${appt.status.toUpperCase()}'),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const Text(
                                    'Health Information:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (healthProfile != null) ...[
                                    Text('Health Information:\n${healthProfile.healthInformation}'),
                                    Text(
                                      'Blood Type: ${healthProfile.bloodType}',
                                    ),
                                    Text(
                                      'Emergency Contact: ${healthProfile.emergencyContact}',
                                    ),
                                    Text(
                                      'Last Updated: ${DateFormat('yyyy-MM-dd').format(healthProfile.lastUpdated)}',
                                    ),
                                  ] else
                                    const Text('No health profile available'),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (appt.status == 'pending') ...[
                                        OutlinedButton(
                                          onPressed: () {
                                            healthService
                                                .updateAppointmentStatus(
                                                  appt.appointmentId,
                                                  'cancelled',
                                                );
                                          },
                                          child: const Text('Decline'),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            healthService
                                                .updateAppointmentStatus(
                                                  appt.appointmentId,
                                                  'approved',
                                                );
                                          },
                                          child: const Text('Approve'),
                                        ),
                                      ] else if (appt.status == 'approved') ...[
                                        ElevatedButton(
                                          onPressed: () {
                                            healthService
                                                .updateAppointmentStatus(
                                                  appt.appointmentId,
                                                  'completed',
                                                );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          child: const Text('Mark Completed'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
}
