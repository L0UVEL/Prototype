import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/file_image_helper_stub.dart'
    if (dart.library.io) '../../../core/utils/file_image_helper_io.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/notification_service.dart';

import 'admin_announcements_tab.dart';
import 'admin_students_tab.dart';
import 'admin_analytics_tab.dart';
import 'admin_appointments_screen.dart';
import 'admin_activity_logs_tab.dart';
import 'admin_user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime? _dashboardInitTime;
  StreamSubscription? _appointmentSubscription;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardInitTime = DateTime.now();
    _listenForNewAppointments();
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    super.dispose();
  }

  void _listenForNewAppointments() {
    final healthService = context.read<HealthService>();
    final notificationService = context.read<NotificationService>();

    _appointmentSubscription = healthService.listenForNewAppointments(
      notificationService: notificationService,
      sinceTime: _dashboardInitTime!,
    );
  }

  void _showAddAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<XFile> dialogSelectedImages = [];
    List<PlatformFile> dialogSelectedPdfs = [];
    bool isPosting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.campaign, color: Color(0xFF800000)),
                SizedBox(width: 8),
                Text(
                  'New Announcement',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF800000),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        labelText: 'Content',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.article_outlined),
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
                          borderSide: const BorderSide(
                            color: Color(0xFF800000),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    if (dialogSelectedImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dialogSelectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: kIsWeb 
                                      ? Image.network(
                                          dialogSelectedImages[index].path,
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : Image(
                                          image: getFileImage(dialogSelectedImages[index].path),
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        dialogSelectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setState(() {
                            dialogSelectedImages.addAll(pickedFiles);
                          });
                        }
                      },
                      icon: const Icon(Icons.image, color: Color(0xFF800000)),
                      label: const Text('Add Images'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF800000),
                        side: const BorderSide(color: Color(0xFF800000)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ─── PDF attachments list ───
                    if (dialogSelectedPdfs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...dialogSelectedPdfs.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pdf = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF800000).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: Color(0xFF800000),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pdf.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    dialogSelectedPdfs.removeAt(idx);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          allowMultiple: true,
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setState(() {
                            dialogSelectedPdfs.addAll(result.files);
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFF800000),
                      ),
                      label: const Text('Attach PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF800000),
                        side: const BorderSide(color: Color(0xFF800000)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                onPressed: isPosting
                    ? null
                    : () async {
                        if (titleController.text.isNotEmpty &&
                            contentController.text.isNotEmpty) {
                          setState(() => isPosting = true);
                          try {
                            await context
                                .read<AnnouncementService>()
                                .addAnnouncement(
                                  titleController.text,
                                  contentController.text,
                                  images: dialogSelectedImages,
                                  pdfs: dialogSelectedPdfs,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            setState(() => isPosting = false);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to create announcement: $e',
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Post'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = const [
    AdminAnnouncementsTab(),
    AdminAppointmentsScreen(),
    AdminStudentsTab(),
    AdminAnalyticsTab(),
    AdminActivityLogsTab(),
  ];

  final List<String> _titles = const [
    'Announcements',
    'Appointments',
    'Students',
    'Analytics',
    'Activity Logs',
  ];

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    final appBar = AppBar(
      title: Text(
        _titles[_selectedIndex],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF800000),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthService>().logout();
            },
          ),
        ),
      ],
    );

    Widget? fab;
    if (_selectedIndex == 0) {
      fab = FloatingActionButton.extended(
        onPressed: () => _showAddAnnouncementDialog(context),
        icon: const Icon(Icons.add),
        label: const Text(
          'Announcement',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      );
    } else if (_selectedIndex == 2) {
      fab = FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminUserManagementScreen(),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Register Student',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      );
    }

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F5F2),
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFF800000),
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Colors.grey.shade600,
              ),
              selectedIconTheme: const IconThemeData(
                color: Color(0xFF800000),
              ),
              unselectedIconTheme: IconThemeData(
                color: Colors.grey.shade600,
              ),
              useIndicator: true,
              indicatorColor: const Color(0xFF800000).withValues(alpha: 0.1),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign),
                  label: Text('Announcements'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: Text('Appointments'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Students'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assessment_outlined),
                  selectedIcon: Icon(Icons.assessment),
                  label: Text('Analytics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_activity_outlined),
                  selectedIcon: Icon(Icons.local_activity),
                  label: Text('Logs'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE0E0E0)),
            Expanded(
              child: _pages[_selectedIndex],
            ),
          ],
        ),
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: appBar,
      body: _pages[_selectedIndex],
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF800000).withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign, color: Color(0xFF800000)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF800000)),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFF800000)),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment, color: Color(0xFF800000)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_activity_outlined),
            selectedIcon: Icon(Icons.local_activity, color: Color(0xFF800000)),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
