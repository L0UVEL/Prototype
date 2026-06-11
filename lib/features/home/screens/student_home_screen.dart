import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/notification_service.dart';
import '../../chat/screens/chat_screen.dart';
import '../../health/screens/health_landing_screen.dart';
import '../../student/screens/student_announcements_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 1; // Default to Health (Daily Check-in)
  StreamSubscription? _appointmentStatusSubscription;

  final List<Widget> _screens = const [
    ChatScreen(),
    HealthLandingScreen(),
    StudentAnnouncementsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupAppointmentNotifications();
  }

  void _setupAppointmentNotifications() {
    final authService = context.read<AuthService>();
    final healthService = context.read<HealthService>();
    final notificationService = context.read<NotificationService>();
    final user = authService.currentUser;

    if (user != null) {
      _appointmentStatusSubscription =
          healthService.listenForAppointmentStatusChanges(
        userId: user.id,
        notificationService: notificationService,
      );
    }
  }

  @override
  void dispose() {
    _appointmentStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF800000).withValues(alpha: 0.15),
              elevation: 0,
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(
                    Icons.chat_bubble,
                    color: Color(0xFF800000),
                  ),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(
                    Icons.favorite,
                    color: Color(0xFF800000),
                  ),
                  label: 'Health',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(
                    Icons.campaign,
                    color: Color(0xFF800000),
                  ),
                  label: 'Updates',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
