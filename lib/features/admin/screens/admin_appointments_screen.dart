import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';

class AdminAppointmentsScreen extends StatelessWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthService = Provider.of<HealthService>(context);
    final appointments = healthService.appointments;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: appointments.isEmpty
          ? const Center(child: Text('No appointments scheduled'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appt = appointments[index];
                final healthProfile = healthService.getHealthProfile(
                  appt.userId,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF800000),
                      child: Text(
                        appt.userId.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('User: ${appt.userId}'),
                    subtitle: Text(
                      DateFormat('MMM d, y - h:mm a').format(appt.dateTime),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason: ${appt.reason}',
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
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (healthProfile != null) ...[
                              Text('Height: ${healthProfile.height} cm'),
                              Text('Weight: ${healthProfile.weight} kg'),
                              Text('Blood Type: ${healthProfile.bloodType}'),
                              Text('Allergies: ${healthProfile.allergies}'),
                              Text('Conditions: ${healthProfile.conditions}'),
                            ] else
                              const Text('No health profile available'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (appt.status == 'pending') ...[
                                  OutlinedButton(
                                    onPressed: () {
                                      healthService.updateAppointmentStatus(
                                        appt.id,
                                        'cancelled',
                                      );
                                    },
                                    child: const Text('Decline'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      healthService.updateAppointmentStatus(
                                        appt.id,
                                        'approved',
                                      );
                                    },
                                    child: const Text('Approve'),
                                  ),
                                ] else if (appt.status == 'approved') ...[
                                  ElevatedButton(
                                    onPressed: () {
                                      healthService.updateAppointmentStatus(
                                        appt.id,
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
            ),
    );
  }
}
