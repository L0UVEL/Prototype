import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/health_model.dart';
import '../../../core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_user_management_screen.dart';
import 'admin_analytics_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _dashboardInitTime;

  @override
  void initState() {
    super.initState();
    _dashboardInitTime = DateTime.now();
    _listenForNewAppointments();
  }

  void _listenForNewAppointments() {
    final notificationService = context.read<NotificationService>();

    // Listen to appointments created after the dashboard was opened
    _firestore
        .collection('appointments')
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(_dashboardInitTime!),
        )
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                notificationService.showNotification(
                  id: change.doc.id.hashCode,
                  title: 'New Appointment',
                  body:
                      'A student has requested a new appointment (${data['reason'] ?? 'consultation'}).',
                );
              }
            }
          }
        });
  }

  Future<void> _generateReport(BuildContext context) async {
    final healthService = context.read<HealthService>();
    final studentsStream = healthService.getStudentsStream();
    final students = await studentsStream.first;

    final header =
        'StudentID,Last Name,First Name,Status,Description,Course/Program\n';

    List<String> rowList = [];

    for (var student in students) {
      final logs = await healthService.getDailyLogsStream(student.id).first;
      final statusData = healthService.calculateStudentStatus(logs);

      final names = student.name.split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      rowList.add(
        '${student.id},"$lastName","$firstName","${statusData['status']}","${statusData['description']}","${student.program ?? ''}"',
      );
    }

    final rows = rowList.join('\n');

    final csvContent = header + rows;

    // Save to file
    try {
      final now = DateTime.now();
      final filename =
          'Student_Health_Report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';

      // Mobile (Android/iOS): Use Application Documents Directory
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}${Platform.pathSeparator}$filename';

      await File(path).writeAsString(csvContent);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<File> dialogSelectedImages = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('New Announcement'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
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
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      dialogSelectedImages[index],
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
                    TextButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setState(() {
                            dialogSelectedImages.addAll(
                              pickedFiles.map((f) => File(f.path)),
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Add Images'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    context.read<AnnouncementService>().addAnnouncement(
                      titleController.text,
                      contentController.text,
                      imageUrls: dialogSelectedImages
                          .map((e) => e.path)
                          .toList(),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Post'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Changed from 2 to 3
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.campaign), text: 'Announcements'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.assessment), text: 'Analytics'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthService>().logout();
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF800000)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Admin Panel',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text('Announcements'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Manage Appointments'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/appointments');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Manage Users'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminUserManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Announcements Tab
            Consumer<AnnouncementService>(
              builder: (context, announcementService, child) {
                final announcements = announcementService.announcements;

                if (announcements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        onTap: () {
                          context.push('/announcement/${announcement.id}');
                        },
                        title: Text(
                          announcement.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(announcement.content),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat(
                                'EEEE, MMM d, y • h:mm a',
                              ).format(announcement.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            context
                                .read<AnnouncementService>()
                                .deleteAnnouncement(announcement.id);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            // Students Tab
            // Students Tab
            StreamBuilder<List<User>>(
              stream: context.read<HealthService>().getStudentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data ?? [];
                final healthService = context.read<HealthService>();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              // Use FilledButton for primary action
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminUserManagementScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Register New Student'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _generateReport(context),
                              icon: const Icon(Icons.add_chart),
                              label: const Text('Generate New Report'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];

                          return StreamBuilder<List<HealthUpdate>>(
                            stream: healthService.getDailyLogsStream(
                              student.id,
                            ),
                            builder: (context, logSnapshot) {
                              final logs = logSnapshot.data ?? [];
                              final statusData = healthService
                                  .calculateStudentStatus(logs);
                              final statusColor = Color(
                                statusData['color'] as int,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: statusColor,
                                    ),
                                  ),
                                  title: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(student.program ?? "N/A"),
                                      Text(
                                        statusData['status'],
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    context.go('/admin/student/${student.id}');
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            // Analytics Tab
            const AdminAnalyticsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddAnnouncementDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Announcement'),
        ),
      ),
    );
  }
}
