import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/auth_service.dart';

class HealthLandingScreen extends StatelessWidget {
  const HealthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Health')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDailyCheckInCard(context),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              title: 'Health Profile',
              subtitle: 'View and update your medical information',
              icon: Icons.person_outline,
              onTap: () => context.push('/health-profile'),
              color: Colors.blue.shade50,
              iconColor: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              title: 'Appointments',
              subtitle: 'Schedule and manage clinic visits',
              icon: Icons.calendar_month_outlined,
              onTap: () => context.push('/schedule'),
              color: Colors.orange.shade50,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCheckInCard(BuildContext context) {
    return Consumer<HealthService>(
      builder: (context, healthService, _) {
        final authService = context.read<AuthService>();
        final user = authService.currentUser;
        bool checkedInToday = false;

        if (user != null) {
          final latestLog = healthService.getLatestLog(user.id);
          if (latestLog != null) {
            final today = DateTime.now();
            if (latestLog.date.year == today.year &&
                latestLog.date.month == today.month &&
                latestLog.date.day == today.day) {
              checkedInToday = true;
            }
          }
        }

        return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: checkedInToday
                    ? [const Color(0xFF00695C), const Color(0xFF4DB6AC)]
                    : [const Color(0xFF800000), const Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: checkedInToday
                      ? Colors.teal.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/daily-check-in'),
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        checkedInToday
                            ? Icons.check_circle_outline
                            : Icons.edit_note,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  checkedInToday
                                      ? Icons.check
                                      : Icons.notifications_active,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  checkedInToday
                                      ? 'COMPLETED TODAY'
                                      : 'ACTION REQUIRED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            checkedInToday
                                ? "You're all set!"
                                : 'Daily Check-in',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            checkedInToday
                                ? 'Good job tracking your health.'
                                : 'Track your symptoms & mood.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
