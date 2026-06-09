import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/image_utils.dart';

class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() => _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Pending', 'Approved', 'Completed', 'Cancelled'];

  void _showCancellationReasonDialog(
    BuildContext context,
    HealthService healthService,
    String appointmentId,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Decline Appointment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for declining this appointment.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'e.g. Schedule conflict, unavailable, etc.',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.note_alt_outlined, color: Color(0xFF800000)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF800000), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please provide a cancellation reason'),
                    backgroundColor: Colors.red.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                return;
              }
              healthService.updateAppointmentStatus(
                appointmentId,
                'cancelled',
                cancellationReason: reason,
              );
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF800000),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF800000),
              side: BorderSide(
                color: isSelected ? const Color(0xFF800000) : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthService = Provider.of<HealthService>(context);
    return Container(
      color: const Color(0xFFF8F5F2),
      child: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: StreamBuilder<List<Appointment>>(
              stream: healthService.getAppointmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF800000)));
                }

                var appointments = snapshot.data ?? [];
                
                // Apply filter
                if (_selectedFilter != 'All') {
                  appointments = appointments
                      .where((appt) => appt.status.toLowerCase() == _selectedFilter.toLowerCase())
                      .toList();
                }

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
                        Text(
                          _selectedFilter == 'All' 
                              ? 'No appointments scheduled' 
                              : 'No $_selectedFilter appointments',
                          style: const TextStyle(
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appt = appointments[index];

                    return StreamBuilder<User>(
                      stream: healthService.getStudentStream(appt.userId),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data;
                        final displayName = user?.name ?? appt.studentId;

                        return StreamBuilder<HealthProfile?>(
                          stream: healthService.getHealthProfileStream(appt.userId),
                          builder: (context, profileSnapshot) {
                            final healthProfile = profileSnapshot.data;
                            final profilePath = healthProfile?.profileImagePath ?? '';

                            // Status badge color
                            Color statusColor;
                            IconData statusIcon;
                            switch (appt.status.toLowerCase()) {
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
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: statusColor,
                                      width: 4,
                                    ),
                                  ),
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
                                          shape: const RoundedRectangleBorder(
                                            side: BorderSide.none,
                                          ),
                                          leading: profilePath.isNotEmpty
                                              ? CircleAvatar(
                                                  radius: 22,
                                                  backgroundImage: resolveProfileImage(profilePath),
                                                  onBackgroundImageError: (_, __) {},
                                                  backgroundColor: const Color(0xFF800000).withValues(alpha: 0.12),
                                                )
                                              : CircleAvatar(
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
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                DateFormat('MMM d, y • h:mm a').format(appt.appointmentDate),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: statusColor.withValues(alpha: 0.3),
                                                    width: 1,
                                                  )
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
                                            const Divider(height: 24),
                                            _buildDetailRow(
                                              Icons.medical_services_outlined,
                                              'Reason for Visit',
                                              appt.reasonForVisit,
                                            ),
                                            const SizedBox(height: 12),
                                            if (appt.status.toLowerCase() == 'cancelled' &&
                                                appt.cancellationReason.isNotEmpty) ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.red.withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.info_outline,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Cancellation Reason',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.red.shade400,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            appt.cancellationReason,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
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
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (appt.status.toLowerCase() == 'pending') ...[
                                                  OutlinedButton(
                                                    onPressed: () {
                                                      _showCancellationReasonDialog(
                                                        context,
                                                        healthService,
                                                        appt.appointmentId,
                                                      );
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                      side: const BorderSide(color: Colors.red),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                                    ),
                                                    child: const Text('Decline'),
                                                  ),
                                                  const SizedBox(width: 12),
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
                                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                                    ),
                                                    child: const Text('Approve'),
                                                  ),
                                                ] else if (appt.status.toLowerCase() == 'approved') ...[
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
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF800000).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF800000)),
        ),
        const SizedBox(width: 12),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

