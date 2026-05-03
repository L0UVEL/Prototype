import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/models/health_model.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/image_utils.dart';

class HealthLandingScreen extends StatelessWidget {
  const HealthLandingScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final healthService = context.read<HealthService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: StreamBuilder<List<HealthUpdate>>(
        stream: healthService.getDailyLogsStream(user.id),
        builder: (context, snapshot) {
          bool checkedInToday = false;
          HealthUpdate? latestLog;
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            latestLog = snapshot.data!.first;
            final today = DateTime.now();
            if (latestLog.checkinDate.year == today.year &&
                latestLog.checkinDate.month == today.month &&
                latestLog.checkinDate.day == today.day) {
              checkedInToday = true;
            }
          }

          final notificationService = Provider.of<NotificationService>(
            context,
            listen: false,
          );

          if (checkedInToday) {
            notificationService.cancelCheckInReminder();
          } else {
            notificationService.scheduleDailyCheckInReminder();
          }

          // Calculate health status
          final statusInfo = healthService.calculateStudentStatus(
            snapshot.data ?? [],
          );

          return Column(
            children: [
              // --- Maroon Header (matches other panels) ---
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF800000), Color(0xFF600000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        // Top row: Greeting + Avatar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting()},',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  '${user.firstName}!',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push('/health-profile'),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: StreamBuilder<HealthProfile?>(
                                  stream: context
                                      .read<HealthService>()
                                      .getHealthProfileStream(
                                        context
                                            .read<AuthService>()
                                            .currentUser!
                                            .id,
                                      ),
                                  builder: (context, profileSnap) {
                                    final profilePath =
                                        profileSnap.data?.profileImagePath ??
                                            '';
                                    if (profilePath.isNotEmpty) {
                                      return CircleAvatar(
                                        radius: 22,
                                        backgroundImage:
                                            resolveProfileImage(profilePath),
                                        onBackgroundImageError: (_, __) {},
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        child: null,
                                      );
                                    }
                                    return CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.2),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Health Support pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            'Health Support',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Scrollable Content ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDailyCheckInCard(context, checkedInToday),
                      const SizedBox(height: 20),
                      _buildAnnouncementsSection(context),
                      const SizedBox(height: 20),
                      _buildHealthSummaryCard(
                        context,
                        statusInfo,
                        latestLog,
                      ),
                      const SizedBox(height: 20),
                      _buildAppointmentsCard(context, checkedInToday),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }




  // ═══════════════════════════════════════════════════════════════
  // Daily Check-in Card
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDailyCheckInCard(BuildContext context, bool checkedInToday) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Check-in',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                if (checkedInToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
                        SizedBox(width: 4),
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              checkedInToday
                  ? 'Great job! You already checked in today.'
                  : 'How are you feeling today?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: () => context.push('/daily-check-in'),
                  style: FilledButton.styleFrom(
                    backgroundColor: checkedInToday
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF800000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  child: Text(
                    checkedInToday ? 'View' : 'Start',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Announcements Section
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAnnouncementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Announcements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<AnnouncementService>(
          builder: (context, announcementService, _) {
            final announcements = announcementService.announcements;

            if (announcements.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: Colors.grey.shade400,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No announcements yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            final latest = announcements.first;
            return GestureDetector(
              onTap: () => context.push('/announcement/${latest.id}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    // Indicator dot
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF800000), Color(0xFFB71C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latest.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF2D2D2D),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(
                              latest.timestamp,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Health Summary Card
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHealthSummaryCard(
    BuildContext context,
    Map<String, dynamic> statusInfo,
    HealthUpdate? latestLog,
  ) {
    final status = statusInfo['status'] as String;
    final statusColor = Color(statusInfo['color'] as int);

    String lastCheckedText = 'No data';
    if (latestLog != null) {
      final diff = DateTime.now().difference(latestLog.checkinDate);
      if (diff.inMinutes < 60) {
        lastCheckedText = 'Last checked: ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastCheckedText = 'Last checked: ${diff.inHours}h ago';
      } else {
        lastCheckedText = 'Last checked: ${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Health Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Latest Status: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastCheckedText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Appointments Card
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppointmentsCard(BuildContext context, bool checkedInToday) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Not Feeling well?\nBook an appointment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: () {
                  if (checkedInToday) {
                    context.push('/schedule');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please complete your Daily Check-in today before booking an appointment.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                child: const Text(
                  'Book',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
