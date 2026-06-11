import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/services/activity_log_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate =
        now.weekday == DateTime.sunday ? now.add(const Duration(days: 1)) : now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2101),
      selectableDayPredicate: (DateTime date) {
        return date.weekday != DateTime.sunday;
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF800000),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  final List<TimeOfDay> _availableSlots = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 8, minute: 30),
    const TimeOfDay(hour: 9, minute: 0),
    const TimeOfDay(hour: 9, minute: 30),
    const TimeOfDay(hour: 10, minute: 0),
    const TimeOfDay(hour: 10, minute: 30),
    const TimeOfDay(hour: 11, minute: 0),
    const TimeOfDay(hour: 11, minute: 30),
    const TimeOfDay(hour: 13, minute: 0),
    const TimeOfDay(hour: 13, minute: 30),
    const TimeOfDay(hour: 14, minute: 0),
    const TimeOfDay(hour: 14, minute: 30),
    const TimeOfDay(hour: 15, minute: 0),
    const TimeOfDay(hour: 15, minute: 30),
  ];

  Future<void> _selectTime(BuildContext context) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    final healthService = Provider.of<HealthService>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Time',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF800000),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<DateTime>>(
                stream: healthService.getTakenSlotsForDateStream(_selectedDate!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final takenSlots = snapshot.data ?? [];
                  final takenTimes = takenSlots
                      .map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute))
                      .toSet();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _availableSlots.length,
                    itemBuilder: (context, index) {
                      final slot = _availableSlots[index];
                      final isTaken = takenTimes.contains(slot);
                      final isSelected = _selectedTime == slot;

                      return Material(
                        color: isTaken
                            ? Colors.grey.shade300
                            : isSelected
                                ? const Color(0xFF800000)
                                : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isTaken
                                ? Colors.transparent
                                : isSelected
                                    ? const Color(0xFF800000)
                                    : Colors.grey.shade400,
                          ),
                        ),
                        child: InkWell(
                          onTap: isTaken
                              ? null
                              : () {
                                  setState(() {
                                    _selectedTime = slot;
                                  });
                                  Navigator.pop(context);
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: Text(
                              slot.format(context),
                              style: TextStyle(
                                color: isTaken
                                    ? Colors.grey.shade500
                                    : isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                fontWeight: FontWeight.bold,
                                decoration: isTaken ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _scheduleAppointment() {
    if (_selectedDate == null ||
        _selectedTime == null ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final DateTime fullDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final authService = Provider.of<AuthService>(context, listen: false);
    final healthService = Provider.of<HealthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      healthService.addAppointment(
        user.id,
        user.studentId,
        fullDateTime,
        _reasonController.text,
      );

      try {
        if (mounted) {
          context.read<ActivityLogService>().logActivity(
            studentId: user.id,
            moduleName: 'Appointment',
            action: 'Scheduled Appointment for ${DateFormat('yyyy-MM-dd').format(fullDateTime)}',
          );
        }
      } catch (_) {}

      // Reset form
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _reasonController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment scheduled successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final healthService = Provider.of<HealthService>(context);
    final user = authService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Checkup')),
      body: StreamBuilder<List<Appointment>>(
        stream: user != null
            ? healthService.getAppointmentsStream(userId: user.id)
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: appointments.isEmpty
                    ? const Center(child: Text('No appointments scheduled'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appt = appointments[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF800000),
                              ),
                              title: Text(
                                DateFormat(
                                  'MMM d, y - h:mm a',
                                ).format(appt.appointmentDate),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reason: ${appt.reasonForVisit}'),
                                  Text(
                                    'Status: ${appt.status.toUpperCase()}',
                                    style: TextStyle(
                                      color: appt.status.toLowerCase() == 'approved' || appt.status.toLowerCase() == 'completed'
                                          ? Colors.green
                                          : appt.status.toLowerCase() == 'cancelled'
                                              ? Colors.red
                                              : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (appt.status.toLowerCase() == 'cancelled' &&
                                      appt.cancellationReason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Colors.red.shade300,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Reason: ${appt.cancellationReason}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade400,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await healthService.removeAppointment(
                                    appt.appointmentId,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Appointment cancelled'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              StreamBuilder<List<HealthUpdate>>(
                stream: user != null
                    ? healthService.getDailyLogsStream(user.id)
                    : const Stream.empty(),
                builder: (context, logSnapshot) {
                  bool checkedInToday = false;
                  if (logSnapshot.hasData && logSnapshot.data!.isNotEmpty) {
                    final latestLog = logSnapshot.data!.first;
                    final today = DateTime.now();
                    if (latestLog.checkinDate.year == today.year &&
                        latestLog.checkinDate.month == today.month &&
                        latestLog.checkinDate.day == today.day) {
                      checkedInToday = true;
                    }
                  }

                  if (!checkedInToday) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'You must complete your Daily Check-in today before booking an appointment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Book New Appointment',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectDate(context),
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  _selectedDate == null
                                      ? 'Select Date'
                                      : DateFormat(
                                          'MMM d, y',
                                        ).format(_selectedDate!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectTime(context),
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  _selectedTime == null
                                      ? 'Select Time'
                                      : _selectedTime!.format(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Reason for visit',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _scheduleAppointment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Schedule Appointment'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
