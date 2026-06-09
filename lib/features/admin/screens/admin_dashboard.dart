import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/file_saver/file_saver.dart';
import '../../../core/utils/file_image_helper_stub.dart'
    if (dart.library.io) '../../../core/utils/file_image_helper_io.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/health_model.dart';
import '../../../core/services/notification_service.dart';
import 'admin_user_management_screen.dart';
import 'admin_analytics_tab.dart';
import 'admin_appointments_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime? _dashboardInitTime;
  StreamSubscription? _appointmentSubscription;

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

  Future<void> _generateReport(BuildContext context) async {
    final healthService = context.read<HealthService>();
    final studentsStream = healthService.getStudentsStream();
    final students = await studentsStream.first;
    
    // Sort students by studentId ascending
    students.sort((a, b) => a.studentId.compareTo(b.studentId));

    final header =
        'StudentID,Last Name,First Name,Status,Description,Course/Program\n';

    List<String> rowList = [];

    for (var student in students) {
      final logs = await healthService.getDailyLogsStream(student.id).first;
      final statusData = healthService.calculateStudentStatus(logs);

      rowList.add(
        '${student.studentId},"${student.lastName}","${student.firstName}","${statusData['status']}","${statusData['description']}","${student.program ?? ''}"',
      );
    }

    final rows = rowList.join('\n');

    final csvContent = header + rows;

    // Save to file
    try {
      final now = DateTime.now();
      final filename =
          'Student_Health_Report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';

      await saveAndLaunchFile(csvContent, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kIsWeb ? 'Report downloaded: $filename' : 'Report saved: $filename',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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

  void _showAddAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<XFile> dialogSelectedImages = [];
    List<PlatformFile> dialogSelectedPdfs = [];

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
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    context.read<AnnouncementService>().addAnnouncement(
                      titleController.text,
                      contentController.text,
                      images: dialogSelectedImages,
                      pdfs: dialogSelectedPdfs,
                    );
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F2),
        appBar: AppBar(
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.campaign), text: 'Announcement'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Appointments'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.assessment), text: 'Analytics'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await context.read<AuthService>().logout();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ═══════════════════════════════════════════════════════════════
            // Announcements Tab
            // ═══════════════════════════════════════════════════════════════
            Consumer<AnnouncementService>(
              builder: (context, announcementService, child) {
                final announcements = announcementService.announcements;

                if (announcements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF800000).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign_outlined,
                            size: 56,
                            color: Color(0xFF800000),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No announcements yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + to create your first announcement',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: () {
                          context.push('/announcement/${announcement.id}');
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF800000).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.campaign,
                            color: Color(0xFF800000),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          announcement.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat(
                              'MMM d, y • h:mm a',
                            ).format(announcement.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.grey.shade400,
                          ),
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

            // ═══════════════════════════════════════════════════════════════
            // Appointments Tab
            // ═══════════════════════════════════════════════════════════════
            const AdminAppointmentsScreen(),

            // ═══════════════════════════════════════════════════════════════
            // Students Tab
            // ═══════════════════════════════════════════════════════════════
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
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
                              label: const Text(
                                'Register New Student',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF800000),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => _generateReport(context),
                              icon: const Icon(Icons.add_chart),
                              label: const Text(
                                'Generate New Report',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF800000),
                                side: const BorderSide(
                                  color: Color(0xFF800000),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];

                          return StreamBuilder<HealthProfile?>(
                            stream: healthService.getHealthProfileStream(
                              student.id,
                            ),
                            builder: (context, profileSnap) {
                              final profilePath =
                                  profileSnap.data?.profileImagePath ?? '';

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

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      leading: profilePath.isNotEmpty
                                          ? CircleAvatar(
                                              radius: 22,
                                              backgroundImage:
                                                  resolveProfileImage(profilePath),
                                              onBackgroundImageError:
                                                  (_, __) {},
                                              backgroundColor:
                                                  statusColor.withValues(
                                                alpha: 0.15,
                                              ),
                                            )
                                          : CircleAvatar(
                                              radius: 22,
                                              backgroundColor:
                                                  statusColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: statusColor,
                                                size: 22,
                                              ),
                                            ),
                                      title: Text(
                                        student.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            student.program ?? "N/A",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            statusData['status'],
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey.shade400,
                                      ),
                                      onTap: () {
                                        context.go(
                                          '/admin/student/${student.id}',
                                        );
                                      },
                                    ),
                                  );
                                },
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

            // ═══════════════════════════════════════════════════════════════
            // Analytics Tab
            // ═══════════════════════════════════════════════════════════════
            const AdminAnalyticsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
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
        ),
      ),
    );
  }
}
