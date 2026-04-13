import 'package:flutter/material.dart';
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

  final List<Widget> _screens = const [
    ChatScreen(),
    HealthLandingScreen(),
    StudentAnnouncementsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF800000).withValues(alpha: 0.12),
          elevation: 0,
          height: 68,
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
    );
  }
}
