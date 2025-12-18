import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/health_model.dart';
import '../models/daily_log.dart';
import '../models/user_model.dart';

class HealthService extends ChangeNotifier {
  // In-memory storage
  final Map<String, HealthInfo> _healthProfiles = {};
  final List<DailyLog> _dailyLogs = [];
  final List<Appointment> _appointments = [];
  final List<User> _dummyStudents = [];

  HealthService() {
    _initializeDummyData();
  }

  void _initializeDummyData() {
    // 1. Create Dummy Students
    _dummyStudents.addAll([
      User(
        id: 's1',
        email: 'juan.delacruz@student.pup.edu.ph',
        name: 'Juan Dela Cruz',
        role: UserRole.user,
        program: 'BSIT',
      ),
      User(
        id: 's2',
        email: 'maria.reyes@student.pup.edu.ph',
        name: 'Maria Reyes',
        role: UserRole.user,
        program: 'BSENT',
      ),
      User(
        id: 's3',
        email: 'jose.santos@student.pup.edu.ph',
        name: 'Jose Santos',
        role: UserRole.user,
        program: 'BEEd',
      ),
      User(
        id: 's4',
        email: 'ana.gonzales@student.pup.edu.ph',
        name: 'Ana Gonzales',
        role: UserRole.user,
        program: 'BPA',
      ),
      User(
        id: 's5',
        email: 'pedro.fernandez@student.pup.edu.ph',
        name: 'Pedro Fernandez',
        role: UserRole.user,
        program: 'DOMT',
      ),
    ]);

    // 2. Create Dummy Health Profiles
    _healthProfiles['s1'] = HealthInfo(
      userId: 's1',
      height: 170,
      weight: 65,
      bloodType: 'O+',
      conditions: ['Asthma'],
      allergies: ['Peanuts'],
      emergencyContactPath: 'Father: 09123456789',
    );
    _healthProfiles['s2'] = HealthInfo(
      userId: 's2',
      height: 160,
      weight: 50,
      bloodType: 'A+',
      conditions: [],
      allergies: [],
      emergencyContactPath: 'Mother: 09987654321',
    );
    _healthProfiles['s3'] = HealthInfo(
      userId: 's3',
      height: 175,
      weight: 80,
      bloodType: 'B-',
      conditions: ['Hypertension'],
      allergies: ['Seafood'],
      emergencyContactPath: 'Wife: 09112233445',
    );
    // Students s4 and s5 might have incomplete profiles

    // 3. Create Daily Logs (Simulating Check-ins)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // s1: Checked in today, feeling okay
    _dailyLogs.add(
      DailyLog(
        id: 'l1',
        userId: 's1',
        date: today,
        mood: 'Happy',
        symptoms: [],
        sleepHours: 8,
        notes: 'Feeling good',
      ),
    );

    // s2: Checked in today, feeling sick
    _dailyLogs.add(
      DailyLog(
        id: 'l2',
        userId: 's2',
        date: today,
        mood: 'Sick',
        symptoms: ['Fever', 'Cough'],
        sleepHours: 5,
        notes: 'Not feeling well',
      ),
    );

    // s3: Checked in yesterday (Missed today)
    _dailyLogs.add(
      DailyLog(
        id: 'l3',
        userId: 's3',
        date: yesterday,
        mood: 'Neutral',
        symptoms: [],
        sleepHours: 7,
        notes: '',
      ),
    );

    // s4, s5: No logs
  }

  List<User> get allStudents => List.unmodifiable(_dummyStudents);

  // Helper to determine status
  // Returns: 'Healthy' (Green), 'Monitor' (Yellow), 'At Risk' (Red), 'No Data' (Grey)
  Map<String, dynamic> getStudentStatus(String userId) {
    final logs = getDailyLogs(userId);
    if (logs.isEmpty) {
      return {
        'status': 'No Data',
        'color': 0xFF9E9E9E,
        'description': 'No check-ins yet',
      };
    }

    // Sort logs by date descending
    logs.sort((a, b) => b.date.compareTo(a.date));
    final latestLog = logs.first;

    final now = DateTime.now();
    final isToday =
        latestLog.date.year == now.year &&
        latestLog.date.month == now.month &&
        latestLog.date.day == now.day;

    if (!isToday) {
      return {
        'status': 'Missed Check-in',
        'color': 0xFFFFA000,
        'description': 'Last check-in: ${_formatDate(latestLog.date)}',
      };
    }

    if (latestLog.symptoms.isNotEmpty || latestLog.mood == 'Sick') {
      return {
        'status': 'At Risk',
        'color': 0xFFD32F2F,
        'description': 'Reported symptoms: ${latestLog.symptoms.join(", ")}',
      };
    }

    return {
      'status': 'Healthy',
      'color': 0xFF388E3C,
      'description': 'Checked in today',
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  // Getters
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<DailyLog> get dailyLogs => List.unmodifiable(_dailyLogs);

  // Health Profile Methods
  HealthInfo? getHealthProfile(String userId) {
    return _healthProfiles[userId];
  }

  void updateHealthProfile(HealthInfo info) {
    _healthProfiles[info.userId] = info;
    notifyListeners();
  }

  // Daily Log Methods
  List<DailyLog> getDailyLogs(String userId) {
    return _dailyLogs.where((log) => log.userId == userId).toList();
  }

  DailyLog? getLatestLog(String userId) {
    final userLogs = getDailyLogs(userId);
    if (userLogs.isEmpty) return null;
    userLogs.sort((a, b) => b.date.compareTo(a.date));
    return userLogs.first;
  }

  void addDailyLog(DailyLog log) {
    _dailyLogs.add(log);
    notifyListeners();
  }

  // Appointment Methods
  List<Appointment> getAppointmentsForUser(String userId) {
    return _appointments.where((appt) => appt.userId == userId).toList();
  }

  void addAppointment(String userId, DateTime dateTime, String reason) {
    final newAppointment = Appointment(
      id: const Uuid().v4(),
      userId: userId,
      dateTime: dateTime,
      reason: reason,
    );
    _appointments.add(newAppointment);
    notifyListeners();
  }

  void removeAppointment(String appointmentId) {
    _appointments.removeWhere((appt) => appt.id == appointmentId);
    notifyListeners();
  }

  void updateAppointmentStatus(String appointmentId, String status) {
    final index = _appointments.indexWhere((appt) => appt.id == appointmentId);
    if (index != -1) {
      final oldAppt = _appointments[index];
      _appointments[index] = Appointment(
        id: oldAppt.id,
        userId: oldAppt.userId,
        dateTime: oldAppt.dateTime,
        reason: oldAppt.reason,
        status: status,
      );
      notifyListeners();
    }
  }
}
