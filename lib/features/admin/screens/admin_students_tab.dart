import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/health_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/health_model.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/file_saver/file_saver.dart';

class AdminStudentsTab extends StatefulWidget {
  const AdminStudentsTab({super.key});

  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab> {
  String _searchQuery = '';
  String _selectedProgram = 'All';
  String _selectedStatus = 'All';

  final List<String> _statusOptions = [
    'All',
    'Healthy',
    'At Risk',
    'Missed Check-in',
    'No Data',
  ];

  Future<void> _generateReport(BuildContext context, List<User> filteredStudents) async {
    final healthService = context.read<HealthService>();
    
    // Sort students by studentId ascending
    final studentsToExport = List<User>.from(filteredStudents);
    studentsToExport.sort((a, b) => a.studentId.compareTo(b.studentId));

    final header =
        'StudentID,Last Name,First Name,Status,Description,Course/Program\n';

    List<String> rowList = [];

    for (var student in studentsToExport) {
      final logs = await healthService.getDailyLogsStream(student.id).first;
      final statusData = healthService.calculateStudentStatus(logs);

      // If filtering by status, skip those that don't match
      if (_selectedStatus != 'All' && statusData['status'] != _selectedStatus) {
        continue;
      }

      rowList.add(
        '${student.studentId},"${student.lastName}","${student.firstName}","${statusData['status']}","${statusData['description']}","${student.program ?? ''}"',
      );
    }

    final rows = rowList.join('\n');
    final csvContent = header + rows;

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: context.read<HealthService>().getStudentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allStudents = snapshot.data ?? [];
        final healthService = context.read<HealthService>();

        // Extract distinct programs
        final programs = ['All'];
        for (var s in allStudents) {
          if (s.program != null && s.program!.isNotEmpty && !programs.contains(s.program)) {
            programs.add(s.program!);
          }
        }

        // Apply basic filters (Search & Program)
        final filteredStudents = allStudents.where((student) {
          final matchesSearch = student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                student.studentId.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesProgram = _selectedProgram == 'All' || student.program == _selectedProgram;
          return matchesSearch && matchesProgram;
        }).toList();

        return Column(
          children: [
            // Filters Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Student ID...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Program',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedProgram,
                              isExpanded: true,
                              items: programs.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedProgram = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Status',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              isExpanded: true,
                              items: _statusOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedStatus = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _generateReport(context, filteredStudents),
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Export Filtered Report',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF800000),
                        side: const BorderSide(color: Color(0xFF800000)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // List Section
            Expanded(
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Text(
                        'No students found.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];

                        return StreamBuilder<HealthProfile?>(
                          stream: healthService.getHealthProfileStream(student.id),
                          builder: (context, profileSnap) {
                            final profilePath = profileSnap.data?.profileImagePath ?? '';

                            return StreamBuilder<List<HealthUpdate>>(
                              stream: healthService.getDailyLogsStream(student.id),
                              builder: (context, logSnapshot) {
                                final logs = logSnapshot.data ?? [];
                                final statusData = healthService.calculateStudentStatus(logs);
                                
                                // Dynamic Health Status Filter
                                if (_selectedStatus != 'All' && statusData['status'] != _selectedStatus) {
                                  return const SizedBox.shrink();
                                }

                                final statusColor = Color(statusData['color'] as int);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
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
                                      vertical: 6,
                                    ),
                                    leading: profilePath.isNotEmpty
                                        ? CircleAvatar(
                                            radius: 22,
                                            backgroundImage: resolveProfileImage(profilePath),
                                            onBackgroundImageError: (_, __) {},
                                            backgroundColor: statusColor.withValues(alpha: 0.15),
                                          )
                                        : CircleAvatar(
                                            radius: 22,
                                            backgroundColor: statusColor.withValues(alpha: 0.15),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                      context.go('/admin/student/${student.id}');
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
    );
  }
}
