import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/health_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<FileSystemEntity> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (directory.existsSync()) {
        final files = directory.listSync().where((file) {
          return file.path.endsWith('.csv') &&
              file.path.contains('Student_Health_Report');
        }).toList();

        files.sort((a, b) {
          return b.statSync().modified.compareTo(
            a.statSync().modified,
          ); // Newest first
        });

        if (mounted) {
          setState(() {
            _reports = files;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    final healthService = context.read<HealthService>();
    final students = healthService.allStudents;

    final header =
        'StudentID,Last Name,First Name,Status,Description,Course/Program\n';
    final rows = students
        .map((student) {
          final names = student.name.split(' ');
          final firstName = names.first;
          final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
          final statusData = healthService.getStudentStatus(student.id);

          return '${student.id},"$lastName","$firstName","${statusData['status']}","${statusData['description']}","${student.program ?? ''}"';
        })
        .join('\n');

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

      await _loadReports(); // Refresh list

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report generated successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Ideally switch tab, but simple feedback is good for now
              },
            ),
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

  Future<void> _exportReport(FileSystemEntity file) async {
    try {
      final filename = file.uri.pathSegments.last;
      String newPath;

      if (Platform.isAndroid) {
        // Warning: Direct access to /storage/emulated/0/Download might fail on Android 11+
        // without MANAGE_EXTERNAL_STORAGE or using MediaStore.
        // For prototype/older androids logic or with WRITE_EXTERNAL_STORAGE legacy request:
        newPath = '/storage/emulated/0/Download/$filename';
      } else {
        // Desktop fallback
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          newPath = '${downloadsDir.path}${Platform.pathSeparator}$filename';
        } else {
          throw Exception('Could not find downloads directory');
        }
      }

      // Copy file
      await File(file.path).copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to Downloads: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
          ],
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
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Post'),
          ),
        ],
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
              Tab(icon: Icon(Icons.assessment), text: 'Reports'), // New Tab
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<AuthService>().logout();
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
                                'MMM d, y HH:mm',
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
            Consumer<HealthService>(
              builder: (context, healthService, child) {
                final students = healthService.allStudents;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _generateReport(context),
                          icon: const Icon(Icons.add_chart),
                          label: const Text('Generate New Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final statusData = healthService.getStudentStatus(
                            student.id,
                          );
                          final statusColor = Color(statusData['color'] as int);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withValues(
                                  alpha: 0.2,
                                ),
                                child: Icon(Icons.person, color: statusColor),
                              ),
                              title: Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                      ),
                    ),
                  ],
                );
              },
            ),
            // Reports Tab
            _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assessment_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No reports generated yet.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final file = _reports[index];
                      final filename = file.uri.pathSegments.last;
                      final stat = file.statSync();

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.description,
                            color: Colors.blue,
                          ),
                          title: Text(filename),
                          subtitle: Text(
                            'Created: ${DateFormat('MMM d, HH:mm').format(stat.modified)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.file_download),
                            tooltip: 'Export to Downloads',
                            onPressed: () => _exportReport(file),
                          ),
                        ),
                      );
                    },
                  ),
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
