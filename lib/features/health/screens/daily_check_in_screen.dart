import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/daily_log.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({super.key});

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> {
  String? _mood;
  final List<String> _selectedSymptoms = [];
  final _notesController = TextEditingController();
  bool _submitted = false;

  final List<String> _moods = ['Great', 'Good', 'Okay', 'Bad', 'Terrible'];
  final List<String> _symptoms = [
    'Headache',
    'Fever',
    'Cough',
    'Fatigue',
    'Nauseous',
    'Anxiety',
    'Stress',
    'Insomnia',
  ];

  @override
  void initState() {
    super.initState();
    _checkTodayLog();
  }

  void _checkTodayLog() {
    final healthService = context.read<HealthService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user != null) {
      final latestLog = healthService.getLatestLog(user.id);
      if (latestLog != null) {
        final today = DateTime.now();
        if (latestLog.date.year == today.year &&
            latestLog.date.month == today.month &&
            latestLog.date.day == today.day) {
          setState(() {
            _submitted = true;
          });
        }
      }
    }
  }

  void _submitCheckIn() {
    if (_mood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select how you are feeling')),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final healthService = context.read<HealthService>();
    final user = authService.currentUser;

    if (user != null) {
      final log = DailyLog(
        id: const Uuid().v4(),
        userId: user.id,
        date: DateTime.now(),
        mood: _mood!,
        symptoms: List.from(_selectedSymptoms),
        notes: _notesController.text,
      );

      healthService.addDailyLog(log);
      setState(() {
        _submitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in submitted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Check-in')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: const Color(0xFF00BFA5), // Teal/Emerald
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "You're all set!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Thanks for checking in today.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Check-in'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(
              'How are you feeling?',
              Icons.sentiment_satisfied_alt,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                itemBuilder: (context, index) {
                  final mood = _moods[index];
                  final isSelected = _mood == mood;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _mood = isSelected ? null : mood;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      width: 80,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF800000)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF800000)
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(
                                0xFF800000,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getMoodIcon(mood),
                            color: isSelected ? Colors.white : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mood,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Symptoms', Icons.healing),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: _symptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: const Color(0xFF800000).withValues(alpha: 0.1),
                  checkmarkColor: const Color(0xFF800000),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF800000)
                        : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF800000)
                          : Colors.grey.shade300,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Notes', Icons.note_alt_outlined),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Add any specific details here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                maxLines: 4,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _submitCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF800000).withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Submit Check-in',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Great':
        return Icons.sentiment_very_satisfied;
      case 'Good':
        return Icons.sentiment_satisfied;
      case 'Okay':
        return Icons.sentiment_neutral;
      case 'Bad':
        return Icons.sentiment_dissatisfied;
      case 'Terrible':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }
}
